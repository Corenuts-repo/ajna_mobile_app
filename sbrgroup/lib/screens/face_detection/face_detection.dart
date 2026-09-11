import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/face_detection/embedding_service.dart';
import 'package:ajna/screens/face_detection/shift_timings_model.dart';
import 'package:ajna/screens/util.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ajna/theme/app_colors.dart';

class FaceAttendanceScreen extends StatefulWidget {
  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<FaceAttendanceScreen> {
  CameraController? _cameraController;
  Future<void>? _cameraInitFuture;
  bool _isDetecting = false;
  bool _faceDetected = false;
  bool _isLoading = false;
  bool _isProcessingAPI = false;

  double currentLatitude = 0.0;
  double currentLongitude = 0.0;

  int _countdown = 3;
  Timer? _countdownTimer;
  bool _isCountingDown = false;

  late CameraDescription _camera;
  late FlutterTts _flutterTts;
  List<double> _generatedEmbeddings = [];
  late FaceEmbeddingService _faceEmbeddingService;
  List<Map<String, dynamic>> _shifts = [];
  int? _selectedShiftId;

  /// Label of the resolved shift, for the read-only line on screen.
  String get _selectedShiftName {
    for (final shift in _shifts) {
      if (shift['id'] == _selectedShiftId) {
        final label = (shift['refValue'] ?? '').toString().trim();
        if (label.isNotEmpty) return label;
      }
    }
    return '';
  }

  int? _selectedLocationId;
  int? _organizationId;
  CameraLensDirection _currentDirection = CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("en-IN");
    _flutterTts.setPitch(1.0);
    _flutterTts.setSpeechRate(0.5);
    _initializeModel();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      _camera = cameras.firstWhere(
        (camera) => camera.lensDirection == _currentDirection,
      );
      _cameraController = CameraController(
        _camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _cameraInitFuture = _cameraController!.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        // Without the shift screen in front of it the camera is often still
        // opening when the guard taps, and the countdown was only ever armed
        // from that tap. Arm it here too, so a slow camera does not leave them
        // staring at a preview that never fires.
        _armCapture();
      });
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _initializeModel() async {
    _organizationId = await Util.getOrganizationId();
    final prefs = await SharedPreferences.getInstance();
    _selectedLocationId = prefs.getInt('selectedProjectId');
    if (_selectedLocationId == null) {
      // Handle no project selected, perhaps navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a project first.')),
      );
      Navigator.pop(context);
      return;
    }
    fetchShiftData();
    await _handleQrCodeScanned();

    print("Initializing model...");
    _faceEmbeddingService = FaceEmbeddingService();
    await _faceEmbeddingService.init();
    print("Model ready: ${_faceEmbeddingService.isReady}");
  }

  Future<void> fetchShiftData() async {
    setState(() {
      _isLoading = true; // Start loading
    });

    try {
      final response = await ApiService.fetchshiftData();

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          _shifts = data
              .map((shifts) => {
                    'id': shifts['id'],
                    'refValue': shifts['refValue'] ?? '',
                    // Carried so the shift can be matched to the clock — see
                    // shiftIdForTime.
                    'commonRefValue': shifts['commonRefValue'],
                    'commonRefKey': shifts['commonRefKey'],
                  })
              .toList();

          // Open on the shift that is running now, so the guard confirms
          // rather than works it out. Null leaves the dropdown empty, as
          // before, and they pick.
          final suggested = shiftIdForLogin(_shifts, DateTime.now());
          if (suggested != null) {
            _selectedShiftId = suggested;
          }

          _isLoading = false; // Stop loading
        });
        _armCapture();
      }
    } catch (error) {
      setState(() {
        _isLoading = false; // Stop loading
      });
    }
  }

  Future<void> _speak(String message) async {
    await _flutterTts.stop();
    await _flutterTts.speak(message);
  }

  Future<void> _handleQrCodeScanned() async {
    try {
      Position position = await _getCurrentPosition(context);
      currentLatitude = position.latitude;
      currentLongitude = position.longitude;
      setState(() {});
    } catch (e) {
      print('Error parsing QR code data: $e');
    }
  }

  Future<Position> _getCurrentPosition(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Open system Location Services settings (iOS opens Settings > Privacy > Location Services)
      await Geolocator.openLocationSettings();
      await Future.delayed(const Duration(seconds: 2));
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _showDialog(
          context,
          'Location services are disabled',
          'Please enable location services in your device settings.',
          // Always show settings for location service disabled
          forceShowSettings: true,
        );
        throw 'Location services are disabled.';
      }
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        await _showDialog(
          context,
          'Location permissions denied',
          'Please grant location permissions in your device settings.',
          forceShowSettings: true,
        );
        throw 'Location permissions are denied.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await _showDialog(
        context,
        'Location permissions permanently denied',
        'Please enable location permissions manually in your device settings.',
        forceShowSettings: true,
      );
      throw 'Location permissions are permanently denied.';
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      debugPrint('Error fetching location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not check your location. Please try '
                  'again.')),
        );
      }
      throw 'Error fetching location';
    }
  }

  Future<void> _showDialog(BuildContext context, String title, String content,
      {bool forceShowSettings = false}) async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final bool showSettings =
            forceShowSettings || title.toLowerCase().contains('denied');
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            if (showSettings)
              TextButton(
                child: const Text('Open Settings'),
                onPressed: () async {
                  await openAppSettings();
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _takePictureAndSendToAPI() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    // The shift is resolved from the clock and never picked by hand, so this is
    // the one place it can be missing. Sending without it would record the punch
    // against no shift, which the backend then cannot match on logout.
    if (_selectedShiftId == null) {
      await _showResponseDialog(
          'Shift could not be identified. Please try again.', false);
      return;
    }

    setState(() {
      _isLoading = true;
      _isProcessingAPI = true;
    });

    try {
      final image = await _cameraController!.takePicture();
      File imageFile = File(image.path);
      // await _generateEmbedding(imageFile);
      await _sendAttendanceToAPI(imageFile, isLogin: true);
    } catch (e) {
      print("Error taking picture: $e");
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      // The result dialog pops this screen, so by the time we get here the
      // widget is usually gone.
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isProcessingAPI = false;
        });
      }
    }
  }

  Future<void> _generateEmbedding(File imageFile) async {
    if (!_faceEmbeddingService.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Still getting ready — please try again in a '
                'moment.')),
      );
      return;
    }

    try {
      final img.Image image = img.decodeImage(await imageFile.readAsBytes())!;
      final List<double> embeddings =
          await _faceEmbeddingService.getEmbedding(image);

      setState(() {
        _generatedEmbeddings = embeddings;
      });

      print('Embedding result: $_generatedEmbeddings');

      if (_generatedEmbeddings.every((e) => e == 0.0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Face not captured clearly. Please try again in '
                  'better light.')),
        );
      }
    } catch (e) {
      debugPrint('Error during embedding: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not read your face. Please try again.')),
      );
    }
  }

  Future<void> _sendAttendanceToAPI(File imageFile,
      {required bool isLogin}) async {
    try {
      // Logged so the shift actually sent can be confirmed against the
      // backend's response, rather than inferred from the app bar.
      debugPrint('Face capture -> shiftId=$_selectedShiftId '
          'isLogin=$isLogin locationId=$_selectedLocationId '
          'organizationId=$_organizationId');

      final response = await ApiService.submitCaptureFace(
        imageFile: imageFile,
        // embeddings: _generatedEmbeddings,
        shiftId: _selectedShiftId!,
        organizationId: _organizationId,
        locationId: _selectedLocationId,
        isLogin: isLogin,
        latitude: currentLatitude,
        longitude: currentLongitude,
      );

      String message = response.body.toString();
      bool isSuccess = response.statusCode == 200;

      await _showResponseDialog(message, isSuccess);
    } catch (e) {
      print("API Error: $e");
      await _showResponseDialog(
        "Something went wrong. Please try again later.",
        false,
      );
    }
  }

  Future<void> _showResponseDialog(String message, bool isSuccess) async {
    await _speak(message);

    // Determine icon and color based on message content
    IconData dialogIcon;
    Color dialogColor;
    String msgLower = message.toLowerCase();
    if (msgLower.contains('success') || msgLower.contains('successfully')) {
      dialogIcon = Icons.check_circle;
      dialogColor = Colors.green;
    } else if (msgLower.contains('already recorded')) {
      dialogIcon = Icons.warning;
      dialogColor = Colors.orange;
    } else if (msgLower.contains('no login record found') ||
        msgLower.contains('something went wrong') ||
        msgLower.contains('failed')) {
      dialogIcon = Icons.error;
      dialogColor = Colors.red;
    } else {
      dialogIcon = Icons.error;
      dialogColor = Colors.red;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 16,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                dialogIcon,
                color: dialogColor,
                size: 50,
              ),
              SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );

    // Nothing else should fire while the result is on screen.
    _countdownTimer?.cancel();

    await Future.delayed(const Duration(seconds: 6));
    if (!mounted) return;

    // Close the result dialog, then leave the capture screen. One punch per
    // visit: the guard reads the outcome and lands back on the dashboard,
    // rather than the camera re-arming and photographing whoever is next.
    Navigator.of(context, rootNavigator: true).pop();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameraController != null) {
      try {
        await _cameraController!.dispose();
      } catch (e) {
        print('Error disposing camera: $e');
      }
      _cameraController = null;
    }
    setState(() {
      _currentDirection = _currentDirection == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;
    });
    await _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _countdownTimer?.cancel();
    _flutterTts.stop();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdown = 3;
      _isCountingDown = true;
    });
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_countdown == 1) {
        timer.cancel();
        setState(() {
          _isCountingDown = false;
        });
        _onCountdownComplete();
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  void _onCountdownComplete() async {
    if (_isLoading || _isProcessingAPI) return;
    setState(() {
      _isDetecting = true;
      _faceDetected = true;
    });
    await _takePictureAndSendToAPI();
    setState(() {
      _isDetecting = false;
      _faceDetected = false;
    });
  }

  Widget _buildCountdownOverlay(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.black45,
      child: Center(
        child: Text(
          '$_countdown',
          style: TextStyle(
            color: Colors.white,
            fontSize: width > 500 ? 80 : 48,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 8, color: Colors.black)],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(double fontSize) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              "Processing Attendance...",
              style: TextStyle(color: Colors.white, fontSize: fontSize),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final loadingFontSize = width > 500 ? 20.0 : 16.0;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        // Brand hero gradient — matches CustomAppBar and the home header.
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.heroGradient,
              stops: AppColors.heroStops,
            ),
          ),
        ),
        // The shift lives here rather than on a panel in front of the camera:
        // it is decided by the clock, not by the guard, so it is a label to
        // read, not a step to complete.
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'In Face Capture',
              style: TextStyle(
                fontSize: width > 600 ? 22 : 18,
                color: Colors.white,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule, color: Colors.white, size: 13),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _selectedShiftName.isEmpty
                        ? 'Shift not identified'
                        : _selectedShiftName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          _buildCameraPreview(),
          if (_isCountingDown) _buildCountdownOverlay(width, height),
          if (_isLoading) _buildLoadingOverlay(loadingFontSize),
          // Capturing without a shift would file the punch against
          // nothing, which the backend cannot match on logout, so the
          // camera is covered until the shift list loads.
          if (_selectedShiftId == null && !_isLoading)
            _buildShiftUnavailableOverlay(),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.switch_camera,
                  color: Colors.white, size: 32),
              onPressed: _toggleCamera,
              tooltip: 'Switch Camera',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final frameWidth = width * 0.7;
        final frameHeight = height * 0.5;
        return Center(
          child: SizedBox(
            width: frameWidth,
            height: frameHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipOval(
                  child: SizedBox(
                    width: frameWidth,
                    height: frameHeight,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
                IgnorePointer(
                  child: Container(
                    width: frameWidth,
                    height: frameHeight,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.greenAccent, width: 3),
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(frameWidth / 2, frameHeight / 2),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Center(
                    child: Text(
                      "Align your face here",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: width > 500 ? 18.0 : 14.0,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Starts the capture countdown when everything it needs is ready.
  ///
  /// Called from three places because any of them can be the last to finish:
  /// the camera opening, the shift list arriving, and the previous guard's
  /// result dialog closing. Guarded so it can never stack two countdowns.
  void _armCapture() {
    if (!mounted) return;
    if (_selectedShiftId == null) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (_isCountingDown || _isLoading || _isProcessingAPI) return;
    _startCountdown();
  }

  /// Covers the camera while the shift is unknown, rather than capturing a
  /// punch that cannot be filed.
  Widget _buildShiftUnavailableOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.75),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_outlined,
                  size: 46, color: Colors.white70),
              const SizedBox(height: 14),
              const Text(
                'Shift could not be identified',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'The shift list did not load, so attendance cannot be recorded. '
                'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: fetchShiftData,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
