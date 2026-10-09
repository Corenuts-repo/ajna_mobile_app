import 'dart:convert';
import 'dart:io';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/connectivity_handler.dart';
import 'package:ajna/screens/hrm/employee_form_screen.dart';
import 'package:ajna/screens/hrm/employee_models.dart';
import 'package:ajna/screens/util.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/form_fields.dart';
import 'package:ajna/theme/responsive.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The employee register, as the web shows it at `employee/displayemployee`.
///
/// The same eight filters, the same paged list, and the same single row action
/// — edit. The web's delete is commented out of its own template, so it is not
/// offered here either: an action the web deliberately withdrew is not one to
/// reintroduce on a phone, where the mis-tap is easier.
class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final ConnectivityHandler _connectivityHandler = ConnectivityHandler();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _projectSearchController =
      TextEditingController();
  final TextEditingController _managerSearchController =
      TextEditingController();

  static const int _pageSize = 15;

  int? _organizationId;
  String? _roleName;

  List<ProjectOption> _projects = [];
  List<RoleOption> _roles = [];
  List<ManagerOption> _managers = [];
  List<RefOption> _shifts = [];

  int? _projectId;
  int? _roleId;
  int? _managerId;
  int? _shiftId;

  /// Fixed at Active. The web's Status filter is commented out of its template
  /// — resigned staff have their own register — so it is not offered here.
  static const String _status = 'A';
  String _name = '';
  String _number = '';
  String _designation = '';

  List<EmployeeListRow> _rows = [];
  int _page = 0;
  int _totalRecords = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _filtersExpanded = false;
  bool _uploadingManagers = false;
  String? _error;

  /// The web shows the Role column to TECH ADMIN only.
  bool get _showsRole => (_roleName ?? '').toUpperCase() == 'TECH ADMIN';

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
    _nameController.dispose();
    _numberController.dispose();
    _designationController.dispose();
    _projectSearchController.dispose();
    _managerSearchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final connected = await _connectivityHandler.checkConnectivity(context);
    if (!connected) return;

    _organizationId = await Util.getOrganizationId();
    _roleName = await Util.getRoleName();

    await Future.wait([
      _fetchProjects(),
      _fetchRoles(),
      _fetchManagers(),
      _fetchShifts(),
    ]);

    if (!mounted) return;
    await _fetch(reset: true);
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

  Future<void> _fetchProjects() async {
    try {
      final response = await ApiService.fetchOrgProjects(_organizationId!);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() =>
            _projects = data.map((e) => ProjectOption.fromJson(e)).toList());
      } else {
        debugPrint('Employees: projects failed ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Employees: projects error $e');
    }
  }

  Future<void> _fetchRoles() async {
    try {
      final response = await ApiService.fetchOrgRoles(_organizationId!);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (!mounted) return;
        setState(
            () => _roles = data.map((e) => RoleOption.fromJson(e)).toList());
      } else {
        debugPrint('Employees: roles failed ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Employees: roles error $e');
    }
  }

  Future<void> _fetchManagers() async {
    try {
      final response = await ApiService.fetchOrgManagers(_organizationId!);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() =>
            _managers = data.map((e) => ManagerOption.fromJson(e)).toList());
      } else {
        debugPrint('Employees: managers failed ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Employees: managers error $e');
    }
  }

  Future<void> _fetchShifts() async {
    try {
      final response = await ApiService.fetchshiftData();
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (!mounted) return;
        setState(
            () => _shifts = data.map((e) => RefOption.fromJson(e)).toList());
      } else {
        debugPrint('Employees: shifts failed ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Employees: shifts error $e');
    }
  }

  // ------------------------------------------------------------------- list

  Future<void> _fetch({bool reset = false}) async {
    if (_organizationId == null) return;

    if (reset) {
      _page = 0;
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await ApiService.getEmployees(
        organizationId: _organizationId!,
        page: _page,
        size: _pageSize,
        projectAssigned: _projectId?.toString() ?? '',
        employeeRoleId: _roleId?.toString() ?? '',
        reportingManager: _managerId?.toString() ?? '',
        employeeId: _number,
        status: _status,
        firstName: _name,
        shiftId: _shiftId?.toString() ?? '',
        designation: _designation,
      );

      if (response.statusCode != 200) {
        debugPrint(
            'Employees: list failed ${response.statusCode} ${response.body}');
        if (!mounted) return;
        setState(() {
          if (reset) _rows = [];
          _loading = false;
          _error = 'Could not load employees. Please try again.';
        });
        return;
      }

      final decoded = jsonDecode(response.body);
      final List<dynamic> records =
          (decoded is Map && decoded['records'] is List)
              ? decoded['records']
              : <dynamic>[];
      final fetched = records.map((e) => EmployeeListRow.fromJson(e)).toList();

      if (!mounted) return;
      setState(() {
        if (reset) {
          _rows = fetched;
        } else {
          _rows.addAll(fetched);
        }
        _totalRecords = (decoded is Map && decoded['totalRecords'] != null)
            ? int.tryParse('${decoded['totalRecords']}') ?? _rows.length
            : _rows.length;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('Employees: list error $e');
      if (!mounted) return;
      setState(() {
        if (reset) _rows = [];
        _loading = false;
        _error = 'Could not reach the server. Please check your connection.';
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    _page += 1;
    await _fetch();
    if (!mounted) return;
    setState(() => _loadingMore = false);
  }

  void _reload() {
    FocusScope.of(context).unfocus();
    _fetch(reset: true);
  }

  void _clearFilters() {
    setState(() {
      _projectId = null;
      _roleId = null;
      _managerId = null;
      _shiftId = null;
      _name = '';
      _number = '';
      _designation = '';
      _nameController.clear();
      _numberController.clear();
      _designationController.clear();
    });
    _reload();
  }

  // ---------------------------------------------------------------- actions

  /// The edit form is handed the row's id and loads the whole record itself.
  ///
  /// It has to: an update replaces every section, so the form must start from
  /// what is stored rather than from the handful of fields the list carries.
  Future<void> _openForm({int? employeeId}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeFormScreen(employeeRowId: employeeId),
      ),
    );
    if (saved == true) {
      // The web's confirmation, shown once the list is back.
      _toast(employeeId == null
          ? 'Employee added successfully'
          : 'Employee updated successfully');
      await _fetch(reset: true);
    }
  }

  /// The web's "Upload Managers": an Excel sheet that reassigns reporting
  /// managers in bulk. TECH ADMIN only, as on the web.
  Future<void> _uploadManagers() async {
    final String? path;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls'],
      );
      path = result?.files.single.path;
    } catch (e) {
      debugPrint('Employees: manager file pick error $e');
      _toast('Could not open the file picker.', error: true);
      return;
    }
    if (path == null) return;

    setState(() => _uploadingManagers = true);
    try {
      final response = await ApiService.uploadManagersExcel(File(path));
      final message = _serverMessage(response.body);
      if (ApiService.isSuccess(response.statusCode)) {
        _toast(message ?? 'Managers updated successfully');
        await _fetch(reset: true);
      } else {
        debugPrint('Employees: manager upload failed '
            '${response.statusCode} ${response.body}');
        _toast(message ?? 'Failed to upload managers file', error: true);
      }
    } catch (e) {
      debugPrint('Employees: manager upload error $e');
      _toast('Could not reach the server. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _uploadingManagers = false);
    }
  }

  String? _serverMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      final message = decoded is Map ? decoded['message'] : null;
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    } catch (_) {
      // Not JSON — the caller's friendly fallback stands.
    }
    return null;
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
          'Employees',
          style: TextStyle(
            fontSize: screenWidth > 600 ? 22 : 18,
            color: AppColors.onPrimary,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.onPrimary),
        actions: [
          if (_showsRole)
            _uploadingManagers
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onPrimary),
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Upload managers',
                    icon: const Icon(Icons.upload_file),
                    onPressed: _uploadManagers,
                  ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('ADD'),
      ),
      body: ContentWidthLimit(
        maxWidth: 760,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () => _fetch(reset: true),
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            children: [
              _filterCard(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _banner(_error!),
              ],
              const SizedBox(height: 12),
              ..._list(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _list() {
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
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            children: [
              Icon(Icons.badge_outlined, size: 42, color: AppColors.textFaint),
              const SizedBox(height: 12),
              Text('No employees found for the selected filters.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ],
          ),
        ),
      ];
    }

    return [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text('$_totalRecords employees',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
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
        ),
    ];
  }

  Widget _card(EmployeeListRow row) {
    final working = row.employeeStatus.trim().toLowerCase() == 'working';
    return InkWell(
      onTap: () => _openForm(employeeId: row.id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.fullName,
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (row.employeeId.isNotEmpty) row.employeeId,
                          if (row.gender.isNotEmpty) row.gender,
                          if (row.designation.isNotEmpty) row.designation,
                          if (_showsRole && row.employeeRoleName.isNotEmpty)
                            row.employeeRoleName,
                        ].join(' · '),
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (row.employeeStatus.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (working ? AppColors.success : AppColors.danger)
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(row.employeeStatus,
                        style: TextStyle(
                            color:
                                working ? AppColors.success : AppColors.danger,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 20, color: AppColors.textFaint),
              ],
            ),
            const SizedBox(height: 8),
            if (row.projectName.isNotEmpty)
              _line(Icons.apartment, row.projectName),
            if (row.reportingManagerName.isNotEmpty)
              _line(Icons.supervisor_account_outlined,
                  'Reports to ${row.reportingManagerName}'),
            if (row.shiftTiming.isNotEmpty)
              _line(Icons.schedule, row.shiftTiming),
            if (row.dateOfJoining != null)
              _line(Icons.event_available,
                  'Joined ${DateFormat('dd MMM yyyy').format(row.dateOfJoining!)}'),
            if (row.phoneNumber.isNotEmpty || row.email.isNotEmpty)
              _line(
                  Icons.contact_phone_outlined,
                  [
                    if (row.phoneNumber.isNotEmpty) row.phoneNumber,
                    if (row.email.isNotEmpty) row.email,
                  ].join(' · ')),
          ],
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppColors.textFaint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- filters

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
                    child: Text(_filterSummary,
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Icon(_filtersExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          if (_filtersExpanded) ...[
            const SizedBox(height: 8),
            _searchableDropdown<ProjectOption>(
              label: 'Project',
              value: _projectId,
              controller: _projectSearchController,
              hint: 'Search site',
              items: _projects,
              idOf: (p) => p.projectId,
              labelOf: (p) => p.projectName,
              onChanged: (value) {
                setState(() => _projectId = value);
                _reload();
              },
            ),
            const SizedBox(height: 12),
            _searchableDropdown<ManagerOption>(
              label: 'Reporting manager',
              value: _managerId,
              controller: _managerSearchController,
              hint: 'Search manager',
              items: _managers,
              idOf: (m) => m.userId,
              labelOf: (m) => m.userName,
              onChanged: (value) {
                setState(() => _managerId = value);
                _reload();
              },
            ),
            const SizedBox(height: 12),
            // The web offers the Role filter to TECH ADMIN only, the same users
            // who see the Role column.
            if (_showsRole) ...[
              DropdownButtonFormField2<int?>(
                isExpanded: true,
                value: _roleId,
                decoration: fieldDecoration('Role'),
                dropdownStyleData: menuStyle(context),
                menuItemStyleData: kMenuItemStyle,
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('All roles')),
                  ..._roles.map((r) => DropdownMenuItem<int?>(
                        value: r.roleId,
                        child:
                            Text(r.roleName, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _roleId = value);
                  _reload();
                },
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField2<int?>(
              isExpanded: true,
              value: _shiftId,
              decoration: fieldDecoration('Shift timings'),
              dropdownStyleData: menuStyle(context),
              menuItemStyleData: kMenuItemStyle,
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('All shifts')),
                ..._shifts.map((s) => DropdownMenuItem<int?>(
                      value: s.id,
                      child: Text(s.value, overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (value) {
                setState(() => _shiftId = value);
                _reload();
              },
            ),
            const SizedBox(height: 12),
            _searchField(_nameController, 'Employee name',
                (value) => setState(() => _name = value)),
            const SizedBox(height: 12),
            // The web waits for three characters on these two before it
            // searches — a single letter matches most of the register and is a
            // full page fetch for nothing.
            _searchField(_numberController, 'Employee number',
                (value) => setState(() => _number = value),
                minLength: 3),
            const SizedBox(height: 12),
            _searchField(_designationController, 'Designation',
                (value) => setState(() => _designation = value),
                minLength: 3),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear filters'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchField(
    TextEditingController controller,
    String label,
    void Function(String) apply, {
    int minLength = 0,
  }) {
    void submit() {
      final text = controller.text.trim();
      if (text.isNotEmpty && text.length < minLength) return;
      apply(text);
      _reload();
    }

    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      style: TextStyle(color: AppColors.textPrimary),
      cursorColor: AppColors.primary,
      onSubmitted: (_) => submit(),
      decoration: fieldDecoration(label).copyWith(
        suffixIcon: IconButton(
          icon: const Icon(Icons.search, color: AppColors.primary),
          onPressed: submit,
        ),
      ),
    );
  }

  /// A dropdown with a search box, for the two lists that run long.
  Widget _searchableDropdown<T>({
    required String label,
    required int? value,
    required TextEditingController controller,
    required String hint,
    required List<T> items,
    required int Function(T) idOf,
    required String Function(T) labelOf,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField2<int?>(
      isExpanded: true,
      value: value,
      decoration: fieldDecoration(label),
      dropdownStyleData: menuStyle(context, maxHeight: 340),
      menuItemStyleData: kMenuItemStyle,
      dropdownSearchData: DropdownSearchData<int?>(
        searchController: controller,
        searchInnerWidgetHeight: kMenuSearchHeight,
        searchInnerWidget: menuSearchField(controller, hint),
        searchMatchFn: (item, query) {
          final needle = query.trim().toLowerCase();
          if (needle.isEmpty) return true;
          if (item.value == null) return true;
          final match = items.where((e) => idOf(e) == item.value);
          if (match.isEmpty) return false;
          return labelOf(match.first).toLowerCase().contains(needle);
        },
      ),
      onMenuStateChange: (isOpen) {
        if (!isOpen) controller.clear();
      },
      items: [
        DropdownMenuItem<int?>(value: null, child: Text('All  $label'.trim())),
        ...items.map((e) => DropdownMenuItem<int?>(
              value: idOf(e),
              child: Text(labelOf(e), overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: onChanged,
    );
  }

  String get _filterSummary {
    String nameOf<T>(List<T> pool, int? id, int Function(T) idOf,
        String Function(T) labelOf) {
      if (id == null) return '';
      final match = pool.where((e) => idOf(e) == id);
      return match.isEmpty ? '' : labelOf(match.first);
    }

    final parts = <String>[
      nameOf(_projects, _projectId, (p) => p.projectId, (p) => p.projectName),
      nameOf(_roles, _roleId, (r) => r.roleId, (r) => r.roleName),
      nameOf(_managers, _managerId, (m) => m.userId, (m) => m.userName),
      nameOf(_shifts, _shiftId, (s) => s.id, (s) => s.value),
      _name,
      _number,
      _designation,
    ].where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? 'All employees' : parts.join(' · ');
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
