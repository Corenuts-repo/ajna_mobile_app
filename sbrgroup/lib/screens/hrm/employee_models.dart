/// The employee record, in the exact shape hrm-service reads and writes.
///
/// FIELD NAMES ARE THE CONTRACT. Every key here matches a field on the Java
/// bean of the same name, because the update endpoint REPLACES the stored
/// record with what it is sent — a misspelled key does not error, it silently
/// writes null over whatever was there. Nothing in this file is renamed to read
/// better in Dart, including the backend's own typos (`plcaeOfBirth`,
/// `esiDisrubbed`, `jobdescription`); those are the wire names.
library;

/// Anything unset is left out of the JSON rather than sent as null.
///
/// The backend maps the DTO onto the stored row field by field, so a key that
/// is present and null clears the column. Omitting it leaves the column alone —
/// which is what a form that never showed the field should do.
void _put(Map<String, dynamic> json, String key, dynamic value) {
  if (value == null) return;
  if (value is String && value.trim().isEmpty) return;
  json[key] = value;
}

/// A `LocalDate` on the wire is `yyyy-MM-dd`.
String? dateToWire(DateTime? date) {
  if (date == null) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

DateTime? dateFromWire(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

int? _int(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString());
}

String _str(dynamic v) => v?.toString() ?? '';

String? _optional(dynamic v) {
  final text = v?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

// ---------------------------------------------------------------------------
// The list row
// ---------------------------------------------------------------------------

/// One row of the employee list. Mirrors the backend's EmployeeDto, which
/// resolves the manager, role, project and shift NAMES so the list needs no
/// lookups of its own.
class EmployeeListRow {
  final int id;
  final String employeeId;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String gender;
  final String designation;
  final DateTime? dateOfJoining;
  final String employeeStatus;
  final String reportingManagerName;
  final String employeeRoleName;
  final String projectName;
  final String shiftTiming;
  final String status;

  EmployeeListRow({
    required this.id,
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.gender,
    required this.designation,
    required this.dateOfJoining,
    required this.employeeStatus,
    required this.reportingManagerName,
    required this.employeeRoleName,
    required this.projectName,
    required this.shiftTiming,
    required this.status,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory EmployeeListRow.fromJson(Map<String, dynamic> json) {
    return EmployeeListRow(
      id: _int(json['id']) ?? 0,
      employeeId: _str(json['employeeId']),
      firstName: _str(json['firstName']),
      lastName: _str(json['lastName']),
      email: _str(json['email']),
      phoneNumber: _str(json['phoneNumber']),
      gender: _str(json['gender']),
      designation: _str(json['designation']),
      dateOfJoining: dateFromWire(json['dateOfJoining']),
      employeeStatus: _str(json['employeeStatus']),
      reportingManagerName: _str(json['reportingManagerName']),
      employeeRoleName: _str(json['employeeRoleName']),
      projectName: _str(json['projectName']),
      shiftTiming: _str(json['shiftTiming']),
      status: _str(json['status']),
    );
  }
}

// ---------------------------------------------------------------------------
// The employee itself
// ---------------------------------------------------------------------------

/// Mirrors EmployeeBean — the Basic Details and Position Details sections.
class EmployeeBean {
  int id;
  String employeeId;
  String firstName;
  String lastName;
  String email;
  String phoneNumber;
  DateTime? dateOfBirth;
  String gender;
  String address;
  String city;
  String state;
  int? postalCode;
  int? department;
  String designation;
  DateTime? dateOfJoining;
  String employeeStatus;
  int? reportingManager;
  int? employeeRoleId;
  int? workLocation;
  String maritalStatus;
  String nationalId;
  int? projectAssigned;
  DateTime? dateOfResignation;
  DateTime? noticePeriodEndDate;
  DateTime? lastWorkingDay;
  String panId;
  int? shiftId;
  String status;
  int? userId;
  int? organizationId;
  String isAddAsUserNeeded;

  /// 'Y' / 'N'. The web's Health Issue switch; the description is only asked
  /// for, and required, while it is 'Y'.
  String healthIssue;
  String healthIssueDescription;

  /// Stored S3 links the web sets. Not edited here, but carried through an
  /// update — leaving them out of the payload would clear them.
  String healthIssueUrl;
  String photoUrl;
  String shift;
  String title;
  String religion;
  String cast;
  String bloodGroup;
  String height;
  String weight;
  String identificationMark;
  String fatherName;
  DateTime? marriageDate;
  String spouseName;
  String nationality;
  String country;

  /// Backend spelling of "place of birth". Not a typo on this side.
  String plcaeOfBirth;
  String physicallyChallenged;
  String personalEmail;
  int? age;
  String emergencyContactName;
  String emergencyContactNumber;
  String policeStationLimits;
  String esiNumber;

  /// Backend spelling of "ESI disbursed".
  String esiDisrubbed;
  String pfUanNo;

  /// Stored paths of the uploaded identity documents. Set by the backend when a
  /// file is uploaded — the form shows them and never writes them itself.
  String adharUrl;
  String panUrl;
  String voterIdUrl;
  String passPortUrl;
  String rationCardUrl;

  int? divisionId;
  int? costCenterId;
  DateTime? confirmationDate;
  int? probationPeriod;
  int? referredBy;
  int? gradeId;
  String company;
  String isPmsEligible;
  int? formStatusOne;
  int? stepperOneStatus;
  int? stepperTwoStatus;
  int? stepperThreeStatus;
  int? attendanceManager;
  String isInProbation;
  String approvalAction;
  String approvalReason;
  String salarySchedule;

  EmployeeBean({
    this.id = 0,
    this.employeeId = '',
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phoneNumber = '',
    this.dateOfBirth,
    this.gender = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.postalCode,
    this.department,
    this.designation = '',
    this.dateOfJoining,
    this.employeeStatus = '',
    this.reportingManager,
    this.employeeRoleId,
    this.workLocation,
    this.maritalStatus = '',
    this.nationalId = '',
    this.projectAssigned,
    this.dateOfResignation,
    this.noticePeriodEndDate,
    this.lastWorkingDay,
    this.panId = '',
    this.shiftId,
    this.status = 'A',
    this.userId,
    this.organizationId,
    this.isAddAsUserNeeded = 'Yes',
    this.healthIssue = 'N',
    this.healthIssueDescription = '',
    this.healthIssueUrl = '',
    this.photoUrl = '',
    this.shift = '',
    this.title = '',
    this.religion = '',
    this.cast = '',
    this.bloodGroup = '',
    this.height = '',
    this.weight = '',
    this.identificationMark = '',
    this.fatherName = '',
    this.marriageDate,
    this.spouseName = '',
    this.nationality = '',
    this.country = '',
    this.plcaeOfBirth = '',
    this.physicallyChallenged = '',
    this.personalEmail = '',
    this.age,
    this.emergencyContactName = '',
    this.emergencyContactNumber = '',
    this.policeStationLimits = '',
    this.esiNumber = '',
    this.esiDisrubbed = '',
    this.pfUanNo = '',
    this.adharUrl = '',
    this.panUrl = '',
    this.voterIdUrl = '',
    this.passPortUrl = '',
    this.rationCardUrl = '',
    this.divisionId,
    this.costCenterId,
    this.confirmationDate,
    this.probationPeriod,
    this.referredBy,
    this.gradeId,
    this.company = '',
    this.isPmsEligible = '',
    this.formStatusOne,
    this.stepperOneStatus,
    this.stepperTwoStatus,
    this.stepperThreeStatus,
    this.attendanceManager,
    this.isInProbation = '',
    this.approvalAction = '',
    this.approvalReason = '',
    this.salarySchedule = '',
  });

  factory EmployeeBean.fromJson(Map<String, dynamic> json) {
    return EmployeeBean(
      id: _int(json['id']) ?? 0,
      employeeId: _str(json['employeeId']),
      firstName: _str(json['firstName']),
      lastName: _str(json['lastName']),
      email: _str(json['email']),
      phoneNumber: _str(json['phoneNumber']),
      dateOfBirth: dateFromWire(json['dateOfBirth']),
      gender: _str(json['gender']),
      address: _str(json['address']),
      city: _str(json['city']),
      state: _str(json['state']),
      postalCode: _int(json['postalCode']),
      department: _int(json['department']),
      designation: _str(json['designation']),
      dateOfJoining: dateFromWire(json['dateOfJoining']),
      employeeStatus: _str(json['employeeStatus']),
      reportingManager: _int(json['reportingManager']),
      employeeRoleId: _int(json['employeeRoleId']),
      workLocation: _int(json['workLocation']),
      maritalStatus: _str(json['maritalStatus']),
      nationalId: _str(json['nationalId']),
      projectAssigned: _int(json['projectAssigned']),
      dateOfResignation: dateFromWire(json['dateOfResignation']),
      noticePeriodEndDate: dateFromWire(json['noticePeriodEndDate']),
      lastWorkingDay: dateFromWire(json['lastWorkingDay']),
      panId: _str(json['panId']),
      shiftId: _int(json['shiftId']),
      status: _str(json['status']).isEmpty ? 'A' : _str(json['status']),
      userId: _int(json['userId']),
      organizationId: _int(json['organizationId']),
      isAddAsUserNeeded: _str(json['isAddAsUserNeeded']),
      healthIssue:
          _str(json['healthIssue']).isEmpty ? 'N' : _str(json['healthIssue']),
      healthIssueDescription: _str(json['healthIssueDescription']),
      healthIssueUrl: _str(json['healthIssueUrl']),
      photoUrl: _str(json['photoUrl']),
      shift: _str(json['shift']),
      title: _str(json['title']),
      religion: _str(json['religion']),
      cast: _str(json['cast']),
      bloodGroup: _str(json['bloodGroup']),
      height: _str(json['height']),
      weight: _str(json['weight']),
      identificationMark: _str(json['identificationMark']),
      fatherName: _str(json['fatherName']),
      marriageDate: dateFromWire(json['marriageDate']),
      spouseName: _str(json['spouseName']),
      nationality: _str(json['nationality']),
      country: _str(json['country']),
      plcaeOfBirth: _str(json['plcaeOfBirth']),
      physicallyChallenged: _str(json['physicallyChallenged']),
      personalEmail: _str(json['personalEmail']),
      age: _int(json['age']),
      emergencyContactName: _str(json['emergencyContactName']),
      emergencyContactNumber: _str(json['emergencyContactNumber']),
      policeStationLimits: _str(json['policeStationLimits']),
      esiNumber: _str(json['esiNumber']),
      esiDisrubbed: _str(json['esiDisrubbed']),
      pfUanNo: _str(json['pfUanNo']),
      adharUrl: _str(json['adharUrl']),
      panUrl: _str(json['panUrl']),
      voterIdUrl: _str(json['voterIdUrl']),
      passPortUrl: _str(json['passPortUrl']),
      rationCardUrl: _str(json['rationCardUrl']),
      divisionId: _int(json['divisionId']),
      costCenterId: _int(json['costCenterId']),
      confirmationDate: dateFromWire(json['confirmationDate']),
      probationPeriod: _int(json['probationPeriod']),
      referredBy: _int(json['referredBy']),
      gradeId: _int(json['gradeId']),
      company: _str(json['company']),
      isPmsEligible: _str(json['isPmsEligible']),
      formStatusOne: _int(json['formStatusOne']),
      stepperOneStatus: _int(json['stepperOneStatus']),
      stepperTwoStatus: _int(json['stepperTwoStatus']),
      stepperThreeStatus: _int(json['stepperThreeStatus']),
      attendanceManager: _int(json['attendanceManager']),
      isInProbation: _str(json['isInProbation']),
      approvalAction: _str(json['approvalAction']),
      approvalReason: _str(json['approvalReason']),
      salarySchedule: _str(json['salarySchedule']),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'id': id};
    _put(json, 'employeeId', employeeId);
    _put(json, 'firstName', firstName);
    _put(json, 'lastName', lastName);
    _put(json, 'email', email);
    _put(json, 'phoneNumber', phoneNumber);
    _put(json, 'dateOfBirth', dateToWire(dateOfBirth));
    _put(json, 'gender', gender);
    _put(json, 'address', address);
    _put(json, 'city', city);
    _put(json, 'state', state);
    _put(json, 'postalCode', postalCode);
    _put(json, 'department', department);
    _put(json, 'designation', designation);
    _put(json, 'dateOfJoining', dateToWire(dateOfJoining));
    _put(json, 'employeeStatus', employeeStatus);
    _put(json, 'reportingManager', reportingManager);
    _put(json, 'employeeRoleId', employeeRoleId);
    _put(json, 'workLocation', workLocation);
    _put(json, 'maritalStatus', maritalStatus);
    _put(json, 'nationalId', nationalId);
    _put(json, 'projectAssigned', projectAssigned);
    _put(json, 'dateOfResignation', dateToWire(dateOfResignation));
    _put(json, 'noticePeriodEndDate', dateToWire(noticePeriodEndDate));
    _put(json, 'lastWorkingDay', dateToWire(lastWorkingDay));
    _put(json, 'panId', panId);
    _put(json, 'shiftId', shiftId);
    _put(json, 'status', status);
    _put(json, 'userId', userId);
    _put(json, 'organizationId', organizationId);
    _put(json, 'isAddAsUserNeeded', isAddAsUserNeeded);
    _put(json, 'healthIssue', healthIssue);
    _put(json, 'healthIssueDescription', healthIssueDescription);
    _put(json, 'healthIssueUrl', healthIssueUrl);
    _put(json, 'photoUrl', photoUrl);
    _put(json, 'shift', shift);
    _put(json, 'title', title);
    _put(json, 'religion', religion);
    _put(json, 'cast', cast);
    _put(json, 'bloodGroup', bloodGroup);
    _put(json, 'height', height);
    _put(json, 'weight', weight);
    _put(json, 'identificationMark', identificationMark);
    _put(json, 'fatherName', fatherName);
    _put(json, 'marriageDate', dateToWire(marriageDate));
    _put(json, 'spouseName', spouseName);
    _put(json, 'nationality', nationality);
    _put(json, 'country', country);
    _put(json, 'plcaeOfBirth', plcaeOfBirth);
    _put(json, 'physicallyChallenged', physicallyChallenged);
    _put(json, 'personalEmail', personalEmail);
    _put(json, 'age', age);
    _put(json, 'emergencyContactName', emergencyContactName);
    _put(json, 'emergencyContactNumber', emergencyContactNumber);
    _put(json, 'policeStationLimits', policeStationLimits);
    _put(json, 'esiNumber', esiNumber);
    _put(json, 'esiDisrubbed', esiDisrubbed);
    _put(json, 'pfUanNo', pfUanNo);
    // The document paths are echoed back unchanged. The backend fills them in
    // when a file is uploaded; dropping them from an update would orphan every
    // document already on the record.
    _put(json, 'adharUrl', adharUrl);
    _put(json, 'panUrl', panUrl);
    _put(json, 'voterIdUrl', voterIdUrl);
    _put(json, 'passPortUrl', passPortUrl);
    _put(json, 'rationCardUrl', rationCardUrl);
    _put(json, 'divisionId', divisionId);
    _put(json, 'costCenterId', costCenterId);
    _put(json, 'confirmationDate', dateToWire(confirmationDate));
    _put(json, 'probationPeriod', probationPeriod);
    _put(json, 'referredBy', referredBy);
    _put(json, 'gradeId', gradeId);
    _put(json, 'company', company);
    _put(json, 'isPmsEligible', isPmsEligible);
    _put(json, 'formStatusOne', formStatusOne);
    _put(json, 'stepperOneStatus', stepperOneStatus);
    _put(json, 'stepperTwoStatus', stepperTwoStatus);
    _put(json, 'stepperThreeStatus', stepperThreeStatus);
    _put(json, 'attendanceManager', attendanceManager);
    _put(json, 'isInProbation', isInProbation);
    _put(json, 'approvalAction', approvalAction);
    _put(json, 'approvalReason', approvalReason);
    _put(json, 'salarySchedule', salarySchedule);
    return json;
  }
}

// ---------------------------------------------------------------------------
// The repeatable sections
// ---------------------------------------------------------------------------

/// Mirrors EmployeeAddressBean.
///
/// Exactly two are always sent, in this order: permanent at index 0 and
/// temporary at index 1. The web writes them positionally and so does the
/// backend, so a list with one entry, or with them the other way round, files
/// the address under the wrong type.
class EmployeeAddress {
  int addressId;
  int employeeId;
  String type;

  /// Integer on the backend even though it is typed as free text — a door
  /// number like "12-B" cannot be sent, and is dropped rather than rejected.
  int? doorNo;
  String houseOwnerName;
  String streetOrRoad;
  String post;
  String city;
  String pincode;
  String state;
  String policeStationLimits;
  String isPointOfContact;
  int stepperStatus;

  EmployeeAddress({
    this.addressId = 0,
    this.employeeId = 0,
    required this.type,
    this.doorNo,
    this.houseOwnerName = '',
    this.streetOrRoad = '',
    this.post = '',
    this.city = '',
    this.pincode = '',
    this.state = '',
    this.policeStationLimits = '',
    this.isPointOfContact = 'No',
    this.stepperStatus = 0,
  });

  factory EmployeeAddress.fromJson(Map<String, dynamic> json) {
    return EmployeeAddress(
      addressId: _int(json['addressId']) ?? 0,
      employeeId: _int(json['employeeId']) ?? 0,
      type: _str(json['type']).isEmpty ? 'permanent' : _str(json['type']),
      doorNo: _int(json['doorNo']),
      houseOwnerName: _str(json['houseOwnerName']),
      streetOrRoad: _str(json['streetOrRoad']),
      post: _str(json['post']),
      city: _str(json['city']),
      pincode: _str(json['pincode']),
      state: _str(json['state']),
      policeStationLimits: _str(json['policeStationLimits']),
      isPointOfContact: _str(json['isPointOfContact']).isEmpty
          ? 'No'
          : _str(json['isPointOfContact']),
      stepperStatus: _int(json['stepperStatus']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'addressId': addressId,
      'employeeId': employeeId,
      'type': type,
      'isPointOfContact': isPointOfContact,
      'stepperStatus': stepperStatus,
    };
    _put(json, 'doorNo', doorNo);
    _put(json, 'houseOwnerName', houseOwnerName);
    _put(json, 'streetOrRoad', streetOrRoad);
    _put(json, 'post', post);
    _put(json, 'city', city);
    _put(json, 'pincode', pincode);
    _put(json, 'state', state);
    _put(json, 'policeStationLimits', policeStationLimits);
    return json;
  }
}

/// Mirrors EmployeeEducationBean.
class EmployeeEducation {
  /// Stored S3 link to the row's attachment (set by the web). Carried through
  /// an update so a mobile edit does not clear it.
  String attachmentUrl = '';

  int id;
  int? qualification;
  String institute;
  int? qualificationArea;
  String grade;
  String remarks;
  DateTime? startDate;
  DateTime? endDate;
  int employeeId;
  int stepperStatus;

  EmployeeEducation({
    this.id = 0,
    this.qualification,
    this.institute = '',
    this.qualificationArea,
    this.grade = '',
    this.remarks = '',
    this.startDate,
    this.endDate,
    this.employeeId = 0,
    this.stepperStatus = 0,
  });

  bool get isEmpty =>
      qualification == null &&
      qualificationArea == null &&
      institute.trim().isEmpty &&
      grade.trim().isEmpty &&
      remarks.trim().isEmpty;

  factory EmployeeEducation.fromJson(Map<String, dynamic> json) {
    return EmployeeEducation(
      id: _int(json['id']) ?? 0,
      qualification: _int(json['qualification']),
      institute: _str(json['institute']),
      qualificationArea: _int(json['qualificationArea']),
      grade: _str(json['grade']),
      remarks: _str(json['remarks']),
      startDate: dateFromWire(json['startDate']),
      endDate: dateFromWire(json['endDate']),
      employeeId: _int(json['employeeId']) ?? 0,
      stepperStatus: _int(json['stepperStatus']) ?? 0,
    )..attachmentUrl = _str(json['attachmentUrl']);
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'employeeId': employeeId,
      'stepperStatus': stepperStatus,
    };
    _put(json, 'qualification', qualification);
    _put(json, 'institute', institute);
    _put(json, 'qualificationArea', qualificationArea);
    _put(json, 'grade', grade);
    _put(json, 'remarks', remarks);
    _put(json, 'startDate', dateToWire(startDate));
    _put(json, 'endDate', dateToWire(endDate));
    _put(json, 'attachmentUrl', attachmentUrl);
    return json;
  }
}

/// Mirrors EmployeeFamilyBean.
class EmployeeFamily {
  /// 'Yes' / 'No' — which member the web marked as the emergency contact.
  /// Carried through an update so a mobile edit does not clear it.
  String isEmergencyContact = '';

  int id;
  String name;
  String relationship;
  String contactNo;
  DateTime? dateOfBirth;
  int? age;
  String remarks;
  String address;
  String email;
  String country;
  String pincode;
  String city;
  int employeeId;
  int stepperStatus;
  String familyMemberId;

  EmployeeFamily({
    this.id = 0,
    this.name = '',
    this.relationship = '',
    this.contactNo = '',
    this.dateOfBirth,
    this.age,
    this.remarks = '',
    this.address = '',
    this.email = '',
    this.country = '',
    this.pincode = '',
    this.city = '',
    this.employeeId = 0,
    this.stepperStatus = 0,
    this.familyMemberId = '',
  });

  bool get isEmpty =>
      name.trim().isEmpty &&
      relationship.trim().isEmpty &&
      contactNo.trim().isEmpty;

  factory EmployeeFamily.fromJson(Map<String, dynamic> json) {
    return EmployeeFamily(
      id: _int(json['id']) ?? 0,
      name: _str(json['name']),
      relationship: _str(json['relationship']),
      contactNo: _str(json['contactNo']),
      dateOfBirth: dateFromWire(json['dateOfBirth']),
      age: _int(json['age']),
      remarks: _str(json['remarks']),
      address: _str(json['address']),
      email: _str(json['email']),
      country: _str(json['country']),
      pincode: _str(json['pincode']),
      city: _str(json['city']),
      employeeId: _int(json['employeeId']) ?? 0,
      stepperStatus: _int(json['stepperStatus']) ?? 0,
      familyMemberId: _str(json['familyMemberId']),
    )..isEmergencyContact = _str(json['isEmergencyContact']);
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'employeeId': employeeId,
      'stepperStatus': stepperStatus,
    };
    _put(json, 'name', name);
    _put(json, 'relationship', relationship);
    _put(json, 'contactNo', contactNo);
    _put(json, 'dateOfBirth', dateToWire(dateOfBirth));
    _put(json, 'age', age);
    _put(json, 'remarks', remarks);
    _put(json, 'address', address);
    _put(json, 'email', email);
    _put(json, 'country', country);
    _put(json, 'pincode', pincode);
    _put(json, 'city', city);
    _put(json, 'familyMemberId', familyMemberId);
    _put(json, 'isEmergencyContact', isEmergencyContact);
    return json;
  }
}

/// Mirrors EmployeeExperienceBean. `jobdescription` is lower-case on the wire.
class EmployeeExperience {
  /// Stored S3 link to the row's attachment (set by the web). Carried through
  /// an update so a mobile edit does not clear it.
  String attachmentUrl = '';

  int id;
  String companyName;
  String jobTitle;
  String designation;
  DateTime? startDate;
  DateTime? endDate;
  String jobdescription;
  int employeeId;
  int stepperStatus;

  EmployeeExperience({
    this.id = 0,
    this.companyName = '',
    this.jobTitle = '',
    this.designation = '',
    this.startDate,
    this.endDate,
    this.jobdescription = '',
    this.employeeId = 0,
    this.stepperStatus = 0,
  });

  bool get isEmpty =>
      companyName.trim().isEmpty &&
      jobTitle.trim().isEmpty &&
      designation.trim().isEmpty;

  factory EmployeeExperience.fromJson(Map<String, dynamic> json) {
    return EmployeeExperience(
      id: _int(json['id']) ?? 0,
      companyName: _str(json['companyName']),
      jobTitle: _str(json['jobTitle']),
      designation: _str(json['designation']),
      startDate: dateFromWire(json['startDate']),
      endDate: dateFromWire(json['endDate']),
      jobdescription: _str(json['jobdescription']),
      employeeId: _int(json['employeeId']) ?? 0,
      stepperStatus: _int(json['stepperStatus']) ?? 0,
    )..attachmentUrl = _str(json['attachmentUrl']);
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'employeeId': employeeId,
      'stepperStatus': stepperStatus,
    };
    _put(json, 'companyName', companyName);
    _put(json, 'jobTitle', jobTitle);
    _put(json, 'designation', designation);
    _put(json, 'startDate', dateToWire(startDate));
    _put(json, 'endDate', dateToWire(endDate));
    _put(json, 'jobdescription', jobdescription);
    _put(json, 'attachmentUrl', attachmentUrl);
    return json;
  }
}

/// Mirrors EmployeeBankDetailsBean.
///
/// The three include flags are 'Yes'/'No' strings on the wire, not booleans —
/// the column is a varchar and a real boolean is rejected.
class EmployeeBankDetails {
  /// Stored S3 link to the bank passbook / cancelled cheque (set by the web).
  /// Carried through an update so a mobile edit does not clear it.
  String attachmentUrl = '';

  int id;
  int employeeId;
  String bankName;
  String bankAccountNumber;
  String bankIfscCode;
  String accountType;
  DateTime? accountOpeningDate;
  String aadhaarNumber;
  String panNumber;
  String esicInclude;
  String esicNumber;
  String pfInclude;
  String pfNumber;
  String uanNumber;
  String lwfInclude;
  String mobileNumber;
  String status;
  int stepperStatus;

  EmployeeBankDetails({
    this.id = 0,
    this.employeeId = 0,
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankIfscCode = '',
    this.accountType = '',
    this.accountOpeningDate,
    this.aadhaarNumber = '',
    this.panNumber = '',
    this.esicInclude = '',
    this.esicNumber = '',
    this.pfInclude = '',
    this.pfNumber = '',
    this.uanNumber = '',
    this.lwfInclude = '',
    this.mobileNumber = '',
    this.status = 'A',
    this.stepperStatus = 0,
  });

  factory EmployeeBankDetails.fromJson(Map<String, dynamic> json) {
    return EmployeeBankDetails(
      id: _int(json['id']) ?? 0,
      employeeId: _int(json['employeeId']) ?? 0,
      bankName: _str(json['bankName']),
      bankAccountNumber: _str(json['bankAccountNumber']),
      bankIfscCode: _str(json['bankIfscCode']),
      accountType: _str(json['accountType']),
      accountOpeningDate: dateFromWire(json['accountOpeningDate']),
      aadhaarNumber: _str(json['aadhaarNumber']),
      panNumber: _str(json['panNumber']),
      esicInclude: _str(json['esicInclude']),
      esicNumber: _str(json['esicNumber']),
      pfInclude: _str(json['pfInclude']),
      pfNumber: _str(json['pfNumber']),
      uanNumber: _str(json['uanNumber']),
      lwfInclude: _str(json['lwfInclude']),
      mobileNumber: _str(json['mobileNumber']),
      status: _str(json['status']).isEmpty ? 'A' : _str(json['status']),
      stepperStatus: _int(json['stepperStatus']) ?? 0,
    )..attachmentUrl = _str(json['attachmentUrl']);
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'employeeId': employeeId,
      'status': status,
      'stepperStatus': stepperStatus,
    };
    _put(json, 'bankName', bankName);
    _put(json, 'bankAccountNumber', bankAccountNumber);
    _put(json, 'bankIfscCode', bankIfscCode);
    _put(json, 'accountType', accountType);
    _put(json, 'accountOpeningDate', dateToWire(accountOpeningDate));
    _put(json, 'aadhaarNumber', aadhaarNumber);
    _put(json, 'panNumber', panNumber);
    _put(json, 'esicInclude', esicInclude);
    _put(json, 'esicNumber', esicNumber);
    _put(json, 'pfInclude', pfInclude);
    _put(json, 'pfNumber', pfNumber);
    _put(json, 'uanNumber', uanNumber);
    _put(json, 'lwfInclude', lwfInclude);
    _put(json, 'mobileNumber', mobileNumber);
    _put(json, 'attachmentUrl', attachmentUrl);
    return json;
  }
}

// ---------------------------------------------------------------------------
// The whole record
// ---------------------------------------------------------------------------

/// Mirrors EmployeeSaveDto — the payload both writes send.
///
/// An update REPLACES the stored record with this, section by section. That is
/// why the edit form loads the full record first and edits it in place: build
/// one of these from a blank form and every section the form did not fill is
/// wiped for that employee.
class EmployeeSaveDto {
  EmployeeBean employeeBean;
  List<EmployeeFamily> employeeFamilyBeanList;
  List<EmployeeAddress> addressBeanList;
  List<EmployeeEducation> employeeEducationBeanList;
  List<EmployeeExperience> employeeExperienceBeanList;
  EmployeeBankDetails employeeBankDetails;
  String? approvalStatus;

  EmployeeSaveDto({
    required this.employeeBean,
    required this.employeeFamilyBeanList,
    required this.addressBeanList,
    required this.employeeEducationBeanList,
    required this.employeeExperienceBeanList,
    required this.employeeBankDetails,
    this.approvalStatus,
  });

  /// A new record: one blank row in each repeatable section, and the two
  /// addresses in the order the backend reads them.
  factory EmployeeSaveDto.blank({required int organizationId}) {
    return EmployeeSaveDto(
      employeeBean: EmployeeBean(organizationId: organizationId),
      employeeFamilyBeanList: [EmployeeFamily()],
      addressBeanList: [
        EmployeeAddress(type: 'permanent', isPointOfContact: 'Yes'),
        EmployeeAddress(type: 'temporary'),
      ],
      employeeEducationBeanList: [EmployeeEducation()],
      employeeExperienceBeanList: [EmployeeExperience()],
      employeeBankDetails: EmployeeBankDetails(),
    );
  }

  factory EmployeeSaveDto.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = json[key];
      if (raw is! List) return <T>[];
      return raw.whereType<Map<String, dynamic>>().map(parse).toList();
    }

    final addresses = list('addressBeanList', EmployeeAddress.fromJson);
    // The form edits permanent and temporary by position, so both have to be
    // present even when the stored record only has one of them.
    EmployeeAddress addressOfType(String type) {
      final match = addresses.where((a) => a.type.toLowerCase() == type);
      return match.isEmpty ? EmployeeAddress(type: type) : match.first;
    }

    final bank = json['employeeBankDetails'];

    return EmployeeSaveDto(
      employeeBean: EmployeeBean.fromJson(
          json['employeeBean'] is Map<String, dynamic>
              ? json['employeeBean']
              : <String, dynamic>{}),
      employeeFamilyBeanList:
          list('employeeFamilyBeanList', EmployeeFamily.fromJson),
      addressBeanList: [
        addressOfType('permanent'),
        addressOfType('temporary'),
      ],
      employeeEducationBeanList:
          list('employeeEducationBeanList', EmployeeEducation.fromJson),
      employeeExperienceBeanList:
          list('employeeExperienceBeanList', EmployeeExperience.fromJson),
      employeeBankDetails: bank is Map<String, dynamic>
          ? EmployeeBankDetails.fromJson(bank)
          : EmployeeBankDetails(),
      approvalStatus: _optional(json['approvalStatus']),
    );
  }

  /// Blank repeatable rows are dropped rather than sent.
  ///
  /// Each section starts with one empty row so the form has something to show.
  /// Sending those through would store a family member with no name and an
  /// education with no qualification against every employee added from a phone.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'employeeBean': employeeBean.toJson(),
      'employeeFamilyBeanList': employeeFamilyBeanList
          .where((e) => !e.isEmpty)
          .map((e) => e.toJson())
          .toList(),
      'addressBeanList': addressBeanList.map((e) => e.toJson()).toList(),
      'employeeEducationBeanList': employeeEducationBeanList
          .where((e) => !e.isEmpty)
          .map((e) => e.toJson())
          .toList(),
      'employeeExperienceBeanList': employeeExperienceBeanList
          .where((e) => !e.isEmpty)
          .map((e) => e.toJson())
          .toList(),
      'employeeBankDetails': employeeBankDetails.toJson(),
    };
    _put(json, 'approvalStatus', approvalStatus);
    return json;
  }
}

// ---------------------------------------------------------------------------
// Dropdown options
// ---------------------------------------------------------------------------

/// One `common_reference_details` row — the shape every reference dropdown on
/// this form is built from (department, designation, shift, grade, division,
/// cost centre, qualification, qualification area, employee status).
class RefOption {
  final int id;
  final String key;
  final String value;

  RefOption({required this.id, required this.key, required this.value});

  factory RefOption.fromJson(Map<String, dynamic> json) {
    return RefOption(
      id: _int(json['id']) ?? 0,
      key: _str(json['commonRefKey']),
      value: _str(json['commonRefValue']),
    );
  }
}

/// A person who can be picked as a reporting or attendance manager.
class ManagerOption {
  final int userId;
  final String userName;

  ManagerOption({required this.userId, required this.userName});

  factory ManagerOption.fromJson(Map<String, dynamic> json) {
    return ManagerOption(
      userId: _int(json['userId']) ?? 0,
      userName: _str(json['userName']),
    );
  }
}

class RoleOption {
  final int roleId;
  final String roleName;

  RoleOption({required this.roleId, required this.roleName});

  factory RoleOption.fromJson(Map<String, dynamic> json) {
    return RoleOption(
      roleId: _int(json['roleId']) ?? 0,
      roleName: _str(json['roleName']),
    );
  }
}

class ProjectOption {
  final int projectId;
  final String projectName;

  ProjectOption({required this.projectId, required this.projectName});

  factory ProjectOption.fromJson(Map<String, dynamic> json) {
    return ProjectOption(
      projectId: _int(json['projectId']) ?? 0,
      projectName: _str(json['projectName']),
    );
  }
}

/// A work location — a qr_generator row, the same list the attendance screens
/// read.
/// An employee, as the Attendance Manager picker lists them — hrm-service's
/// `employee/getAllEmpoyees`. The value stored is the employee row `id`, not a
/// user id: that is what the web writes to `attendanceManager`.
class EmployeeOption {
  final int id;
  final String name;

  EmployeeOption({required this.id, required this.name});

  factory EmployeeOption.fromJson(Map<String, dynamic> json) {
    return EmployeeOption(
      id: _int(json['id']) ?? 0,
      name: '${_str(json['firstName'])} ${_str(json['lastName'])}'.trim(),
    );
  }
}

class WorkLocationOption {
  final int id;
  final String location;

  WorkLocationOption({required this.id, required this.location});

  factory WorkLocationOption.fromJson(Map<String, dynamic> json) {
    return WorkLocationOption(
      id: _int(json['id']) ?? 0,
      location: _str(json['location']),
    );
  }
}
