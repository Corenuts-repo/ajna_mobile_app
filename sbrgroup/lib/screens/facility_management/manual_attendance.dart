import 'dart:convert';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/connectivity_handler.dart';
import 'package:ajna/screens/util.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/responsive.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One row of the manual attendance sheet — a face attendance punch and what
/// the supervisor has done about it.
///
/// Everything the row is rendered from arrives on the row: whether the tick box
/// is ticked ([checked]), whether it may be ticked ([selectable]), which actions
/// it offers ([movable] / [restorable] / [undoMovable]) and what its state is
/// called ([recordStatus]). The screen decides none of it — the backend does,
/// exactly as it does for the web sheet, so the two cannot drift apart.
class ManualAttendanceRecord {
  /// shift_attendance.attendance_id — null once the punch has been removed,
  /// which is why every action that needs it is gated on a flag from the row.
  final int? attendanceId;

  /// The verification row. Restore is raised against this.
  final int? manualAttendanceId;

  /// The live MOVED row. A send-back is raised against this, not against
  /// [manualAttendanceId] — they are different records.
  final int? movedManualAttendanceId;

  final String userName;
  final String employeeNumber;
  final String designation;
  final int? locationId;
  final String locationName;
  final String? movedFromLocationName;
  final String? movedByName;
  final DateTime? movedDate;
  final String? movedRemarks;
  final String shiftName;
  final String? attendanceInTime;
  final String? attendanceOutTime;
  final String recordStatusKey;
  final String recordStatus;
  final bool checked;
  final bool selectable;
  final bool movable;
  final bool restorable;
  final bool undoMovable;
  final String? verifiedByName;
  final DateTime? verifiedDate;
  final String? remarks;

  ManualAttendanceRecord({
    required this.attendanceId,
    required this.manualAttendanceId,
    required this.movedManualAttendanceId,
    required this.userName,
    required this.employeeNumber,
    required this.designation,
    required this.locationId,
    required this.locationName,
    required this.movedFromLocationName,
    required this.movedByName,
    required this.movedDate,
    required this.movedRemarks,
    required this.shiftName,
    required this.attendanceInTime,
    required this.attendanceOutTime,
    required this.recordStatusKey,
    required this.recordStatus,
    required this.checked,
    required this.selectable,
    required this.movable,
    required this.restorable,
    required this.undoMovable,
    required this.verifiedByName,
    required this.verifiedDate,
    required this.remarks,
  });

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  static bool _toBool(dynamic v) => v == true;

  static String _text(dynamic v) => v?.toString().trim() ?? '';

  static String? _optional(dynamic v) {
    final text = _text(v);
    return text.isEmpty ? null : text;
  }

  /// LocalTime arrives as "09:15:00" — the seconds are noise on a sheet that is
  /// read at a glance, so only hours and minutes are kept.
  static String? _time(dynamic v) {
    final text = _optional(v);
    if (text == null) return null;
    final parts = text.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return text;
  }

  static DateTime? _dateTime(dynamic v) {
    final text = _optional(v);
    if (text == null) return null;
    return DateTime.tryParse(text);
  }

  factory ManualAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return ManualAttendanceRecord(
      attendanceId: _toInt(json['attendanceId']),
      manualAttendanceId: _toInt(json['manualAttendanceId']),
      movedManualAttendanceId: _toInt(json['movedManualAttendanceId']),
      userName: _text(json['userName']),
      employeeNumber: _text(json['employeeNumber']),
      designation: _text(json['designation']),
      locationId: _toInt(json['locationId']),
      locationName: _text(json['locationName']),
      movedFromLocationName: _optional(json['movedFromLocationName']),
      movedByName: _optional(json['movedByName']),
      movedDate: _dateTime(json['movedDate']),
      movedRemarks: _optional(json['movedRemarks']),
      shiftName: _text(json['shiftName']),
      attendanceInTime: _time(json['attendanceInTime']),
      attendanceOutTime: _time(json['attendanceOutTime']),
      recordStatusKey: _text(json['recordStatusKey']).toUpperCase(),
      recordStatus: _text(json['recordStatus']),
      checked: _toBool(json['checked']),
      selectable: _toBool(json['selectable']),
      movable: _toBool(json['movable']),
      restorable: _toBool(json['restorable']),
      undoMovable: _toBool(json['undoMovable']),
      verifiedByName: _optional(json['verifiedByName']),
      verifiedDate: _dateTime(json['verifiedDate']),
      remarks: _optional(json['remarks']),
    );
  }

  /// Ticking is keyed on the attendance id, which a removed punch no longer
  /// carries — those rows are read-only and this is never called for them.
  bool get isTickable => selectable && attendanceId != null;
}

/// Header counts of the sheet.
class ManualAttendanceCounts {
  final int loggedIn;
  final int pending;
  final int verified;
  final int removed;
  final int movedOut;

  const ManualAttendanceCounts({
    this.loggedIn = 0,
    this.pending = 0,
    this.verified = 0,
    this.removed = 0,
    this.movedOut = 0,
  });

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory ManualAttendanceCounts.fromJson(Map<String, dynamic> json) {
    return ManualAttendanceCounts(
      loggedIn: _toInt(json['loggedInCount']),
      pending: _toInt(json['pendingCount']),
      verified: _toInt(json['verifiedCount']),
      removed: _toInt(json['removedCount']),
      movedOut: _toInt(json['movedOutCount']),
    );
  }
}

/// One option of the status filter, served by the backend so the app carries
/// none of them itself.
class ManualAttendanceStatus {
  final int statusId;
  final String statusKey;
  final String statusValue;

  ManualAttendanceStatus({
    required this.statusId,
    required this.statusKey,
    required this.statusValue,
  });

  factory ManualAttendanceStatus.fromJson(Map<String, dynamic> json) {
    return ManualAttendanceStatus(
      statusId: json['statusId'] is int
          ? json['statusId']
          : int.tryParse('${json['statusId']}') ?? 0,
      statusKey: '${json['statusKey'] ?? ''}'.toUpperCase(),
      statusValue: '${json['statusValue'] ?? ''}',
    );
  }
}

/// A site the sheet can be opened for, and a destination a punch can be moved
/// to. Same shape the attendance screens already read.
class AttendanceLocation {
  final int id;
  final String location;

  AttendanceLocation({required this.id, required this.location});

  factory AttendanceLocation.fromJson(Map<String, dynamic> json) {
    return AttendanceLocation(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      location: '${json['location'] ?? ''}',
    );
  }
}

class ShiftOption {
  final int id;
  final String name;

  ShiftOption({required this.id, required this.name});

  factory ShiftOption.fromJson(Map<String, dynamic> json) {
    return ShiftOption(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: '${json['commonRefValue'] ?? ''}',
    );
  }
}

/// The manual attendance sheet, as the web shows it at
/// `attendance/manualAttendance`.
///
/// The supervisor picks the site and the day, then works down the punches made
/// there: tick the genuine ones and save, remove the ones that should never
/// have been recorded, move the ones worked at another site. Nothing is ticked
/// for them — a sheet that arrives pre-ticked gets saved without being read.
class ManualAttendanceScreen extends StatefulWidget {
  const ManualAttendanceScreen({Key? key}) : super(key: key);

  @override
  State<ManualAttendanceScreen> createState() => _ManualAttendanceScreenState();
}

class _ManualAttendanceScreenState extends State<ManualAttendanceScreen> {
  final ConnectivityHandler _connectivityHandler = ConnectivityHandler();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  /// Types into the Location menu. Kept on the state rather than built inline
  /// so the text survives the rebuilds the menu triggers while it is open.
  final TextEditingController _locationSearchController =
      TextEditingController();

  /// The dialog fields, owned here rather than created per dialog.
  ///
  /// showDialog's future completes the moment Navigator.pop is called, but the
  /// dialog keeps rebuilding through its exit animation. Disposing a controller
  /// as soon as that future returned killed it while its TextField was still on
  /// screen — "A TextEditingController was used after being disposed", and the
  /// broken subtree then threw a render overflow and a dependents assertion on
  /// top of it. Living on the state, they outlive every dialog by construction
  /// and are cleared on the way in instead.
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _moveRemarksController = TextEditingController();
  final TextEditingController _moveSearchController = TextEditingController();

  static const int _pageSize = 50;

  int? _userId;
  int? _organizationId;

  List<AttendanceLocation> _locations = [];
  List<ShiftOption> _shifts = [];
  List<ManualAttendanceStatus> _statuses = [];

  int? _locationId;
  int _shiftId = 0;
  int _statusId = 0;
  /// The sheet is a range, not a day — the backend filters on a start and an
  /// end, and the web sheet opens on today..today. Both the same day is the
  /// single-day sheet; widening the end covers a week without six reloads.
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String _search = '';

  List<ManualAttendanceRecord> _rows = [];
  ManualAttendanceCounts _counts = const ManualAttendanceCounts();

  /// Every punch currently ticked, saved or not.
  final Set<int> _selectedIds = {};

  /// What arrived ticked, so a save sends only what actually changed — the
  /// supervisor's edits, not the whole page back again.
  final Set<int> _savedIds = {};

  int _page = 0;
  int _totalRecords = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _saving = false;
  bool _filtersExpanded = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _locationSearchController.dispose();
    _remarksController.dispose();
    _moveRemarksController.dispose();
    _moveSearchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final connected = await _connectivityHandler.checkConnectivity(context);
    if (!connected) return;

    _userId = await Util.getUserId();
    _organizationId = await Util.getOrganizationId();

    await Future.wait([
      _fetchLocations(),
      _fetchShifts(),
      _fetchStatuses(),
    ]);

    if (!mounted) return;
    // Nothing loads until a site is chosen — the sheet is one site's day, and
    // without one there is nothing to show.
    if (_locationId != null) {
      await _fetchSheet(reset: true);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 120 &&
        !_loading &&
        !_loadingMore &&
        _rows.length < _totalRecords) {
      _loadMore();
    }
  }

  // ---------------------------------------------------------------- filters

  Future<void> _fetchLocations() async {
    try {
      final response =
          await ApiService.fetchAttendanceLocation(_organizationId);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _locations = data.map((e) => AttendanceLocation.fromJson(e)).toList();
        });
      } else {
        debugPrint(
            'Manual attendance: locations failed ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Manual attendance: locations error $e');
    }
  }

  Future<void> _fetchShifts() async {
    try {
      final response = await ApiService.fetchshiftData();
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _shifts = data.map((e) => ShiftOption.fromJson(e)).toList();
        });
      } else {
        debugPrint(
            'Manual attendance: shifts failed ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Manual attendance: shifts error $e');
    }
  }

  /// The states come from common reference data, in the order configured there,
  /// and the sheet opens on the first of them — so which states exist, what
  /// they are called and which one the supervisor lands on are all decided
  /// outside the app, exactly as on the web.
  Future<void> _fetchStatuses() async {
    try {
      final response = await ApiService.getManualAttendanceStatuses();
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _statuses =
              data.map((e) => ManualAttendanceStatus.fromJson(e)).toList();
          if (_statuses.isNotEmpty) {
            _statusId = _statuses.first.statusId;
          }
        });
      } else {
        debugPrint(
            'Manual attendance: statuses failed ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Manual attendance: statuses error $e');
    }
  }

  String get _formattedStart => DateFormat('yyyy-MM-dd').format(_startDate);
  String get _formattedEnd => DateFormat('yyyy-MM-dd').format(_endDate);

  // ------------------------------------------------------------------ sheet

  Future<void> _fetchSheet({bool reset = false}) async {
    if (_locationId == null) return;

    if (reset) {
      _page = 0;
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await ApiService.getManualAttendances(
        page: _page,
        size: _pageSize,
        locationId: _locationId!,
        startDate: _formattedStart,
        endDate: _formattedEnd,
        shiftId: _shiftId,
        statusId: _statusId,
        userName: _search,
      );

      if (response.statusCode != 200) {
        debugPrint(
            'Manual attendance: sheet failed ${response.statusCode} ${response.body}');
        if (!mounted) return;
        setState(() {
          if (reset) _rows = [];
          _loading = false;
          _error = 'Could not load the attendance sheet. Please try again.';
        });
        return;
      }

      final decoded = jsonDecode(response.body);
      final List<dynamic> records =
          (decoded is Map && decoded['records'] is List)
              ? decoded['records']
              : <dynamic>[];
      final fetched =
          records.map((e) => ManualAttendanceRecord.fromJson(e)).toList();

      if (!mounted) return;
      setState(() {
        if (reset) {
          _rows = fetched;
          _selectedIds.clear();
          _savedIds.clear();
        } else {
          _rows.addAll(fetched);
        }
        // Only the newly arrived rows seed the ticks. Re-seeding from the whole
        // list would put back ticks the supervisor has just taken off on an
        // earlier page.
        for (final row in fetched) {
          if (row.checked && row.attendanceId != null) {
            _savedIds.add(row.attendanceId!);
            _selectedIds.add(row.attendanceId!);
          }
        }
        _totalRecords = (decoded is Map && decoded['totalRecords'] != null)
            ? int.tryParse('${decoded['totalRecords']}') ?? _rows.length
            : _rows.length;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('Manual attendance: sheet error $e');
      if (!mounted) return;
      setState(() {
        if (reset) _rows = [];
        _loading = false;
        _error = 'Could not reach the server. Please check your connection.';
      });
    }

    await _fetchCounts();
  }

  Future<void> _fetchCounts() async {
    if (_locationId == null) return;
    try {
      final response = await ApiService.getManualAttendanceCount(
        locationId: _locationId!,
        startDate: _formattedStart,
        endDate: _formattedEnd,
        shiftId: _shiftId,
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _counts = decoded is Map<String, dynamic>
              ? ManualAttendanceCounts.fromJson(decoded)
              : const ManualAttendanceCounts();
        });
      } else {
        debugPrint(
            'Manual attendance: counts failed ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Manual attendance: counts error $e');
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    _page += 1;
    await _fetchSheet();
    if (!mounted) return;
    setState(() => _loadingMore = false);
  }

  void _reload() {
    _searchFocusOut();
    _fetchSheet(reset: true);
  }

  void _searchFocusOut() => FocusScope.of(context).unfocus();

  // -------------------------------------------------------------- selection

  bool _isSelected(ManualAttendanceRecord row) =>
      row.attendanceId != null && _selectedIds.contains(row.attendanceId);

  void _toggleRow(ManualAttendanceRecord row, bool ticked) {
    final id = row.attendanceId;
    if (id == null) return;
    setState(() {
      if (ticked) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  List<ManualAttendanceRecord> get _tickableRows =>
      _rows.where((row) => row.isTickable).toList();

  bool get _allSelected {
    final rows = _tickableRows;
    return rows.isNotEmpty && rows.every(_isSelected);
  }

  void _toggleAll(bool ticked) {
    setState(() {
      for (final row in _tickableRows) {
        if (ticked) {
          _selectedIds.add(row.attendanceId!);
        } else {
          _selectedIds.remove(row.attendanceId!);
        }
      }
    });
  }

  /// Ticks added since the sheet loaded.
  List<int> get _newlyVerified =>
      _selectedIds.where((id) => !_savedIds.contains(id)).toList();

  /// Ticks taken back since the sheet loaded.
  List<int> get _reverted =>
      _savedIds.where((id) => !_selectedIds.contains(id)).toList();

  int get _changeCount => _newlyVerified.length + _reverted.length;

  void _resetSelection() {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(_savedIds);
    });
  }

  // ---------------------------------------------------------------- actions

  Future<void> _save() async {
    if (_changeCount == 0 || _saving || _userId == null) return;

    final verified = _newlyVerified;
    final reverted = _reverted;

    setState(() => _saving = true);
    try {
      // Both calls have to land before the sheet is reloaded — reloading
      // between them would re-seed the ticks and lose the second half.
      if (verified.isNotEmpty) {
        final response = await ApiService.verifyManualAttendance(
          attendanceIds: verified,
          verifiedBy: _userId!,
        );
        if (!ApiService.isSuccess(response.statusCode)) {
          debugPrint(
              'Manual attendance: verify failed ${response.statusCode} ${response.body}');
          _failed(response, 'Could not save the attendance. Please try again.');
          return;
        }
      }

      if (reverted.isNotEmpty) {
        final response = await ApiService.unVerifyManualAttendance(
          attendanceIds: reverted,
          verifiedBy: _userId!,
        );
        if (!ApiService.isSuccess(response.statusCode)) {
          debugPrint(
              'Manual attendance: unverify failed ${response.statusCode} ${response.body}');
          _failed(response, 'Could not save the attendance. Please try again.');
          return;
        }
      }

      _toast('Attendance saved');
      await _fetchSheet(reset: true);
    } catch (e) {
      debugPrint('Manual attendance: save error $e');
      _toast('Could not reach the server. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(ManualAttendanceRecord row) async {
    final remarks = await _askRemarks(
      title: 'Remove attendance',
      message:
          'Remove the attendance of ${row.userName}? It stays on record as removed and can be put back.',
      confirmLabel: 'Remove',
      danger: true,
    );
    if (remarks == null || row.attendanceId == null || _userId == null) return;

    await _run(
      () => ApiService.removeManualAttendance(
        attendanceId: row.attendanceId!,
        removedBy: _userId!,
        remarks: remarks,
      ),
      success: 'Attendance removed',
      failure: 'Could not remove the attendance. Please try again.',
      action: 'remove',
    );
  }

  Future<void> _restore(ManualAttendanceRecord row) async {
    final confirmed = await _confirm(
      title: 'Put back attendance',
      message: 'Put back the attendance of ${row.userName}?',
      confirmLabel: 'Put back',
    );
    if (!confirmed || row.manualAttendanceId == null || _userId == null) return;

    await _run(
      () => ApiService.restoreManualAttendance(
        manualAttendanceId: row.manualAttendanceId!,
        restoredBy: _userId!,
      ),
      success: 'Attendance put back',
      failure: 'Could not put the attendance back. Please try again.',
      action: 'restore',
    );
  }

  Future<void> _move(ManualAttendanceRecord row) async {
    final result = await _askDestination(row);
    if (result == null || row.attendanceId == null || _userId == null) return;

    await _run(
      () => ApiService.moveManualAttendance(
        attendanceId: row.attendanceId!,
        movedLocationId: result.locationId,
        movedBy: _userId!,
        remarks: result.remarks,
      ),
      success: 'Attendance moved',
      failure: 'Could not move the attendance. Please try again.',
      action: 'move',
    );
  }

  Future<void> _undoMove(ManualAttendanceRecord row) async {
    final confirmed = await _confirm(
      title: 'Send attendance back',
      message: 'Bring the attendance of ${row.userName} back to '
          '${row.movedFromLocationName ?? 'the site it was marked at'}?',
      confirmLabel: 'Send back',
    );
    if (!confirmed || row.movedManualAttendanceId == null || _userId == null) {
      return;
    }

    await _run(
      () => ApiService.undoMoveManualAttendance(
        manualAttendanceId: row.movedManualAttendanceId!,
        movedBy: _userId!,
      ),
      success: 'Attendance sent back',
      failure: 'Could not send the attendance back. Please try again.',
      action: 'undo move',
    );
  }

  /// Runs one row action and reloads the sheet on success.
  ///
  /// The backend refuses a move or a send-back it cannot honour with a plain
  /// sentence saying why — that sentence is what the supervisor needs to see,
  /// so it is preferred over the generic message when one comes back.
  Future<void> _run(
    Future<dynamic> Function() request, {
    required String success,
    required String failure,
    required String action,
  }) async {
    setState(() => _saving = true);
    try {
      final response = await request();
      if (ApiService.isSuccess(response.statusCode)) {
        _toast(success);
        await _fetchSheet(reset: true);
      } else {
        debugPrint(
            'Manual attendance: $action failed ${response.statusCode} ${response.body}');
        _failed(response, failure);
      }
    } catch (e) {
      debugPrint('Manual attendance: $action error $e');
      _toast('Could not reach the server. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Shows the reason the backend gave, if it gave one — never a status code.
  void _failed(dynamic response, String fallback) {
    String message = fallback;
    try {
      final decoded = jsonDecode(response.body);
      final served = decoded is Map ? decoded['message'] : null;
      if (served is String && served.trim().isNotEmpty) {
        message = served.trim();
      }
    } catch (_) {
      // Body was not the JSON error shape — the friendly fallback stands.
    }
    _toast(message, error: true);
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColors.danger : AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ---------------------------------------------------------------- dialogs

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title,
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content:
            Text(message, style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? AppColors.danger : AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Confirm plus a reason. Returns the reason (possibly empty) on confirm and
  /// null on cancel — an empty reason and a cancel are different answers.
  Future<String?> _askRemarks({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) async {
    _remarksController.clear();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title,
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        // Scrollable so the keyboard cannot squeeze the content past the
        // dialog's height — an AlertDialog does not scroll its content itself.
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message, style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              TextField(
                controller: _remarksController,
                maxLength: 255,
                style: TextStyle(color: AppColors.textPrimary),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  counterText: '',
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? AppColors.danger : AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () =>
                Navigator.of(dialogContext).pop(_remarksController.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result;
  }

  /// Asks where the punch should go.
  ///
  /// Every site is offered, the punch's own included. The web used to filter
  /// that one out and no longer does, so re-selecting the current site is a
  /// supported move rather than something the list hides.
  Future<_MoveRequest?> _askDestination(ManualAttendanceRecord row) async {
    final destinations = _locations;
    if (destinations.isEmpty) {
      _toast('No site is available to move this attendance to.', error: true);
      return null;
    }

    int? destinationId;
    _moveRemarksController.clear();
    _moveSearchController.clear();

    final result = await showDialog<_MoveRequest>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Move attendance',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          // Scrollable: the dropdown, the reason field and two blocks of text
          // do not fit a short phone once the keyboard is up.
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  [
                    if (row.employeeNumber.isNotEmpty) row.employeeNumber,
                    row.userName,
                    if (row.locationName.isNotEmpty) row.locationName,
                    if (row.shiftName.isNotEmpty) row.shiftName,
                    if (row.attendanceInTime != null)
                      'In ${row.attendanceInTime}',
                  ].join(' · '),
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField2<int>(
                  isExpanded: true,
                  value: destinationId,
                  hint: Text('Move to',
                      style: TextStyle(color: AppColors.textSecondary)),
                  decoration: _fieldDecoration('Move to'),
                  // Bounded here too — an unbounded menu opened from a dialog
                  // covers the dialog, hiding which punch is being moved.
                  dropdownStyleData: _menuStyle(dialogContext, maxHeight: 300),
                  menuItemStyleData: _menuItemStyle,
                  dropdownSearchData: DropdownSearchData<int>(
                    searchController: _moveSearchController,
                    searchInnerWidgetHeight: _menuSearchHeight,
                    searchInnerWidget: _menuSearchField(_moveSearchController),
                    searchMatchFn: (item, query) =>
                        _matchesLocation(item, query, destinations),
                  ),
                  onMenuStateChange: (isOpen) {
                    if (!isOpen) _moveSearchController.clear();
                  },
                  items: destinations
                      .map((l) => DropdownMenuItem<int>(
                            value: l.id,
                            child: Text(l.location,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => destinationId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _moveRemarksController,
                  maxLength: 255,
                  style: TextStyle(color: AppColors.textPrimary),
                  cursorColor: AppColors.primary,
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    counterText: '',
                    border: const OutlineInputBorder(),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'The attendance itself is not changed. It moves to the chosen '
                  "site's sheet, where that supervisor verifies it.",
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              onPressed: destinationId == null
                  ? null
                  : () => Navigator.of(dialogContext).pop(_MoveRequest(
                        locationId: destinationId!,
                        remarks: _moveRemarksController.text.trim(),
                      )),
              child: const Text('Move'),
            ),
          ],
        ),
      ),
    );

    return result;
  }

  /// The two ends clamp each other rather than being validated after the fact:
  /// the start picker cannot go past the end and the end picker cannot go
  /// before the start, so an inverted range is never offered in the first place.
  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: isStart ? DateTime(2020) : _startDate,
      lastDate:
          isStart ? _endDate : DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.onPrimary,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
    _reload();
  }

  // ------------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: AppColors.bg,
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
        title: Text(
          'Manual Attendance',
          style: TextStyle(
            fontSize: screenWidth > 600 ? 22 : 18,
            color: AppColors.onPrimary,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.onPrimary),
      ),
      body: ContentWidthLimit(
        maxWidth: 760,
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: () async {
                  if (_locationId == null) return;
                  await _fetchSheet(reset: true);
                },
                child: ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  children: [
                    _filterCard(),
                    if (_locationId != null) ...[
                      const SizedBox(height: 12),
                      _summary(),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _banner(_error!),
                    ],
                    const SizedBox(height: 12),
                    ..._sheet(),
                  ],
                ),
              ),
            ),
            if (_locationId != null) _footer(),
          ],
        ),
      ),
    );
  }

  List<Widget> _sheet() {
    if (_locationId == null) {
      return [
        _placeholder(Icons.place_outlined,
            'Select a location to view its attendance for the day.'),
      ];
    }
    if (_loading) {
      return [
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ];
    }
    if (_rows.isEmpty) {
      return [
        _placeholder(Icons.inbox_outlined,
            'No attendance found for the selected filters.'),
      ];
    }

    return [
      if (_tickableRows.isNotEmpty) _selectAllBar(),
      const SizedBox(height: 8),
      ..._rows.map(_card),
      if (_loadingMore)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
        )
      else if (_rows.length < _totalRecords)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Center(
            child: TextButton(
              onPressed: _loadMore,
              child: Text('Load more (${_rows.length} of $_totalRecords)',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(
            child: Text('${_rows.length} of $_totalRecords shown',
                style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
          ),
        ),
    ];
  }

  Widget _filterCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _filterSummary,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _filtersExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_filtersExpanded) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField2<int>(
              isExpanded: true,
              value: _locationId,
              hint: Text('Select location',
                  style: TextStyle(color: AppColors.textSecondary)),
              decoration: _fieldDecoration('Location'),
              dropdownStyleData: _menuStyle(context, maxHeight: 340),
              menuItemStyleData: _menuItemStyle,
              dropdownSearchData: DropdownSearchData<int>(
                searchController: _locationSearchController,
                searchInnerWidgetHeight: _menuSearchHeight,
                searchInnerWidget: _menuSearchField(_locationSearchController),
                searchMatchFn: (item, query) =>
                    _matchesLocation(item, query, _locations),
              ),
              // The typed text belongs to one opening of the menu. Left behind,
              // the next open shows a list already filtered by something the
              // supervisor cannot see they typed.
              onMenuStateChange: (isOpen) {
                if (!isOpen) _locationSearchController.clear();
              },
              items: _locations
                  .map((l) => DropdownMenuItem<int>(
                        value: l.id,
                        child:
                            Text(l.location, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _locationId = value);
                _reload();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField2<int>(
              isExpanded: true,
              value: _shiftId,
              decoration: _fieldDecoration('Shift'),
              dropdownStyleData: _menuStyle(context, maxHeight: 280),
              menuItemStyleData: _menuItemStyle,
              items: [
                const DropdownMenuItem<int>(value: 0, child: Text('All shifts')),
                ..._shifts.map((s) => DropdownMenuItem<int>(
                      value: s.id,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (value) {
                setState(() => _shiftId = value ?? 0);
                _reload();
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _dateField('Start Date', _startDate,
                      () => _pickDate(isStart: true)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dateField(
                      'End Date', _endDate, () => _pickDate(isStart: false)),
                ),
              ],
            ),
            if (_statuses.isNotEmpty) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _statuses.map((status) {
                    final selected = status.statusId == _statusId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(status.statusValue),
                        selected: selected,
                        showCheckmark: false,
                        backgroundColor: AppColors.surfaceAlt,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selected
                              ? AppColors.onPrimary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        side: BorderSide(color: AppColors.divider),
                        onSelected: (_) {
                          if (selected) return;
                          setState(() => _statusId = status.statusId);
                          _reload();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: AppColors.textPrimary),
              cursorColor: AppColors.primary,
              onSubmitted: (value) {
                setState(() => _search = value.trim());
                _reload();
              },
              decoration: _fieldDecoration('Search employee').copyWith(
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: AppColors.primary),
                  onPressed: () {
                    setState(() => _search = _searchController.text.trim());
                    _reload();
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One line naming what is actually applied, shown on the collapsed panel so
  /// nobody has to open it to work out why the sheet looks the way it does.
  String get _filterSummary {
    final site = _locationId == null
        ? 'No location'
        : _locations
            .firstWhere(
              (l) => l.id == _locationId,
              orElse: () => AttendanceLocation(id: 0, location: 'Location'),
            )
            .location;
    final parts = <String>[
      site,
      _dateSummary,
      if (_shiftId != 0)
        _shifts
            .firstWhere((s) => s.id == _shiftId,
                orElse: () => ShiftOption(id: 0, name: 'Shift'))
            .name,
      if (_statuses.isNotEmpty)
        _statuses
            .firstWhere((s) => s.statusId == _statusId,
                orElse: () => _statuses.first)
            .statusValue,
      if (_search.isNotEmpty) _search,
    ];
    return parts.join(' · ');
  }

  /// One end of the range, read as a field rather than a button so the two
  /// sit level with the Shift dropdown above them.
  Widget _dateField(String label, DateTime value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: _fieldDecoration(label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('dd MMM yyyy').format(value),
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  /// A range of one day reads as that day, not as "x – x".
  String get _dateSummary {
    final start = DateFormat('dd MMM yyyy').format(_startDate);
    if (DateUtils.isSameDay(_startDate, _endDate)) return start;
    return '$start – ${DateFormat('dd MMM yyyy').format(_endDate)}';
  }

  /// How every dropdown on this screen opens its menu.
  ///
  /// Without this, dropdown_button2 lays the menu out unbounded and a list of
  /// twenty-odd sites covers the whole screen — the filters, the counts and the
  /// sheet behind it all disappear, so there is nothing left to tell you what
  /// you were choosing for. Capping the height keeps it a menu: it scrolls, the
  /// page stays visible around it, and tapping outside still dismisses it.
  DropdownStyleData _menuStyle(BuildContext context, {double maxHeight = 320}) {
    return DropdownStyleData(
      maxHeight: maxHeight,
      width: MediaQuery.of(context).size.width * 0.86,
      padding: EdgeInsets.zero,
      offset: const Offset(0, -4),
      elevation: 3,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
    );
  }

  /// Menu rows sized for a thumb at a gate, not for a mouse.
  MenuItemStyleData get _menuItemStyle => const MenuItemStyleData(
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: 14),
      );

  /// The search box inside the Location menus.
  ///
  /// The site list runs past twenty at this organisation, so scrolling to find
  /// one is slower than typing three letters of it.
  ///
  /// dropdown_button2 listens to the controller itself and re-filters the rows,
  /// so this only has to own the text — no rebuild is wired up by hand.
  ///
  /// The height is fixed and shared with `searchInnerWidgetHeight` below.
  /// dropdown_button2 uses that number to work out the menu's limits and scroll
  /// offset, so a field that renders taller than it claims leaves the menu
  /// mis-measured — the last row sits under the edge and cannot be reached.
  static const double _menuSearchHeight = 60;

  Widget _menuSearchField(TextEditingController controller) {
    return SizedBox(
      height: _menuSearchHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        child: TextFormField(
          controller: controller,
          autofocus: false,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            hintText: 'Search site',
            hintStyle:
                const TextStyle(color: AppColors.searchHint, fontSize: 13),
            prefixIcon:
                Icon(Icons.search, size: 18, color: AppColors.textFaint),
            // Left at its default the icon claims a 48px box, which pushes the
            // field past the height declared above.
            prefixIconConstraints:
                const BoxConstraints(minWidth: 34, minHeight: 34),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }

  /// Matches on the site name shown in the row, not on the id the item carries
  /// — the default match function compares `item.value.toString()`, which for
  /// an int id means typing a site name finds nothing.
  bool _matchesLocation(
      DropdownMenuItem<int> item, String query, List<AttendanceLocation> pool) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    final match = pool.where((l) => l.id == item.value);
    if (match.isEmpty) return false;
    return match.first.location.toLowerCase().contains(needle);
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  Widget _summary() {
    final chips = <Widget>[
      _countChip('Logged In', _counts.loggedIn, AppColors.primary),
      _countChip('Pending', _counts.pending, AppColors.warning),
      _countChip('Verified', _counts.verified, AppColors.success),
      _countChip('Removed', _counts.removed, AppColors.textSecondary),
      _countChip('Moved Out', _counts.movedOut, AppColors.info),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    );
  }

  Widget _countChip(String label, int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('$count',
              style: TextStyle(
                  fontSize: 16, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _selectAllBar() {
    return Row(
      children: [
        Checkbox(
          value: _allSelected,
          activeColor: AppColors.primary,
          onChanged: (value) => _toggleAll(value == true),
        ),
        Expanded(
          child: Text(
            _allSelected
                ? 'All shown punches ticked'
                : 'Tick all shown punches',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
        Text('${_selectedIds.length} ticked',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
      ],
    );
  }

  Widget _card(ManualAttendanceRecord row) {
    final accent = _statusColor(row.recordStatusKey);
    final actions = _actionsFor(row);
    // Struck off the sheet, exactly as the web row reads — the name carries the
    // line and the rest of the card fades, so a removed punch is recognised
    // before it is read. The notes underneath stay plain: who removed it and
    // why is the part still worth reading.
    final removed = row.recordStatusKey == 'REMOVED';
    // A moved punch is intact, it just belongs to another site's sheet now, so
    // it is muted rather than struck.
    final moved =
        row.recordStatusKey == 'MOVED' || row.recordStatusKey == 'MOVED_OUT';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The left edge carries the state as colour, so a page of rows
              // reads as a shape before any of it is read as text.
              Container(
                width: 4,
                height: 76,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                  ),
                ),
              ),
              if (row.isTickable)
                Checkbox(
                  value: _isSelected(row),
                  activeColor: AppColors.primary,
                  onChanged: (value) => _toggleRow(row, value == true),
                )
              else
                const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding:
                      EdgeInsets.fromLTRB(row.isTickable ? 0 : 4, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.userName,
                              style: TextStyle(
                                color: removed
                                    ? AppColors.textFaint
                                    : moved
                                        ? AppColors.textSecondary
                                        : AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                decoration: removed
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: AppColors.textFaint,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _statusPill(row.recordStatus, accent),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (row.employeeNumber.isNotEmpty) row.employeeNumber,
                          if (row.designation.isNotEmpty) row.designation,
                          if (row.shiftName.isNotEmpty) row.shiftName,
                        ].join(' · '),
                        style: TextStyle(
                            color: removed
                                ? AppColors.textFaint
                                : AppColors.textSecondary,
                            fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _timeChip(Icons.login, 'In', row.attendanceInTime),
                          const SizedBox(width: 8),
                          _timeChip(Icons.logout, 'Out', row.attendanceOutTime),
                        ],
                      ),
                      if (row.locationName.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.place_outlined,
                                size: 13, color: AppColors.textFaint),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(row.locationName,
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ],
                      if (row.movedFromLocationName != null)
                        _note('Moved from ${row.movedFromLocationName}'
                            '${row.movedByName == null ? '' : ' by ${row.movedByName}'}'
                            '${row.movedDate == null ? '' : ' on ${DateFormat('dd/MM/yyyy hh:mm a').format(row.movedDate!)}'}'
                            '${row.movedRemarks == null ? '' : ' · ${row.movedRemarks}'}'),
                      if (row.verifiedByName != null)
                        _note('${row.recordStatus} by ${row.verifiedByName}'
                            '${row.verifiedDate == null ? '' : ' on ${DateFormat('dd/MM/yyyy hh:mm a').format(row.verifiedDate!)}'}'
                            '${row.remarks == null ? '' : ' · ${row.remarks}'}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 8, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions,
              ),
            ),
        ],
      ),
    );
  }

  /// Only what the row says it offers. A removed punch has no attendance id to
  /// act on, so offering Remove or Move there would be an action that cannot
  /// be carried out.
  List<Widget> _actionsFor(ManualAttendanceRecord row) {
    return [
      if (row.selectable && row.attendanceId != null)
        _actionButton(Icons.delete_outline, 'Remove', AppColors.danger,
            () => _remove(row)),
      if (row.movable && row.attendanceId != null)
        _actionButton(Icons.drive_file_move_outline, 'Move', AppColors.primary,
            () => _move(row)),
      if (row.restorable && row.manualAttendanceId != null)
        _actionButton(
            Icons.restore, 'Put back', AppColors.success, () => _restore(row)),
      if (row.undoMovable && row.movedManualAttendanceId != null)
        _actionButton(
            Icons.undo, 'Send back', AppColors.primary, () => _undoMove(row)),
    ];
  }

  Widget _actionButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: _saving ? null : onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _timeChip(IconData icon, String label, String? value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textFaint),
          const SizedBox(width: 4),
          Text('$label ${value ?? '—'}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _note(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text,
          style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
    );
  }

  /// The web sheet's four states, in its colours.
  ///
  /// Removed is grey, not red: the punch was struck off the sheet by a
  /// supervisor who meant to, which is a decision rather than a fault, and a
  /// page of red down the left edge reads as a page of errors.
  Color _statusColor(String key) {
    switch (key) {
      case 'VERIFIED':
        return AppColors.success;
      case 'REMOVED':
        return AppColors.textSecondary;
      case 'MOVED':
      case 'MOVED_OUT':
        return AppColors.info;
      default:
        return AppColors.warning;
    }
  }

  Widget _banner(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppColors.textFaint),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      // Bottom padding clears the system navigation bar (SDK 36 is always
      // edge-to-edge), so SAVE/RESET are not hidden underneath it.
      padding: EdgeInsets.fromLTRB(12, 10, 12, 14 + bottomBarInset(context)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed:
                  _saving || _changeCount == 0 ? null : _resetSelection,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.divider),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('RESET'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _saving || _changeCount == 0 ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                disabledBackgroundColor: AppColors.surfaceAlt,
                disabledForegroundColor: AppColors.textFaint,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onPrimary),
                    )
                  : Text('VERIFY SELECTED ($_changeCount)',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where a punch is being sent and why.
class _MoveRequest {
  final int locationId;
  final String remarks;

  _MoveRequest({required this.locationId, required this.remarks});
}
