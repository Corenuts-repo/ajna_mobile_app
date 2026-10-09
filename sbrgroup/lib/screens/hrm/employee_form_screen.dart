import 'dart:convert';
import 'dart:io';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/hrm/employee_models.dart';
import 'package:ajna/screens/util.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/form_fields.dart';
import 'package:ajna/theme/responsive.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// Add or edit an employee — the mobile form of the web's
/// `employee/addemployee`, which serves both the same way.
///
/// EIGHT SECTIONS, ONE RECORD
///
/// Basic, Position, Address, Education, Bank, Family, Experience and Documents
/// are one save, not eight. Both write endpoints take the whole EmployeeSaveDto
/// — so an edit loads the full record first and changes it in place. Building
/// the payload from a blank form would wipe every section the form did not
/// fill.
///
/// The save UPSERTS the repeated sections rather than replacing them: the
/// backend walks each list and updates or inserts every row it is handed, and
/// never deletes one that is absent. Dropping a saved education, family or
/// experience row therefore takes its own DELETE call — see [_removeChildRow].
///
/// The sections are collapsible rather than a wizard: a supervisor adding a
/// guard fills Basic and Position and saves, while HR correcting a bank account
/// opens one panel and leaves the rest alone. A wizard makes both walk the same
/// eight steps.
class EmployeeFormScreen extends StatefulWidget {
  /// The `id` of the row being edited, or null to add.
  final int? employeeRowId;

  const EmployeeFormScreen({Key? key, this.employeeRowId}) : super(key: key);

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();

  bool get _isEdit => widget.employeeRowId != null;

  late EmployeeSaveDto _dto;
  int? _organizationId;
  String? _roleName;

  /// The web's "onboarding rules": on when `nextEmployeeNumber` returns a
  /// number. They pre-fill the employee number on a new employee, drop the
  /// emergency-contact and shift questions, narrow work locations to the
  /// chosen project, and make blood group, bank details and family details
  /// required (the web's `ajnaRequiredFields`) — optional for everyone else.
  bool _onboardingRules = false;

  /// The web shows Role to organisation 2 and to TECH ADMIN only; everyone
  /// else's employees get the role the backend defaults.
  bool get _showsRole =>
      _organizationId == 2 || (_roleName ?? '').toUpperCase() == 'TECH ADMIN';

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  // Reference data for the dropdowns, all served rather than written here.
  List<RefOption> _departments = [];
  List<RefOption> _shifts = [];
  List<RefOption> _divisions = [];
  List<RefOption> _costCentres = [];
  List<RefOption> _grades = [];
  List<RefOption> _qualifications = [];
  List<RefOption> _qualificationAreas = [];
  List<RefOption> _employeeStatuses = [];
  List<ManagerOption> _managers = [];
  List<EmployeeOption> _attendanceManagers = [];
  List<RoleOption> _roles = [];
  List<ProjectOption> _projects = [];
  List<WorkLocationOption> _workLocations = [];

  /// Files picked in this session, keyed by the web's docType — `Adhar_card`,
  /// `Health_issue`, `bank`, or `family_member_2` / `education_0` for a row.
  /// Each is uploaded as `{key}_{originalName}`; the backend routes it by that
  /// name. Picking again for the same key replaces the earlier file.
  final Map<String, File> _pickedDocuments = {};

  /// Email / phone as loaded, so an unchanged value on edit is not re-checked.
  String _originalEmail = '';
  String _originalPhone = '';
  bool _emailExists = false;
  bool _phoneExists = false;

  /// Under onboarding rules, the family row picked as the emergency contact.
  int? _emergencyIndex;

  /// Which panels are open. Basic starts open; the rest are a tap away so the
  /// form does not open as a wall of ninety fields.
  final Set<String> _open = {'basic'};

  final Map<String, TextEditingController> _text = {};
  final Map<String, TextEditingController> _menuSearch = {};

  /// The prefix is the web's docType — the backend reads it out of the
  /// filename to decide which column the upload belongs to.
  static const List<_DocumentSlot> _documentSlots = [
    _DocumentSlot('adharUrl', 'Aadhaar', 'Adhar_card'),
    _DocumentSlot('panUrl', 'PAN', 'Pan_card'),
    _DocumentSlot('voterIdUrl', 'Voter ID', 'Voter_card'),
    _DocumentSlot('passPortUrl', 'Passport', 'PassPort_card'),
    _DocumentSlot('rationCardUrl', 'Ration card', 'Ration_card'),
  ];

  static const List<String> _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Not Known' //
  ];

  /// The web pre-selects this role for organisation 1 when its users, who do
  /// not see the Role field, add an employee.
  static const int _defaultRoleIdOrgOne = 146;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    for (final controller in _menuSearch.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// A controller per field, created once and owned by the state.
  ///
  /// Built on demand rather than declared up front — ninety fields across eight
  /// sections, most of which a given edit never opens.
  TextEditingController _controller(String key, String initial) {
    return _text.putIfAbsent(key, () => TextEditingController(text: initial));
  }

  TextEditingController _searchController(String key) {
    return _menuSearch.putIfAbsent(key, () => TextEditingController());
  }

  // ------------------------------------------------------------------ load

  Future<void> _bootstrap() async {
    _organizationId = await Util.getOrganizationId();
    _roleName = await Util.getRoleName();

    final nextNumber = await Future.wait([
      _loadReferenceData(),
      _loadNextEmployeeNumber(),
    ]).then((results) => results[1] as String?);
    _onboardingRules = nextNumber != null;

    if (_isEdit) {
      await _loadEmployee();
    } else {
      _dto = EmployeeSaveDto.blank(organizationId: _organizationId ?? 0);
      // Pre-filled, not locked — the web leaves the field editable too.
      if (nextNumber != null) _dto.employeeBean.employeeId = nextNumber;
      if (!_showsRole && _organizationId == 1) {
        _dto.employeeBean.employeeRoleId = _defaultRoleIdOrgOne;
      }
    }

    _originalEmail = _isEdit ? _dto.employeeBean.email.trim() : '';
    _originalPhone = _isEdit ? _dto.employeeBean.phoneNumber.trim() : '';
    final emergency = _dto.employeeFamilyBeanList
        .indexWhere((f) => f.isEmergencyContact == 'Yes');
    _emergencyIndex = emergency >= 0 ? emergency : null;

    if (_onboardingRules && _dto.employeeBean.projectAssigned != null) {
      await _loadLocationsForProject(_dto.employeeBean.projectAssigned!);
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  /// The web's duplicate checks. A non-2xx answer means the value is taken; a
  /// network failure is not treated as a duplicate (the save would then fail
  /// on the server with its own message).
  Future<void> _checkEmail() async {
    final email = _dto.employeeBean.email.trim();
    if (email.isEmpty ||
        (_isEdit && email == _originalEmail) ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      if (_emailExists) setState(() => _emailExists = false);
      return;
    }
    try {
      final response = await ApiService.checkEmailExists(email);
      if (!mounted || _dto.employeeBean.email.trim() != email) return;
      setState(() => _emailExists = !ApiService.isSuccess(response.statusCode));
    } catch (e) {
      debugPrint('Employee form: email check error $e');
    }
  }

  Future<void> _checkPhone() async {
    final phone = _dto.employeeBean.phoneNumber.trim();
    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone) ||
        (_isEdit && phone == _originalPhone)) {
      if (_phoneExists) setState(() => _phoneExists = false);
      return;
    }
    try {
      final response = await ApiService.checkPhoneNumberExists(phone);
      if (!mounted || _dto.employeeBean.phoneNumber.trim() != phone) return;
      setState(() => _phoneExists = !ApiService.isSuccess(response.statusCode));
    } catch (e) {
      debugPrint('Employee form: phone check error $e');
    }
  }

  /// The next employee number, or null when the organisation has no
  /// onboarding rules (or the call fails — the form then behaves as before).
  Future<String?> _loadNextEmployeeNumber() async {
    if (_organizationId == null) return null;
    try {
      final response = await ApiService.getNextEmployeeNumber(_organizationId!);
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        final decoded = jsonDecode(response.body);
        final number = decoded is Map ? decoded['employeeNumber'] : null;
        final text = number?.toString().trim() ?? '';
        return text.isEmpty ? null : text;
      }
      debugPrint('Employee form: next number ${response.statusCode}');
    } catch (e) {
      debugPrint('Employee form: next number error $e');
    }
    return null;
  }

  /// Under onboarding rules the work locations are the chosen project's. A
  /// location that is not in the new list is cleared, as the web does.
  Future<void> _loadLocationsForProject(int projectId) async {
    if (_organizationId == null) return;
    try {
      final response = await ApiService.fetchAttendanceLocationsByProject(
          _organizationId!, projectId);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final locations = decoded
              .whereType<Map<String, dynamic>>()
              .map(WorkLocationOption.fromJson)
              .toList();
          if (!mounted) return;
          setState(() {
            _workLocations = locations;
            final current = _dto.employeeBean.workLocation;
            if (current != null && !locations.any((l) => l.id == current)) {
              _dto.employeeBean.workLocation = null;
            }
          });
          return;
        }
      }
      debugPrint('Employee form: project locations ${response.statusCode}');
    } catch (e) {
      debugPrint('Employee form: project locations error $e');
    }
  }

  Future<void> _loadEmployee() async {
    try {
      final response = await ApiService.getEmployeeById(widget.employeeRowId!);
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          _dto = EmployeeSaveDto.fromJson(decoded);
          // Older records can come back without an organisation on them; the
          // save needs one, so the signed-in user's stands in.
          _dto.employeeBean.organizationId ??= _organizationId;
          return;
        }
      }
      debugPrint(
          'Employee form: load failed ${response.statusCode} ${response.body}');
      _dto = EmployeeSaveDto.blank(organizationId: _organizationId ?? 0);
      _loadError = 'Could not load this employee. Please go back and retry.';
    } catch (e) {
      debugPrint('Employee form: load error $e');
      _dto = EmployeeSaveDto.blank(organizationId: _organizationId ?? 0);
      _loadError = 'Could not reach the server. Please go back and retry.';
    }
  }

  Future<void> _loadReferenceData() async {
    Future<List<T>> fetchList<T>(
      Future<dynamic> Function() request,
      T Function(Map<String, dynamic>) parse,
      String what,
    ) async {
      try {
        final response = await request();
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is List) {
            return decoded
                .whereType<Map<String, dynamic>>()
                .map(parse)
                .toList();
          }
        }
        debugPrint('Employee form: $what failed ${response.statusCode}');
      } catch (e) {
        debugPrint('Employee form: $what error $e');
      }
      return <T>[];
    }

    Future<List<RefOption>> refs(String type) => fetchList(
        () => ApiService.getCommonReferenceDetails(type),
        RefOption.fromJson,
        type);

    // Designation is a free-text field, matching the web, so
    // `Designation_Type` is deliberately not fetched here.
    final results = await Future.wait([
      refs('Department_Type'),
      refs('Shift_Timings'),
      refs('Divisions'),
      refs('cost_center'),
      refs('Grades'),
      refs('Qualification_Type'),
      refs('Qualification_Area'),
      refs('Employee_Status'),
      fetchList(() => ApiService.fetchOrgManagers(_organizationId!),
          ManagerOption.fromJson, 'managers'),
      fetchList(() => ApiService.fetchOrgRoles(_organizationId!),
          RoleOption.fromJson, 'roles'),
      fetchList(() => ApiService.fetchOrgProjects(_organizationId!),
          ProjectOption.fromJson, 'projects'),
      fetchList(() => ApiService.fetchLocation(_organizationId!),
          WorkLocationOption.fromJson, 'work locations'),
      fetchList(() => ApiService.getAttendanceManagers(_organizationId!),
          EmployeeOption.fromJson, 'attendance managers'),
    ]);

    if (!mounted) return;
    _departments = results[0] as List<RefOption>;
    _shifts = results[1] as List<RefOption>;
    _divisions = results[2] as List<RefOption>;
    _costCentres = results[3] as List<RefOption>;
    _grades = results[4] as List<RefOption>;
    _qualifications = results[5] as List<RefOption>;
    _qualificationAreas = results[6] as List<RefOption>;
    _employeeStatuses = results[7] as List<RefOption>;
    _managers = results[8] as List<ManagerOption>;
    _roles = results[9] as List<RoleOption>;
    _projects = results[10] as List<ProjectOption>;
    _workLocations = results[11] as List<WorkLocationOption>;
    _attendanceManagers = results[12] as List<EmployeeOption>;
  }

  // ------------------------------------------------------------------ save

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    // The web will not leave Basic Details while either is a duplicate.
    await Future.wait([_checkEmail(), _checkPhone()]);
    if (!mounted) return;

    // Checked against the record, not the widgets: a collapsed section's
    // fields are not built, so the Form cannot see them.
    final missing = _firstMissing();
    if (missing != null) {
      _openSection(missing.section);
      _toast(missing.message, error: true);
      // Once the section is open, outline what is wrong in it.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _formKey.currentState?.validate());
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      _toast('Please correct the highlighted fields.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      _dto.employeeBean.organizationId = _organizationId;
      // Only a NEW employee gets a form status stamped here. 'ews' is
      // reference data, not a constant, so it is resolved rather than
      // hard-coded — the same thing the web's saveEmployee does.
      //
      // An edit deliberately leaves formStatusOne exactly as it was loaded.
      // Setting it to 'esd' ("Submitted") makes the backend treat the save as
      // a submission for approval and look up the "Employee Stages" workflow,
      // which fails with "No Record Found with given name" wherever that
      // workflow is not configured. The web only stamps 'esd' from its
      // separate declaration action, never from the normal UPDATE button.
      if (!_isEdit) {
        final statusId = await _formStatusId('ews');
        if (statusId != null) {
          _dto.employeeBean.formStatusOne = statusId;
        }
      }

      if (_onboardingRules) {
        final family = _dto.employeeFamilyBeanList;
        for (var i = 0; i < family.length; i++) {
          family[i].isEmergencyContact = _emergencyIndex == i ? 'Yes' : 'No';
        }
      }

      final payload = jsonEncode(_dto.toJson());
      // `{docType}_{stamp}.{ext}`, not the original name: the backend routes
      // by substring (`contains("Pan")`, `"Pass"`, …), so a phone filename
      // such as `Pancake.jpg` would file a Voter ID as the PAN card. Row keys
      // keep the index third (`family_member_2_…`), where the backend reads it.
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final documents = <String, File>{
        for (final entry in _pickedDocuments.entries)
          '${entry.key}_$stamp.${_extension(entry.value.path)}': entry.value,
      };

      final response = _isEdit
          ? await ApiService.updateEmployee(payload, documents)
          : await ApiService.submitEmployee(payload, documents);

      if (ApiService.isSuccess(response.statusCode)) {
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      debugPrint(
          'Employee form: save failed ${response.statusCode} ${response.body}');
      _toast(
          _serverMessage(response.body) ?? 'Could not save. Please try again.',
          error: true);
    } catch (e) {
      debugPrint('Employee form: save error $e');
      _toast('Could not reach the server. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<int?> _formStatusId(String refKey) async {
    try {
      final response = await ApiService.getCommonReferenceByKey(refKey);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['id'] != null) {
          return int.tryParse('${decoded['id']}');
        }
      }
      debugPrint('Employee form: status $refKey failed ${response.statusCode}');
    } catch (e) {
      debugPrint('Employee form: status $refKey error $e');
    }
    // The save is still valid without it — the web treats this the same way.
    return null;
  }

  String? _serverMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      final message = decoded is Map ? decoded['message'] : null;
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    } catch (_) {
      // Not the JSON error shape — the friendly fallback stands.
    }
    return null;
  }

  /// The first required answer that is missing, in the web's section order,
  /// with the section that holds it.
  _Missing? _firstMissing() {
    final bean = _dto.employeeBean;
    bool blank(String v) => v.trim().isEmpty;
    final tenDigits = RegExp(r'^[0-9]{10}$');

    _Missing basic(String m) => _Missing('basic', m);
    if (_emailExists) {
      return basic('This Email already exists. Please enter another.');
    }
    if (_phoneExists) {
      return basic('This Phone Number already exists. Please enter another.');
    }
    if (blank(bean.employeeId)) return basic('Employee number is required.');
    if (blank(bean.firstName)) return basic('First name is required.');
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(bean.email.trim())) {
      return basic('Email is not valid.');
    }
    if (!tenDigits.hasMatch(bean.phoneNumber.trim())) {
      return basic('Phone number must be 10 digits.');
    }
    if (bean.dateOfBirth == null) return basic('Date of birth is required.');

    _Missing personal(String m) => _Missing('personal', m);
    if (!RegExp(r'^([0-9]{12}|[A-Z]{5}[0-9]{4}[A-Z])$')
        .hasMatch(bean.nationalId.trim().toUpperCase())) {
      return personal('Aadhaar must be 12 digits or PAN like ABCDE1234F.');
    }
    if (blank(bean.gender)) return personal('Gender is required.');
    if (_onboardingRules && blank(bean.bloodGroup)) {
      return personal('Blood group is required.');
    }
    if (!_onboardingRules) {
      if (blank(bean.emergencyContactName)) {
        return personal('Emergency contact name is required.');
      }
      if (!tenDigits.hasMatch(bean.emergencyContactNumber.trim())) {
        return personal('Emergency contact number must be 10 digits.');
      }
    }
    if (bean.healthIssue == 'Y' && blank(bean.healthIssueDescription)) {
      return personal('Describe the health issue.');
    }

    _Missing position(String m) => _Missing('position', m);
    if (bean.dateOfJoining == null) {
      return position('Date of joining is required.');
    }
    if (bean.reportingManager == null) {
      return position('Reporting manager is required.');
    }
    if (bean.attendanceManager == null) {
      return position('Attendance manager is required.');
    }
    if (bean.projectAssigned == null) return position('Project is required.');
    if (blank(bean.employeeStatus)) {
      return position('Employee status is required.');
    }
    // Attendance calls `employee.getShift().equals("Yes")` with no null guard,
    // so a record saved without an answer later breaks a punch.
    if (!_onboardingRules) {
      if (bean.shiftId == null) return position('Shift is required.');
      if (blank(bean.shift)) {
        return position('Choose Yes or No for rotational shift.');
      }
    }
    if (bean.workLocation == null) {
      return position('Work location is required.');
    }
    if (blank(bean.designation)) return position('Designation is required.');
    if (_showsRole && bean.employeeRoleId == null) {
      return position('Role is required.');
    }
    if (bean.department == null) return position('Department is required.');
    if (blank(bean.isInProbation)) {
      return position('Choose Yes or No for probation.');
    }
    if (bean.isInProbation == 'Yes' && (bean.probationPeriod ?? 0) < 1) {
      return position('Enter probation period days.');
    }

    // Aadhaar — satisfied by a file picked now or one already on the record.
    if (_pickedDocuments['Adhar_card'] == null && blank(bean.adharUrl)) {
      return const _Missing('documents', 'Aadhaar Card is required.');
    }

    final bank = _dto.employeeBankDetails;
    if (_onboardingRules &&
        (blank(bank.bankName) ||
            blank(bank.bankAccountNumber) ||
            blank(bank.bankIfscCode))) {
      return const _Missing(
          'bank', 'Please enter all required fields in Bank Details');
    }
    if (_onboardingRules &&
        _pickedDocuments['bank'] == null &&
        blank(bank.attachmentUrl)) {
      return const _Missing(
          'bank', 'Please upload the Bank Passbook / Cancelled Cheque');
    }

    final family = _dto.employeeFamilyBeanList;
    if (_onboardingRules) {
      for (var i = 0; i < family.length; i++) {
        final f = family[i];
        if (blank(f.name) ||
            blank(f.relationship) ||
            blank(f.contactNo) ||
            blank(f.address) ||
            blank(f.country) ||
            blank(f.city) ||
            blank(f.pincode)) {
          return _Missing('family',
              'Please enter all required fields in Employee Family Details (member ${i + 1})');
        }
      }
    }

    // The web's onboarding check, run after the sections.
    if (_onboardingRules) {
      final index = _emergencyIndex;
      if (index == null || index >= family.length) {
        if (blank(bean.emergencyContactNumber)) {
          return const _Missing(
              'family', 'Select a family member as the emergency contact');
        }
      } else {
        final member = family[index];
        if (blank(member.name)) {
          return const _Missing('family',
              'Enter the name of the emergency contact family member');
        }
        if (!tenDigits.hasMatch(member.contactNo.trim())) {
          return const _Missing('family',
              'Enter a valid 10 digit contact number for the emergency contact');
        }
        if (member.contactNo.trim() == bean.phoneNumber.trim()) {
          return const _Missing('family',
              'Emergency contact number must be different from the employee phone number');
        }
      }
    }
    return null;
  }

  /// Keeps row-indexed uploads (`family_member_3`, …) pointing at the right
  /// row after row [removed] is dropped — the web renumbers the same way.
  void _shiftRowDocuments(String prefix, int removed) {
    final moved = <String, File>{};
    _pickedDocuments.removeWhere((key, file) {
      if (!key.startsWith('${prefix}_')) return false;
      final index = int.tryParse(key.substring(prefix.length + 1));
      if (index == null || index < removed) return false;
      if (index > removed) moved['${prefix}_${index - 1}'] = file;
      return true;
    });
    _pickedDocuments.addAll(moved);
  }

  /// Drops one row of a repeated section, deleting it on the server first when
  /// it has already been saved.
  ///
  /// A row with `id == 0` has never been stored, so removing it locally is the
  /// whole job. A saved row has to be deleted through its own endpoint — the
  /// employee save upserts and would leave it behind. The row only leaves the
  /// form once the server has accepted the delete, so a failure cannot make it
  /// look gone when it is still on the record.
  Future<void> _removeChildRow({
    required int id,
    required Future<dynamic> Function(int) delete,
    required VoidCallback removeLocally,
    required String what,
  }) async {
    if (id > 0) {
      try {
        final response = await delete(id);
        if (!ApiService.isSuccess(response.statusCode)) {
          debugPrint('Employee form: delete $what failed '
              '${response.statusCode} ${response.body}');
          _toast('Could not remove this $what. Please try again.', error: true);
          return;
        }
      } catch (e) {
        debugPrint('Employee form: delete $what error $e');
        _toast('Could not reach the server. Please try again.', error: true);
        return;
      }
    }
    if (!mounted) return;
    setState(removeLocally);
  }

  void _openSection(String key) {
    if (!_open.contains(key)) {
      setState(() => _open.add(key));
    }
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
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
          _isEdit ? 'Update Employee' : 'Add Employee',
          style: TextStyle(
            fontSize: screenWidth > 600 ? 22 : 18,
            color: AppColors.onPrimary,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.onPrimary),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ContentWidthLimit(
              maxWidth: 760,
              child: Column(
                children: [
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                        children: [
                          if (_loadError != null) ...[
                            _banner(_loadError!),
                            const SizedBox(height: 12),
                          ],
                          _basicSection(),
                          _personalSection(),
                          _positionSection(),
                          _documentsSection(),
                          _educationSection(),
                          _bankSection(),
                          _experienceSection(),
                          _addressSection(),
                          _familySection(),
                        ],
                      ),
                    ),
                  ),
                  _footer(),
                ],
              ),
            ),
    );
  }

  Widget _footer() {
    return Container(
      // Bottom padding clears the system navigation bar (SDK 36 is always
      // edge-to-edge), so the action buttons are not hidden underneath it.
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
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.divider),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('CANCEL'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onPrimary),
                    )
                  : Text(_isEdit ? 'UPDATE' : 'SUBMIT',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- sections

  Widget _section({
    required String id,
    required String title,
    required IconData icon,
    String? subtitle,
    required List<Widget> children,
  }) {
    final expanded = _open.contains(id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (expanded) {
                _open.remove(id);
              } else {
                _open.add(id);
              }
            }),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: TextStyle(
                                  color: AppColors.textFaint, fontSize: 11)),
                        ],
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
        ],
      ),
    );
  }

  /// Basic and Personal share one employee row, split the way the web splits
  /// them (its `personalFields`). Title, PAN, ESI and PF are carried on the
  /// web's form but not shown there; they stay here so nothing is lost.
  Widget _basicSection() {
    final bean = _dto.employeeBean;
    return _section(
      id: 'basic',
      title: 'Basic Details',
      icon: Icons.badge_outlined,
      subtitle: 'Required',
      children: [
        _field('employeeId', 'Employee number', bean.employeeId,
            (v) => bean.employeeId = v,
            required: true),
        _row(
          _field('firstName', 'First name', bean.firstName,
              (v) => bean.firstName = v,
              required: true),
          _field(
              'lastName', 'Last name', bean.lastName, (v) => bean.lastName = v),
        ),
        _field(
            'email',
            'Email',
            bean.email,
            (v) {
              bean.email = v;
              if (_emailExists) setState(() => _emailExists = false);
            },
            required: true,
            keyboardType: TextInputType.emailAddress,
            onBlur: _checkEmail,
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isEmpty) return 'Email is required.';
              if (_emailExists) {
                return 'This Email already exists. Please enter another.';
              }
              final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
              return ok ? null : 'Email is not valid.';
            }),
        _field(
            'phoneNumber',
            'Phone number',
            bean.phoneNumber,
            (v) {
              bean.phoneNumber = v;
              if (_phoneExists) setState(() => _phoneExists = false);
            },
            required: true,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            digitsOnly: true,
            onBlur: _checkPhone,
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isEmpty) return 'Phone Number is required.';
              if (_phoneExists) {
                return 'This Phone Number already exists. Please enter another.';
              }
              return RegExp(r'^[0-9]{10}$').hasMatch(text)
                  ? null
                  : 'Phone number must be 10 digits.';
            }),
        _dateField('Date of birth', bean.dateOfBirth,
            (d) => setState(() => bean.dateOfBirth = d),
            required: true, lastDate: DateTime.now()),
        _row(
          _field('city', 'City', bean.city, (v) => bean.city = v),
          _field('state', 'State', bean.state, (v) => bean.state = v),
        ),
        _field('postalCode', 'Postal code', bean.postalCode?.toString() ?? '',
            (v) => bean.postalCode = int.tryParse(v.trim()),
            keyboardType: TextInputType.number, digitsOnly: true),
        _field('title', 'Title', bean.title, (v) => bean.title = v),
        _field('panId', 'PAN number', bean.panId, (v) => bean.panId = v),
        _row(
          _field('esiNumber', 'ESI number', bean.esiNumber,
              (v) => bean.esiNumber = v),
          _field('pfUanNo', 'PF UAN number', bean.pfUanNo,
              (v) => bean.pfUanNo = v),
        ),
        // No "create a login" question: the web removed it and always sends
        // isAddAsUserNeeded = 'Yes' (the model's default), so this does too.
      ],
    );
  }

  Widget _personalSection() {
    final bean = _dto.employeeBean;
    return _section(
      id: 'personal',
      title: 'Personal Details',
      icon: Icons.assignment_ind_outlined,
      subtitle: 'Required',
      children: [
        // Aadhaar (12 digits) or PAN (ABCDE1234F) — the same rule the web
        // applies, so a record entered on a phone is accepted by both.
        _field('nationalId', 'Aadhaar / PAN', bean.nationalId,
            (v) => bean.nationalId = v,
            required: true, validator: (value) {
          final text = (value ?? '').trim().toUpperCase();
          if (text.isEmpty) return 'Aadhaar / PAN Id is required.';
          final ok =
              RegExp(r'^([0-9]{12}|[A-Z]{5}[0-9]{4}[A-Z])$').hasMatch(text);
          return ok
              ? null
              : 'Aadhaar must be 12 digits or PAN like ABCDE1234F.';
        }),
        _choice('Gender', bean.gender, const ['Male', 'Female', 'Other'],
            (v) => setState(() => bean.gender = v),
            required: true),
        _choice(
            'Marital status',
            bean.maritalStatus,
            const ['Single', 'Married'],
            (v) => setState(() => bean.maritalStatus = v)),
        _field('address', 'Address', bean.address, (v) => bean.address = v,
            maxLines: 2),
        _row(
          _field(
              'religion', 'Religion', bean.religion, (v) => bean.religion = v),
          _field('cast', 'Caste', bean.cast, (v) => bean.cast = v),
        ),
        _stringDropdown('Blood group', _bloodGroups, bean.bloodGroup,
            (v) => setState(() => bean.bloodGroup = v),
            required: _onboardingRules),
        _field('identificationMark', 'Identification mark',
            bean.identificationMark, (v) => bean.identificationMark = v),
        _row(
          _field('height', 'Height', bean.height, (v) => bean.height = v),
          _field('weight', 'Weight', bean.weight, (v) => bean.weight = v),
        ),
        _field('fatherName', "Father's name", bean.fatherName,
            (v) => bean.fatherName = v),
        _field('spouseName', 'Spouse name', bean.spouseName,
            (v) => bean.spouseName = v),
        _dateField('Marriage date', bean.marriageDate,
            (d) => setState(() => bean.marriageDate = d),
            lastDate: DateTime.now()),
        _row(
          _field('nationality', 'Nationality', bean.nationality,
              (v) => bean.nationality = v),
          _field('country', 'Country', bean.country, (v) => bean.country = v),
        ),
        _field('personalEmail', 'Personal email', bean.personalEmail,
            (v) => bean.personalEmail = v,
            keyboardType: TextInputType.emailAddress),
        // Required, except under onboarding rules, where the web hides both.
        if (!_onboardingRules) ...[
          _field('emergencyContactName', 'Emergency contact name',
              bean.emergencyContactName, (v) => bean.emergencyContactName = v,
              required: true),
          _field(
              'emergencyContactNumber',
              'Emergency contact number',
              bean.emergencyContactNumber,
              (v) => bean.emergencyContactNumber = v,
              required: true,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              digitsOnly: true, validator: (value) {
            final text = (value ?? '').trim();
            if (text.isEmpty) return 'Emergency Contact Number is required.';
            return RegExp(r'^[0-9]{10}$').hasMatch(text)
                ? null
                : 'Emergency contact number must be 10 digits.';
          }),
        ],
        _field('policeStationLimits', 'Police station limits',
            bean.policeStationLimits, (v) => bean.policeStationLimits = v),
        // Entered, not derived. Neither the web nor the backend works it out
        // from the date of birth, so a form that skipped it would leave the
        // column empty on every employee added from a phone.
        _field('age', 'Age', bean.age?.toString() ?? '',
            (v) => bean.age = int.tryParse(v.trim()),
            keyboardType: TextInputType.number, digitsOnly: true, maxLength: 3),
        _field('plcaeOfBirth', 'Place of birth', bean.plcaeOfBirth,
            (v) => bean.plcaeOfBirth = v),
        _choice(
            'Physically challenged',
            bean.physicallyChallenged,
            const ['Yes', 'No'],
            (v) => setState(() => bean.physicallyChallenged = v)),
        // The web's Employee Health switch. 'Y'/'N' on the wire; turning it
        // off clears the description, as the web does.
        _choice(
            'Health issue',
            bean.healthIssue == 'Y' ? 'Yes' : 'No',
            const ['Yes', 'No'],
            (v) => setState(() {
                  bean.healthIssue = v == 'Yes' ? 'Y' : 'N';
                  if (bean.healthIssue != 'Y') {
                    bean.healthIssueDescription = '';
                    bean.healthIssueUrl = '';
                    _pickedDocuments.remove('Health_issue');
                    _setText('healthIssueDescription', '');
                  }
                })),
        if (bean.healthIssue == 'Y')
          _field(
              'healthIssueDescription',
              'Health issue description',
              bean.healthIssueDescription,
              (v) => bean.healthIssueDescription = v,
              required: true,
              maxLines: 3),
        if (bean.healthIssue == 'Y')
          _attachmentRow(
              'Health_issue', 'Health issue document', bean.healthIssueUrl),
      ],
    );
  }

  Widget _positionSection() {
    final bean = _dto.employeeBean;
    return _section(
      id: 'position',
      title: 'Position Details',
      icon: Icons.work_outline,
      subtitle: 'Required',
      children: [
        _dateField('Date of joining', bean.dateOfJoining,
            (d) => setState(() => bean.dateOfJoining = d),
            required: true),
        _searchableRefDropdown<ProjectOption>(
          key: 'projectAssigned',
          label: 'Project',
          value: bean.projectAssigned,
          items: _projects,
          idOf: (p) => p.projectId,
          labelOf: (p) => p.projectName,
          onChanged: (v) {
            setState(() => bean.projectAssigned = v);
            if (_onboardingRules && v != null) _loadLocationsForProject(v);
          },
          required: true,
        ),
        _searchableRefDropdown<ManagerOption>(
          key: 'reportingManager',
          label: 'Reporting manager',
          value: bean.reportingManager,
          items: _managers,
          idOf: (m) => m.userId,
          labelOf: (m) => m.userName,
          onChanged: (v) => setState(() => bean.reportingManager = v),
          required: true,
        ),
        // An EMPLOYEE, not a user: the web lists `getAllEmpoyees` and stores
        // the employee row id here.
        _searchableRefDropdown<EmployeeOption>(
          key: 'attendanceManager',
          label: 'Attendance manager',
          value: bean.attendanceManager,
          items: _attendanceManagers,
          idOf: (e) => e.id,
          labelOf: (e) => e.name,
          onChanged: (v) => setState(() => bean.attendanceManager = v),
          required: true,
        ),
        if (_showsRole)
          _searchableRefDropdown<RoleOption>(
            key: 'employeeRoleId',
            label: 'Role',
            value: bean.employeeRoleId,
            items: _roles,
            idOf: (r) => r.roleId,
            labelOf: (r) => r.roleName,
            onChanged: (v) => setState(() => bean.employeeRoleId = v),
            required: true,
          ),
        _searchableRefDropdown<WorkLocationOption>(
          key: 'workLocation',
          label: 'Work location',
          value: bean.workLocation,
          items: _workLocations,
          idOf: (l) => l.id,
          labelOf: (l) => l.location,
          onChanged: (v) => setState(() => bean.workLocation = v),
          required: true,
        ),
        _refDropdown('Department', _departments, bean.department,
            (v) => setState(() => bean.department = v),
            required: true),
        // Free text, not a dropdown. `Designation_Type` reference data exists
        // and the web still fetches it, but the web's field is a plain input
        // and the column is a varchar — a dropdown here would refuse the
        // designations already on record that are not in that list.
        _field('designation', 'Designation', bean.designation,
            (v) => bean.designation = v,
            required: true),
        // Hidden under onboarding rules, as on the web.
        if (!_onboardingRules) ...[
          _refDropdown('Shift', _shifts, bean.shiftId,
              (v) => setState(() => bean.shiftId = v),
              required: true),
          // `shift` is NOT a label for shiftId — it is the rotational-shift
          // flag, and attendance reads it as `employee.getShift().equals("Yes")`.
          // Free text here would write something that comparison never matches.
          _choice('Rotational shift', bean.shift, const ['Yes', 'No'],
              (v) => setState(() => bean.shift = v),
              required: true),
        ],
        _refDropdownByValue('Employee status', _employeeStatuses,
            bean.employeeStatus, (v) => setState(() => bean.employeeStatus = v),
            required: true),
        _choice(
            'In probation',
            bean.isInProbation,
            const ['Yes', 'No'],
            (v) => setState(() {
                  bean.isInProbation = v;
                  // Turning probation off clears the period, as the web does —
                  // otherwise a stale number is saved against an employee who
                  // is no longer on probation.
                  if (v != 'Yes') {
                    bean.probationPeriod = 0;
                    _setText('probationPeriod', '0');
                  }
                }),
            required: true),
        // Only asked for while probation is on, and then it must be a real
        // number of days — the web hides the field and drops its validators
        // the moment probation is switched off.
        if (bean.isInProbation == 'Yes')
          _field(
              'probationPeriod',
              'Probation period (days)',
              bean.probationPeriod?.toString() ?? '',
              (v) => bean.probationPeriod = int.tryParse(v.trim()),
              required: true,
              keyboardType: TextInputType.number,
              digitsOnly: true, validator: (value) {
            final days = int.tryParse((value ?? '').trim());
            if (days == null || days < 1) {
              return 'Enter Probation Period (days).';
            }
            return null;
          }),
        _dateField('Confirmation date', bean.confirmationDate,
            (d) => setState(() => bean.confirmationDate = d)),
        _refDropdown('Division', _divisions, bean.divisionId,
            (v) => setState(() => bean.divisionId = v)),
        _refDropdown('Cost centre', _costCentres, bean.costCenterId,
            (v) => setState(() => bean.costCenterId = v)),
        _refDropdown('Grade', _grades, bean.gradeId,
            (v) => setState(() => bean.gradeId = v)),
        _field('company', 'Company', bean.company, (v) => bean.company = v),
        _choice('PMS eligible', bean.isPmsEligible, const ['Yes', 'No'],
            (v) => setState(() => bean.isPmsEligible = v)),
        const SizedBox(height: 6),
        Text('Exit',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _dateField('Date of resignation', bean.dateOfResignation,
            (d) => setState(() => bean.dateOfResignation = d)),
        _dateField('Notice period end', bean.noticePeriodEndDate,
            (d) => setState(() => bean.noticePeriodEndDate = d)),
        _dateField('Last working day', bean.lastWorkingDay,
            (d) => setState(() => bean.lastWorkingDay = d)),
      ],
    );
  }

  Widget _addressSection() {
    final permanent = _dto.addressBeanList[0];
    final temporary = _dto.addressBeanList[1];
    return _section(
      id: 'address',
      title: 'Address Details',
      icon: Icons.home_outlined,
      subtitle: 'Permanent and temporary',
      children: [
        ..._addressFields('perm', 'Permanent', permanent),
        const SizedBox(height: 12),
        Divider(color: AppColors.divider),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text('Temporary address',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            TextButton.icon(
              onPressed: () => _copyPermanentAddress(),
              icon: const Icon(Icons.copy_all, size: 16),
              label: const Text('Same as permanent'),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        ..._addressFields('temp', null, temporary),
        const SizedBox(height: 12),
        Text('Point of contact',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        // Nothing is selected until one is chosen. Both addresses start at
        // 'No', so defaulting the display to Temporary claimed a choice the
        // record had not been given.
        _choiceRaw(
          permanent.isPointOfContact == 'Yes'
              ? 'Permanent'
              : temporary.isPointOfContact == 'Yes'
                  ? 'Temporary'
                  : '',
          const ['Permanent', 'Temporary'],
          (v) => setState(() {
            final isPermanent = v == 'Permanent';
            permanent.isPointOfContact = isPermanent ? 'Yes' : 'No';
            temporary.isPointOfContact = isPermanent ? 'No' : 'Yes';
          }),
        ),
      ],
    );
  }

  List<Widget> _addressFields(
      String prefix, String? heading, EmployeeAddress address) {
    return [
      if (heading != null) ...[
        Text('$heading address',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
      ],
      _row(
        // Integer on the backend, so anything with a letter in it cannot be
        // stored — flagged here rather than silently dropped on save.
        _field('${prefix}DoorNo', 'Door no', address.doorNo?.toString() ?? '',
            (v) => address.doorNo = int.tryParse(v.trim()),
            keyboardType: TextInputType.number, digitsOnly: true),
        _field('${prefix}Owner', 'House owner', address.houseOwnerName,
            (v) => address.houseOwnerName = v),
      ),
      _field('${prefix}Street', 'Street or road', address.streetOrRoad,
          (v) => address.streetOrRoad = v),
      _row(
        _field('${prefix}Post', 'Post', address.post, (v) => address.post = v),
        _field('${prefix}City', 'City', address.city, (v) => address.city = v),
      ),
      _row(
        _field(
            '${prefix}State', 'State', address.state, (v) => address.state = v),
        _field('${prefix}Pincode', 'Pincode', address.pincode,
            (v) => address.pincode = v,
            keyboardType: TextInputType.number, digitsOnly: true),
      ),
      _field('${prefix}Police', 'Police station limits',
          address.policeStationLimits, (v) => address.policeStationLimits = v),
    ];
  }

  void _copyPermanentAddress() {
    final permanent = _dto.addressBeanList[0];
    final temporary = _dto.addressBeanList[1];
    setState(() {
      temporary
        ..doorNo = permanent.doorNo
        ..houseOwnerName = permanent.houseOwnerName
        ..streetOrRoad = permanent.streetOrRoad
        ..post = permanent.post
        ..city = permanent.city
        ..pincode = permanent.pincode
        ..state = permanent.state
        ..policeStationLimits = permanent.policeStationLimits;
      // The visible text lives in the controllers, so they have to be moved
      // across too — updating the model alone leaves the old text on screen.
      _setText('tempDoorNo', permanent.doorNo?.toString() ?? '');
      _setText('tempOwner', permanent.houseOwnerName);
      _setText('tempStreet', permanent.streetOrRoad);
      _setText('tempPost', permanent.post);
      _setText('tempCity', permanent.city);
      _setText('tempState', permanent.state);
      _setText('tempPincode', permanent.pincode);
      _setText('tempPolice', permanent.policeStationLimits);
    });
  }

  void _setText(String key, String value) {
    final controller = _text[key];
    if (controller != null) controller.text = value;
  }

  Widget _educationSection() {
    return _section(
      id: 'education',
      title: 'Education Details',
      icon: Icons.school_outlined,
      subtitle: '${_dto.employeeEducationBeanList.length} entered',
      children: [
        ..._dto.employeeEducationBeanList.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return _repeatable(
            title: 'Education ${index + 1}',
            onRemove: _dto.employeeEducationBeanList.length > 1
                ? () => _removeChildRow(
                      id: row.id,
                      delete: ApiService.deleteEmployeeEducation,
                      removeLocally: () {
                        _dto.employeeEducationBeanList.removeAt(index);
                        _shiftRowDocuments('education', index);
                      },
                      what: 'education entry',
                    )
                : null,
            children: [
              _refDropdown('Qualification', _qualifications, row.qualification,
                  (v) => setState(() => row.qualification = v),
                  keySuffix: 'edu$index'),
              _refDropdown(
                  'Qualification area',
                  _qualificationAreas,
                  row.qualificationArea,
                  (v) => setState(() => row.qualificationArea = v),
                  keySuffix: 'edu$index'),
              _field('edu${index}Institute', 'Institute', row.institute,
                  (v) => row.institute = v),
              _row(
                _field('edu${index}Grade', 'Grade', row.grade,
                    (v) => row.grade = v),
                const SizedBox.shrink(),
              ),
              _row(
                _dateField('Start', row.startDate,
                    (d) => setState(() => row.startDate = d),
                    lastDate: DateTime.now()),
                _dateField(
                    'End', row.endDate, (d) => setState(() => row.endDate = d),
                    lastDate: DateTime.now()),
              ),
              _field('edu${index}Remarks', 'Remarks', row.remarks,
                  (v) => row.remarks = v),
              if (_onboardingRules)
                _attachmentRow('education_$index', 'Education certificate',
                    row.attachmentUrl),
            ],
          );
        }),
        _addRowButton(
            'Add education',
            () => setState(
                () => _dto.employeeEducationBeanList.add(EmployeeEducation()))),
      ],
    );
  }

  Widget _bankSection() {
    final bank = _dto.employeeBankDetails;
    return _section(
      id: 'bank',
      title: 'Bank Details',
      icon: Icons.account_balance_outlined,
      subtitle: _onboardingRules ? 'Required' : 'Optional',
      children: [
        _field('bankName', 'Bank name', bank.bankName, (v) => bank.bankName = v,
            required: _onboardingRules),
        _field('bankAccountNumber', 'Account number', bank.bankAccountNumber,
            (v) => bank.bankAccountNumber = v,
            required: _onboardingRules,
            keyboardType: TextInputType.number,
            digitsOnly: true),
        _field('bankIfscCode', 'IFSC code', bank.bankIfscCode,
            (v) => bank.bankIfscCode = v.toUpperCase(),
            required: _onboardingRules, upperCase: true),
        _field('accountType', 'Account type', bank.accountType,
            (v) => bank.accountType = v),
        _dateField('Account opening date', bank.accountOpeningDate,
            (d) => setState(() => bank.accountOpeningDate = d),
            lastDate: DateTime.now()),
        _row(
          _field('bankAadhaar', 'Aadhaar number', bank.aadhaarNumber,
              (v) => bank.aadhaarNumber = v,
              keyboardType: TextInputType.number, digitsOnly: true),
          _field('bankPan', 'PAN number', bank.panNumber,
              (v) => bank.panNumber = v,
              upperCase: true),
        ),
        _field('mobileNumber', 'Mobile number', bank.mobileNumber,
            (v) => bank.mobileNumber = v,
            keyboardType: TextInputType.phone, digitsOnly: true),
        const SizedBox(height: 6),
        // Yes/No strings, not booleans — the columns are varchars and a real
        // boolean is rejected.
        _choice('ESIC', bank.esicInclude, const ['Yes', 'No'],
            (v) => setState(() => bank.esicInclude = v)),
        if (bank.esicInclude == 'Yes')
          _field('esicNumber', 'ESIC number', bank.esicNumber,
              (v) => bank.esicNumber = v),
        _choice('PF', bank.pfInclude, const ['Yes', 'No'],
            (v) => setState(() => bank.pfInclude = v)),
        if (bank.pfInclude == 'Yes') ...[
          _field(
              'pfNumber', 'PF number', bank.pfNumber, (v) => bank.pfNumber = v),
          _field('uanNumber', 'UAN number', bank.uanNumber,
              (v) => bank.uanNumber = v),
        ],
        _choice('LWF', bank.lwfInclude, const ['Yes', 'No'],
            (v) => setState(() => bank.lwfInclude = v)),
        if (_onboardingRules)
          _attachmentRow(
              'bank', 'Bank passbook / cancelled cheque', bank.attachmentUrl,
              required: true),
      ],
    );
  }

  Widget _familySection() {
    return _section(
      id: 'family',
      title: 'Family Details',
      icon: Icons.family_restroom_outlined,
      subtitle:
          '${_onboardingRules ? 'Required · ' : ''}${_dto.employeeFamilyBeanList.length} entered',
      children: [
        ..._dto.employeeFamilyBeanList.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return _repeatable(
            title: 'Member ${index + 1}',
            onRemove: _dto.employeeFamilyBeanList.length > 1
                ? () => _removeChildRow(
                      id: row.id,
                      delete: ApiService.deleteEmployeeFamily,
                      removeLocally: () {
                        _dto.employeeFamilyBeanList.removeAt(index);
                        _shiftRowDocuments('family_member', index);
                        if (_emergencyIndex == index) {
                          _emergencyIndex = null;
                        } else if ((_emergencyIndex ?? -1) > index) {
                          _emergencyIndex = _emergencyIndex! - 1;
                        }
                      },
                      what: 'family member',
                    )
                : null,
            children: [
              _field('fam${index}Name', 'Name', row.name, (v) => row.name = v,
                  required: _onboardingRules),
              _row(
                _field('fam${index}Rel', 'Relationship', row.relationship,
                    (v) => row.relationship = v,
                    required: _onboardingRules),
                _field('fam${index}Contact', 'Contact no', row.contactNo,
                    (v) => row.contactNo = v,
                    required: _onboardingRules,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    digitsOnly: true),
              ),
              _row(
                _dateField('Date of birth', row.dateOfBirth,
                    (d) => setState(() => row.dateOfBirth = d),
                    lastDate: DateTime.now()),
                _field('fam${index}Age', 'Age', row.age?.toString() ?? '',
                    (v) => row.age = int.tryParse(v.trim()),
                    keyboardType: TextInputType.number, digitsOnly: true),
              ),
              _field(
                  'fam${index}Email', 'Email', row.email, (v) => row.email = v,
                  keyboardType: TextInputType.emailAddress),
              _field('fam${index}Address', 'Address', row.address,
                  (v) => row.address = v,
                  required: _onboardingRules, maxLines: 2),
              _row(
                _field('fam${index}City', 'City', row.city, (v) => row.city = v,
                    required: _onboardingRules),
                _field('fam${index}Pin', 'Pincode', row.pincode,
                    (v) => row.pincode = v,
                    required: _onboardingRules,
                    keyboardType: TextInputType.number,
                    digitsOnly: true),
              ),
              // No editable "Family member id": on the web that column holds
              // the member's ID-card link, so typing into it would break it.
              _field('fam${index}Country', 'Country', row.country,
                  (v) => row.country = v,
                  required: _onboardingRules),
              _field('fam${index}Remarks', 'Remarks', row.remarks,
                  (v) => row.remarks = v),
              // `familyMemberId` holds the stored ID-card link.
              _attachmentRow(
                  'family_member_$index', 'ID card', row.familyMemberId),
              if (_onboardingRules)
                _choice(
                  'Emergency contact',
                  _emergencyIndex == index ? 'Yes' : 'No',
                  const ['Yes', 'No'],
                  (v) => setState(() {
                    if (v == 'Yes') {
                      _emergencyIndex = index;
                    } else if (_emergencyIndex == index) {
                      _emergencyIndex = null;
                    }
                  }),
                  note: _emergencyIndex == index &&
                          row.contactNo.trim().isNotEmpty &&
                          row.contactNo.trim() ==
                              _dto.employeeBean.phoneNumber.trim()
                      ? 'Emergency contact number must be different from the employee phone number'
                      : null,
                ),
            ],
          );
        }),
        _addRowButton(
            'Add family member',
            () => setState(
                () => _dto.employeeFamilyBeanList.add(EmployeeFamily()))),
      ],
    );
  }

  Widget _experienceSection() {
    return _section(
      id: 'experience',
      title: 'Employee Experience',
      icon: Icons.history_edu_outlined,
      subtitle: '${_dto.employeeExperienceBeanList.length} entered',
      children: [
        ..._dto.employeeExperienceBeanList.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return _repeatable(
            title: 'Experience ${index + 1}',
            onRemove: _dto.employeeExperienceBeanList.length > 1
                ? () => _removeChildRow(
                      id: row.id,
                      delete: ApiService.deleteEmployeeExperience,
                      removeLocally: () {
                        _dto.employeeExperienceBeanList.removeAt(index);
                        _shiftRowDocuments('experience', index);
                      },
                      what: 'experience entry',
                    )
                : null,
            children: [
              _field('exp${index}Company', 'Company', row.companyName,
                  (v) => row.companyName = v),
              _row(
                _field('exp${index}Title', 'Job title', row.jobTitle,
                    (v) => row.jobTitle = v),
                _field('exp${index}Desig', 'Designation', row.designation,
                    (v) => row.designation = v),
              ),
              _row(
                _dateField('Start', row.startDate,
                    (d) => setState(() => row.startDate = d),
                    lastDate: DateTime.now()),
                _dateField(
                    'End', row.endDate, (d) => setState(() => row.endDate = d),
                    lastDate: DateTime.now()),
              ),
              _field('exp${index}Desc', 'Job description', row.jobdescription,
                  (v) => row.jobdescription = v,
                  maxLines: 3),
              if (_onboardingRules)
                _attachmentRow('experience_$index', 'Experience letter',
                    row.attachmentUrl),
            ],
          );
        }),
        _addRowButton(
            'Add experience',
            () => setState(() =>
                _dto.employeeExperienceBeanList.add(EmployeeExperience()))),
      ],
    );
  }

  Widget _documentsSection() {
    return _section(
      id: 'documents',
      title: 'Documents',
      icon: Icons.folder_outlined,
      subtitle: _documentSlots.every((d) => _pickedDocuments[d.prefix] == null)
          ? 'Aadhaar required · PAN, Voter ID, Passport, Ration card'
          : '${_documentSlots.where((d) => _pickedDocuments[d.prefix] != null).length} ready to upload',
      children: [
        for (final slot in _documentSlots)
          _attachmentRow(slot.prefix, slot.label, _storedDocument(slot.field),
              required: slot.prefix == 'Adhar_card'),
        const SizedBox(height: 8),
        Text(
          'Files are uploaded with the record when you save. A document already '
          'on the record stays there unless you pick a new one.',
          style: TextStyle(color: AppColors.textFaint, fontSize: 11),
        ),
      ],
    );
  }

  String _extension(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot < 0 ? 'jpg' : name.substring(dot + 1).toLowerCase();
  }

  /// One upload: a file picked now, one already on the record, or neither.
  Widget _attachmentRow(String docKey, String label, String stored,
      {bool required = false}) {
    final picked = _pickedDocuments[docKey];
    final hasStored = stored.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            picked != null
                ? Icons.check_circle
                : hasStored
                    ? Icons.description_outlined
                    : Icons.upload_file_outlined,
            size: 18,
            color: picked != null
                ? AppColors.success
                : hasStored
                    ? AppColors.primary
                    : AppColors.textFaint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(required ? '$label *' : label,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(
                  picked != null
                      ? picked.path.split('/').last
                      : hasStored
                          ? 'On record'
                          : 'Not uploaded',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (picked != null || hasStored)
            IconButton(
              tooltip: 'View',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.visibility_outlined,
                  size: 18, color: AppColors.primary),
              onPressed: () => _viewDocument(label, picked, stored),
            ),
          if (picked != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
              onPressed: () => setState(() => _pickedDocuments.remove(docKey)),
            ),
          TextButton(
            onPressed: () => _pickDocument(docKey),
            child: Text(picked != null || hasStored ? 'Replace' : 'Upload',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  bool _isImageName(String name) {
    final ext = _extension(name.split('?').first);
    return ext == 'jpg' || ext == 'jpeg' || ext == 'png';
  }

  /// The web's "View": the file picked in this session if there is one (what
  /// will be saved), otherwise the copy on the record. Images open in the app;
  /// PDFs go to the phone's own viewer.
  Future<void> _viewDocument(String label, File? picked, String stored) async {
    if (picked != null) {
      if (_isImageName(picked.path)) {
        _showImage(label, Image.file(picked, fit: BoxFit.contain));
      } else {
        await _openExternally(picked.path);
      }
      return;
    }

    final url = stored.trim();
    // Older records hold a bare file name rather than a link; the server
    // cannot fetch those, so say so instead of failing quietly.
    if (!url.startsWith('http')) {
      _toast('This $label link is broken. Please upload it again.',
          error: true);
      return;
    }

    _showBusy();
    try {
      final response = await ApiService.downloadEmployeeDocument(
          label.replaceAll(' ', '_'), url);
      final type = response.headers['content-type'] ?? '';
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.isEmpty ||
          type.contains('html') ||
          type.contains('json') ||
          type.contains('xml')) {
        debugPrint('Employee form: view $label failed '
            '${response.statusCode} $type');
        _hideBusy();
        _toast(
            response.statusCode == 404
                ? 'This $label was not found. Please upload it again.'
                : 'Could not open the $label. Please try again.',
            error: true);
        return;
      }
      _hideBusy();
      if (type.startsWith('image/')) {
        _showImage(
            label, Image.memory(response.bodyBytes, fit: BoxFit.contain));
        return;
      }
      final name = url.split('?').first.split('/').last;
      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/view_${DateTime.now().millisecondsSinceEpoch}'
              '.${type.contains('pdf') ? 'pdf' : _extension(name)}');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      await _openExternally(file.path);
    } catch (e) {
      debugPrint('Employee form: view $label error $e');
      _hideBusy();
      _toast('Could not open the $label. Check your connection.', error: true);
    }
  }

  Future<void> _openExternally(String path) async {
    final result = await OpenFile.open(path);
    if (result.type != ResultType.done) {
      debugPrint('Employee form: open file ${result.type} ${result.message}');
      _toast('No app found on this phone to open this file.', error: true);
    }
  }

  bool _busyShown = false;

  void _showBusy() {
    _busyShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
    ).then((_) => _busyShown = false);
  }

  void _hideBusy() {
    // Cleared here, not only in the dialog's `then` (which runs a frame
    // later), so a second call cannot pop the form itself.
    if (!_busyShown || !mounted) return;
    _busyShown = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _showImage(String label, Widget image) {
    showDialog<void>(
      context: context,
      builder: (dialog) => Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(dialog),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                // Pinch to zoom — card photos are read at a glance otherwise.
                child: InteractiveViewer(maxScale: 5, child: image),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _storedDocument(String field) {
    final bean = _dto.employeeBean;
    switch (field) {
      case 'adharUrl':
        return bean.adharUrl;
      case 'panUrl':
        return bean.panUrl;
      case 'voterIdUrl':
        return bean.voterIdUrl;
      case 'passPortUrl':
        return bean.passPortUrl;
      case 'rationCardUrl':
        return bean.rationCardUrl;
      default:
        return '';
    }
  }

  /// Camera or file. A photo of the card is the common case on a phone; a
  /// file covers PDFs and scans. Both end up as jpg/jpeg/png/pdf — the types
  /// the web accepts.
  Future<void> _pickDocument(String docKey) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.primary),
              title: Text('Take photo',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(sheet, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined,
                  color: AppColors.primary),
              title: Text('Choose file',
                  style: TextStyle(color: AppColors.textPrimary)),
              subtitle: Text('JPG, PNG or PDF',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
              onTap: () => Navigator.pop(sheet, 'file'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      String? path;
      if (source == 'camera') {
        // Compressed: a full-resolution photo is several MB per document and
        // all of them go up in one request.
        final photo = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 70,
          maxWidth: 2000,
        );
        path = photo?.path;
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
        );
        path = result?.files.single.path;
      }
      if (path == null) return;
      setState(() => _pickedDocuments[docKey] = File(path!));
    } catch (e) {
      debugPrint('Employee form: document pick error $e');
      _toast(
          source == 'camera'
              ? 'Could not open the camera. Check camera permission.'
              : 'Could not open the file picker.',
          error: true);
    }
  }

  // ----------------------------------------------------------------- pieces

  Widget _row(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }

  Widget _field(
    String key,
    String label,
    String initial,
    ValueChanged<String> onChanged, {
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    bool digitsOnly = false,
    bool upperCase = false,
    String? Function(String?)? validator,
    VoidCallback? onBlur,
  }) {
    final input = TextFormField(
      controller: _controller(key, initial),
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization:
          upperCase ? TextCapitalization.characters : TextCapitalization.none,
      inputFormatters: [
        if (digitsOnly) FilteringTextInputFormatter.digitsOnly,
        if (upperCase) _UpperCaseFormatter(),
      ],
      style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      cursorColor: AppColors.primary,
      decoration: fieldDecoration(required ? '$label *' : label)
          .copyWith(counterText: ''),
      onChanged: onChanged,
      validator: validator ??
          (required
              ? (value) =>
                  (value ?? '').trim().isEmpty ? '$label is required.' : null
              : null),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      // The web runs its duplicate checks on blur.
      child: onBlur == null
          ? input
          : Focus(
              skipTraversal: true,
              onFocusChange: (hasFocus) {
                if (!hasFocus) onBlur();
              },
              child: input,
            ),
    );
  }

  Widget _dateField(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onChanged, {
    bool required = false,
    DateTime? lastDate,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(1940),
            lastDate: lastDate ?? DateTime(2100),
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
          if (picked != null) onChanged(picked);
        },
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: fieldDecoration(required ? '$label *' : label),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value == null ? '—' : DateFormat('dd MMM yyyy').format(value),
                  style: TextStyle(
                      color: value == null
                          ? AppColors.textFaint
                          : AppColors.textPrimary,
                      fontSize: 14),
                ),
              ),
              if (value != null)
                InkWell(
                  onTap: () => onChanged(null),
                  child:
                      Icon(Icons.close, size: 16, color: AppColors.textFaint),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.calendar_today,
                  size: 15, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  /// A short fixed list, as chips. Faster than a dropdown for two or three
  /// options and shows what was chosen without opening anything.
  Widget _choice(String label, String value, List<String> options,
      ValueChanged<String> onChanged,
      {bool required = false, bool enabled = true, String? note}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(required ? '$label *' : label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          _choiceRaw(value, options, onChanged, enabled: enabled),
          if (note != null) ...[
            const SizedBox(height: 5),
            Text(note,
                style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _choiceRaw(
      String value, List<String> options, ValueChanged<String> onChanged,
      {bool enabled = true}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final selected = value.toLowerCase() == option.toLowerCase();
        return ChoiceChip(
          label: Text(option),
          selected: selected,
          showCheckmark: false,
          backgroundColor: AppColors.surfaceAlt,
          selectedColor: AppColors.primary,
          // A locked chip still has to show which way it is set, so the
          // selected one keeps the brand fill and only dims.
          disabledColor: selected
              ? AppColors.primary.withOpacity(0.55)
              : AppColors.surfaceAlt,
          side: BorderSide(color: AppColors.divider),
          labelStyle: TextStyle(
            color: selected
                ? AppColors.onPrimary
                : enabled
                    ? AppColors.textSecondary
                    : AppColors.textFaint,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          onSelected: enabled ? (_) => onChanged(option) : null,
        );
      }).toList(),
    );
  }

  /// A reference dropdown that stores the row's id.
  Widget _refDropdown(String label, List<RefOption> options, int? value,
      ValueChanged<int?> onChanged,
      {bool required = false, String keySuffix = ''}) {
    // A value that is not in the list would throw rather than render — an
    // option that has since been deactivated shows as unset instead.
    final safe = options.any((o) => o.id == value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField2<int?>(
        key: ValueKey('$label$keySuffix'),
        isExpanded: true,
        value: safe,
        decoration: fieldDecoration(required ? '$label *' : label),
        dropdownStyleData: menuStyle(context),
        menuItemStyleData: kMenuItemStyle,
        items: options
            .map((o) => DropdownMenuItem<int?>(
                  value: o.id,
                  child: Text(o.value, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: onChanged,
        validator: required
            ? (value) => value == null ? '$label is required.' : null
            : null,
      ),
    );
  }

  /// A reference dropdown that stores the row's LABEL rather than its id —
  /// designation and employee status are varchar columns on the employee.
  Widget _refDropdownByValue(String label, List<RefOption> options,
      String value, ValueChanged<String> onChanged,
      {bool required = false}) {
    final safe = options.any((o) => o.value == value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField2<String?>(
        isExpanded: true,
        value: safe,
        decoration: fieldDecoration(required ? '$label *' : label),
        dropdownStyleData: menuStyle(context),
        menuItemStyleData: kMenuItemStyle,
        items: options
            .map((o) => DropdownMenuItem<String?>(
                  value: o.value,
                  child: Text(o.value, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (v) => onChanged(v ?? ''),
        validator: required
            ? (v) => (v ?? '').trim().isEmpty ? '$label is required.' : null
            : null,
      ),
    );
  }

  /// A fixed list of strings as a dropdown. A stored value outside the list is
  /// still shown, so an older record does not render as unset.
  Widget _stringDropdown(String label, List<String> options, String value,
      ValueChanged<String> onChanged,
      {bool required = false}) {
    final items = [
      ...options,
      if (value.trim().isNotEmpty && !options.contains(value)) value,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField2<String?>(
        isExpanded: true,
        value: value.trim().isEmpty ? null : value,
        decoration: fieldDecoration(required ? '$label *' : label),
        dropdownStyleData: menuStyle(context),
        menuItemStyleData: kMenuItemStyle,
        items: items
            .map((o) => DropdownMenuItem<String?>(value: o, child: Text(o)))
            .toList(),
        onChanged: (v) => onChanged(v ?? ''),
        validator: required
            ? (v) => (v ?? '').trim().isEmpty ? '$label is required.' : null
            : null,
      ),
    );
  }

  /// A dropdown with a search box, for the lists that run long — projects,
  /// managers, roles and work locations all do at this organisation.
  Widget _searchableRefDropdown<T>({
    required String key,
    required String label,
    required int? value,
    required List<T> items,
    required int Function(T) idOf,
    required String Function(T) labelOf,
    required ValueChanged<int?> onChanged,
    bool required = false,
  }) {
    final controller = _searchController(key);
    final safe = items.any((e) => idOf(e) == value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField2<int?>(
        isExpanded: true,
        value: safe,
        decoration: fieldDecoration(required ? '$label *' : label),
        dropdownStyleData: menuStyle(context, maxHeight: 340),
        menuItemStyleData: kMenuItemStyle,
        dropdownSearchData: DropdownSearchData<int?>(
          searchController: controller,
          searchInnerWidgetHeight: kMenuSearchHeight,
          searchInnerWidget: menuSearchField(controller, 'Search $label'),
          // Matches the label shown in the row. The default compares
          // item.value.toString(), which for an int id finds nothing.
          searchMatchFn: (item, query) {
            final needle = query.trim().toLowerCase();
            if (needle.isEmpty) return true;
            final match = items.where((e) => idOf(e) == item.value);
            if (match.isEmpty) return false;
            return labelOf(match.first).toLowerCase().contains(needle);
          },
        ),
        onMenuStateChange: (isOpen) {
          if (!isOpen) controller.clear();
        },
        items: items
            .map((e) => DropdownMenuItem<int?>(
                  value: idOf(e),
                  child: Text(labelOf(e), overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: onChanged,
        validator: required
            ? (value) => value == null ? '$label is required.' : null
            : null,
      ),
    );
  }

  Widget _repeatable({
    required String title,
    required List<Widget> children,
    VoidCallback? onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              if (onRemove != null)
                InkWell(
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline,
                        size: 18, color: AppColors.danger),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _addRowButton(String label, VoidCallback onTap) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
    );
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
}

class _DocumentSlot {
  final String field;
  final String label;

  /// The web's docType, prepended to the uploaded filename.
  final String prefix;

  const _DocumentSlot(this.field, this.label, this.prefix);
}

/// A required answer that is missing, and the section it lives in.
class _Missing {
  final String section;
  final String message;

  const _Missing(this.section, this.message);
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
