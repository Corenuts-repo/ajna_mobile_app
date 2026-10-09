import 'dart:convert';
import 'dart:io';

import 'package:ajna/screens/util.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart'; // Import the path package
// Import for MediaType

class ApiService {
  static int? userId;
  static String? accessToken;
  static String? token;

  // static const String baseUrl1 = 'http://localhost:1093/';
  // static const String baseUrl2 = 'http://localhost:1093/';
  // static const String baseUrl3 = 'http://localhost:1093/';
  // static const String baseUrl4 = 'http://localhost:1093/';

  // static const String baseUrl1 = 'http://15.207.212.144/';
  // static const String baseUrl2 = 'http://15.207.212.144/';
  // static const String baseUrl3 = 'http://15.207.212.144/';
  // static const String baseUrl4 = 'http://15.207.212.144/';
  // static const String notificationUrl = 'http://15.207.212.144';

  // static const String baseUrl1 = 'http://192.168.0.15:1093/';
  // static const String baseUrl2 = 'http://192.168.0.15:1093/';
  // static const String baseUrl3 = 'http://192.168.0.15:1093/';
  // static const String baseUrl4 = 'http://192.168.0.15:1093/';
  // static const String notificationUrl = 'http://192.168.0.15:1093';

  static const String baseUrl1 = 'https://sbrgroup.salesncrm.com/';
  static const String baseUrl2 = 'https://sbrgroup.salesncrm.com/';
  static const String baseUrl3 = 'https://sbrgroup.salesncrm.com/';
  static const String baseUrl4 = 'https://sbrgroup.salesncrm.com/';
  static const String notificationUrl = 'https://sbrgroup.salesncrm.com';

  // static const String baseUrl1 = 'https://ad776369d415.ngrok-free.app/';
  // static const String baseUrl2 = 'https://ad776369d415.ngrok-free.app/';
  // static const String baseUrl3 = 'https://ad776369d415.ngrok-free.app/';
  // static const String baseUrl4 = 'https://ad776369d415.ngrok-free.app/';
  // static const String notificationUrl =
  //     'https://ad776369d415.ngrok-free.app';

  static final List<String> excludedEndpoints = [
    'api/user/user/signUp',
    'api/user/user/login',
    'api/user/user/mob/login',
    'api/user/user/refreshToken',
    'api/user/user/updatepassword',
    'api/user/user/verify',
    'api/user/user/generateotp',
    'api/user/user/reset',
  ];

  // Initialize the access token
  static Future<void> initialize() async {
    userId = await Util.getUserId();
    try {
      accessToken = await Util
          .getAccessToken(); // Ensure Util.getAccessToken() is defined
      token = await Util.getToken();
      // Log presence only — never the token value (it is a session credential
      // and this runs before every request).
      debugPrint('Session initialized (token '
          '${accessToken == null || accessToken!.isEmpty ? "missing" : "present"}).');
    } catch (error) {
      print('Error during initialization: $error');
      // Handle error, e.g., show a snackbar or retry
      rethrow; // Re-throw the error for further handling
    }
  }

  // Check if the endpoint is excluded from authorization
  static bool isExcludedEndpoint(String endpoint) {
    return excludedEndpoints.any((excluded) => endpoint.contains(excluded));
  }

  // POST request method
  static Future<http.Response> postRequest(
      String baseUrl, String endpoint, Map<String, dynamic> data) async {
    await initialize();

    final Uri uri = Uri.parse('$baseUrl$endpoint');
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      if (!isExcludedEndpoint(endpoint) && accessToken != null)
        'Authorization': 'Bearer $accessToken',
      if (userId != null) 'proxyId': userId.toString(),
      if (userId != null) 'userId': userId.toString(),
    };

    http.Response response = await http.post(
      uri,
      body: json.encode(data),
      headers: headers,
    );

    if (response.statusCode == 401) {
      // Attempt to refresh the token
      final refreshSuccess = await _refreshToken();
      if (refreshSuccess) {
        // Retry the original request with the new token
        headers['Authorization'] = 'Bearer $accessToken';
        response = await http.post(
          uri,
          body: json.encode(data),
          headers: headers,
        );
      }
    }

    _handleResponse(response); // Optional: Handle response status
    return response;
  }

  // Token refresh method
  static Future<bool> _refreshToken() async {
    final Uri refreshUri =
        Uri.parse('https://sbrgroup.salesncrm.com/api/user/user/refreshToken');

    // Define headers
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'No-Auth': 'True', // Custom header indicating no authentication required
    };

    // Ensure tokens are not null
    if (accessToken == null || token == null) {
      print('Access token or refresh token is null.');
      return false;
    }

    // Define request body
    final Map<String, dynamic> body = {
      'accessToken': accessToken,
      'token': token,
    };

    try {
      final response = await http.post(
        refreshUri,
        headers: headers,
        body: json.encode(body),
      );

      // Check if the response is successful
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Update tokens
        accessToken = responseData['accessToken'];
        token = responseData['token'];

        // Save the new tokens using SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('accessToken', accessToken!);
        await prefs.setString('token', token!);

        return true;
      } else {
        // Handle token refresh failure
        print('Token refresh failed with status: ${response.statusCode}');
        return false;
      }
    } catch (error) {
      // Handle any errors during the request
      print('Error during token refresh: $error');
      return false;
    }
  }

  // GET request method
  static Future<http.Response> getRequest(
      String baseUrl, String endpoint) async {
    await initialize();

    final Uri uri = Uri.parse('$baseUrl$endpoint');
    final Map<String, String> headers = {
      if (!isExcludedEndpoint(endpoint) && accessToken != null)
        'Authorization': 'Bearer $accessToken',
      if (userId != null) 'proxyId': userId.toString(),
      if (userId != null) 'userId': userId.toString(),
    };

    http.Response response = await http.get(
      uri,
      headers: headers,
    );

    if (response.statusCode == 401) {
      // Attempt to refresh the token
      final refreshSuccess = await _refreshToken();
      if (refreshSuccess) {
        // Retry the original request with the new token
        headers['Authorization'] = 'Bearer $accessToken';
        response = await http.get(
          uri,
          headers: headers,
        );
      }
    }

    _handleResponse(response); // Optional: Handle response status
    return response;
  }

  static Future<http.Response> putRequest(
    String baseUrl,
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    // Initialize if needed
    // await initialize();

    final Uri uri = Uri.parse('$baseUrl$endpoint');
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Authorization':
          'Bearer $accessToken', // Uncomment if authorization is needed
      if (userId != null) 'proxyId': userId.toString(),
      if (userId != null) 'userId': userId.toString(),
    };

    http.Response response = await http.put(
      uri,
      body: json.encode(data),
      headers: headers,
    );

    if (response.statusCode == 401) {
      // Attempt to refresh the token
      final refreshSuccess = await _refreshToken();
      if (refreshSuccess) {
        // Retry the original request with the new token
        headers['Authorization'] = 'Bearer $accessToken';
        response = await http.put(
          uri,
          body: json.encode(data),
          headers: headers,
        );
      }
    }

    _handleResponse(response); // Optional: Handle response status
    return response;
  }

  /// DELETE with the same auth and 401-retry behaviour as the other verbs.
  ///
  /// The delete endpoints in use take their arguments in the path and query
  /// string, so this sends no body — `http.delete` with a body is refused by
  /// some proxies and none of the callers need one.
  static Future<http.Response> deleteRequest(
      String baseUrl, String endpoint) async {
    await initialize();

    final Uri uri = Uri.parse('$baseUrl$endpoint');
    final Map<String, String> headers = {
      if (!isExcludedEndpoint(endpoint) && accessToken != null)
        'Authorization': 'Bearer $accessToken',
      if (userId != null) 'proxyId': userId.toString(),
      if (userId != null) 'userId': userId.toString(),
    };

    http.Response response = await http.delete(uri, headers: headers);

    if (response.statusCode == 401) {
      final refreshSuccess = await _refreshToken();
      if (refreshSuccess) {
        headers['Authorization'] = 'Bearer $accessToken';
        response = await http.delete(uri, headers: headers);
      }
    }

    _handleResponse(response);
    return response;
  }

  // Optional: Handle HTTP response status
  static void _handleResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      print('Failed request: ${response.statusCode} ${response.reasonPhrase}');
      // Optionally: throw an exception or handle errors
    }
  }

  static Future<http.Response> login(
      String identifier, String password, String androidId) async {
    return await postRequest(baseUrl1, 'api/user/user/mob/login', {
      'identifier': identifier,
      'password': password,
      'androidId': androidId,
      'organizationId': 2,
    });
  }

  // static Future<http.Response> login(String identifier, String password) async {
  //   return await postRequest(baseUrl1, 'api/user/user/mob/login', {
  //     'identifier': identifier,
  //     'password': password,
  //     'organizationId': 2,
  //   });
  // }

  static Future<http.Response> checkForUpdate() async {
    return await getRequest(
        baseUrl1, 'api/user/commonreferencedetails/mob?refKey=ajna_version');
  }

  static Future<http.Response> fetchAdditionalData(int roleId) async {
    return await getRequest(
        baseUrl1, 'api/user/roleMenuItem/moblie/icon/$roleId');
  }

  static Future<http.Response> fetchQRScanDetails(int userId) async {
    return await getRequest(
        baseUrl1, 'api/user/user/qrscan/details?userId=$userId');
  }

  static Future<http.Response> sendError(String errorDetails) async {
    return await getRequest(
        baseUrl1, 'api/user/user/sendemailtotechteam?errorMsg=$errorDetails');
  }

  static Future<http.Response> fetchOrgDetails(int organizationId) async {
    return await getRequest(baseUrl1, 'api/user/organization/$organizationId');
  }

  static Future<http.Response> fetchOrgUsers(int intOraganizationId) async {
    return await getRequest(baseUrl1,
        'api/user/user/fetchall?userName=&organizationId=$intOraganizationId');
  }

  static Future<http.Response> fetchOrgManagers(int intOraganizationId) async {
    return await getRequest(baseUrl1,
        'api/user/user/fetchall?userName=&organizationId=$intOraganizationId');
  }

  static Future<http.Response> fetchOrgRoles(int intOraganizationId) async {
    return await getRequest(baseUrl1,
        'api/user/role/fetchall?roleName=&organizationId=$intOraganizationId');
  }

  static Future<http.Response> signUp(
      String userName,
      String email,
      String password,
      String phoneNumber,
      String roleId,
      String managerId,
      int organizationId) async {
    return await postRequest(baseUrl1, 'api/user/user/signUp', {
      'userName': userName,
      'email': email,
      'password': password,
      'phoneNumber': phoneNumber,
      'roleId': roleId,
      'managerId': managerId,
      'organizationId': organizationId,
    });
  }

  static Future<http.Response> generateOtp(String email) async {
    return await getRequest(baseUrl1, 'api/user/user/generateotp/$email');
  }

  static Future<http.Response> verifyOtp(String email, String otp) async {
    return await getRequest(baseUrl1, 'api/user/user/verify/$email/$otp');
  }

  static Future<http.Response> updatePassword(
      String email, String password) async {
    return await getRequest(
        baseUrl1, 'api/user/user/updatepassword/$email/$password');
  }

  static Future<http.Response> fetchFilterDays() async {
    return await getRequest(
        baseUrl1, 'api/user/commonreferencedetails/types/Filter_Days');
  }

  static Future<http.Response> fetchDashboardData(
      String range, int userId, int roleId) async {
    return await getRequest(baseUrl1,
        'api/lead/lead/dashboard/leads?userId=$userId&roleId=$roleId&range=$range');
  }

  static Future<http.Response> fetchFollowups(
      String range, int userId, int roleId) async {
    return await getRequest(baseUrl1,
        'api/lead/followup/dashboard/followups?userId=$userId&roleId=$roleId&range=$range');
  }

  static Future<http.Response> getCommonReferenceDetails(
      String typeName) async {
    return await getRequest(
        baseUrl1, 'api/user/commonreferencedetails/types/$typeName');
  }

  static Future<http.Response> fetchResetUsers(String organizationId) async {
    return await getRequest(
        baseUrl1, 'api/user/user/fetchall?organizationId=$organizationId');
  }

  static Future<http.Response> resetAndroidId(int userId) async {
    return await getRequest(
        baseUrl1, 'api/user/user/mob/resetandroidid?userId=$userId');
  }

  static Future<http.Response> fetchConsumptionTypeList() async {
    return await getRequest(
        baseUrl1, 'api/user/commonreferencedetails/types/Consumption_Type');
  }

  static Future<http.Response> fetchConsumptionYearList() async {
    return await getRequest(
        baseUrl1, 'api/user/commonreferencedetails/types/Consumption_Year');
  }

  //Start baseUrl2 - http://localhost:9006/

  static Future<http.Response> fetchReportProjectWise(
      int organizationId, String selectedDateRange) async {
    return await getRequest(baseUrl2,
        'api/facility-management/qrreport/getallreportprojectwise?organizationId=$organizationId&range=$selectedDateRange');
  }

  static Future<http.Response> fetchReportLocationWise(
      int organizationId, int projectId, String selectedDateRange) async {
    return await getRequest(baseUrl2,
        'api/facility-management/qrreport/getallreportlocationwise?organizationId=$organizationId&projectId=$projectId&range=$selectedDateRange');
  }

  static Future<http.Response> fetchReportUserWise(int organizationId,
      int projectId, String selectedDateRange, int qrgeneratorId) async {
    return await getRequest(baseUrl2,
        'api/facility-management/qrreport/getallreportuserwise?organizationId=$organizationId&projectId=$projectId&range=$selectedDateRange&qrgeneratorId=$qrgeneratorId');
  }

  static Future<http.Response> fetchReportScheduleWise(
      int organizationId,
      int projectId,
      String selectedDateRange,
      int qrgeneratorId,
      int userId) async {
    return await getRequest(baseUrl2,
        'api/facility-management/qrreport/getallwithfilter?organizationId=$organizationId&projectId=$projectId&range=$selectedDateRange&qrgeneratorId=$qrgeneratorId&userId=$userId');
  }

  static Future<http.Response> fetchQrReGenerate(
      int projectId, int selectedOrgId) async {
    return await getRequest(baseUrl2,
        'api/facility-management/facility/getAll/withoutpage?orgId=$selectedOrgId&projectId=$projectId');
  }

  /// Every QR of an organization, optionally narrowed to one project or one QR
  /// type. Pass qrTypeId 0 for all types; omitting it entirely makes the server
  /// fall back to Security-only, which is the older behaviour other screens use.
  static Future<http.Response> fetchQrCodes({
    required int orgId,
    String projectId = '',
    int qrTypeId = 0,
    String location = '',
  }) async {
    return await getRequest(
        baseUrl2,
        'api/facility-management/facility/getAll/withoutpage?orgId=$orgId'
        '&projectId=$projectId&qrTypeId=$qrTypeId'
        '&location=${Uri.encodeQueryComponent(location)}');
  }

  /// Activates or deactivates a QR. Status 'A' is active, 'I' inactive.
  /// Preferred over delete, which would orphan the scan history.
  static Future<http.Response> updateQrStatus(int id, String status) async {
    return await putRequest(baseUrl2,
        'api/facility-management/facility/status/$id?status=$status', {});
  }

  static Future<http.Response> postQrData(Map<String, dynamic> qrData) async {
    return await postRequest(
        baseUrl2, 'api/facility-management/facility/save', qrData);
  }

  // // Method to submit QR transaction data
  // static Future<http.Response> submitQrTransactionData(
  //     Map<String, dynamic> scannedQrData, File selfie) async {
  //   final url =
  //       Uri.parse('${baseUrl2}api/facility-management/qrtransaction/save');

  //   final request = http.MultipartRequest('POST', url);

  //   // Add the scanned data as a field in the request
  //   request.fields['scannedData'] = jsonEncode(scannedQrData);
  //   // Add the _selfie file to the request
  //   request.files.add(
  //     http.MultipartFile(
  //       'file',
  //       selfie.readAsBytes().asStream(),
  //       selfie.lengthSync(),
  //       filename: selfie.path.split('/').last,
  //       contentType: MediaType('image', 'jpeg'),
  //     ),
  //   );
  //   // Add the Authorization header with the accessToken
  //   request.headers['Authorization'] = 'Bearer $accessToken';

  //   try {
  //     final streamedResponse = await request.send();
  //     final responseBody = await streamedResponse.stream.bytesToString();
  //     return http.Response(responseBody, streamedResponse.statusCode);
  //   } catch (e) {
  //     throw Exception('Error during upload: $e');
  //   }
  // }
  static Future<http.Response> submitQrTransactionData(
      String qrTransactionData, File imageFile) async {
    final url =
        Uri.parse('${baseUrl2}api/facility-management/qrtransaction/save');

    var request = http.MultipartRequest('POST', url);

    request.fields['qrTransactionDataBean'] = qrTransactionData;

    if (imageFile != null && await imageFile.exists()) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'imageFile',
          imageFile.path,
          contentType: MediaType(
            'image',
            path.extension(imageFile.path).replaceFirst('.', ''),
          ),
        ),
      );
    }

    request.headers['Authorization'] = 'Bearer $accessToken';

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return response;
    } catch (e) {
      throw Exception('Error during upload: $e');
    }
  }

  static Future<http.Response> fetchScanSchedules(int userId) async {
    return await getRequest(baseUrl2,
        'api/facility-management/securitypatrol/getsecuritypartolbyuserwise?userId=$userId');
  }

  static Future<http.Response> fetchQrLocations(String projectId) async {
    return await getRequest(baseUrl2,
        'api/facility-management/securitypatrol/getallsecuritypatrolformob?projectId=$projectId&securityPatrolName=');
  }

  static Future<http.Response> fetchloadCustomers() async {
    return await getRequest(
        baseUrl2, 'api/facility-management/customer/fetchall');
  }

  static Future<http.Response> saveConsumptionData(
      Map<String, dynamic> data) async {
    return await postRequest(
        baseUrl2, 'api/facility-management/consumption/save', data);
  }

  //Start baseUrl3 - http://localhost:9002/

  static Future<http.Response> fetchOrgProjects(int organizationId) async {
    return await getRequest(
        baseUrl3, 'api/project/project/org?organizationId=$organizationId');
  }

  static Future<http.Response> fetchQrProjects(int selectedOrgId) async {
    return await getRequest(
        baseUrl3, 'api/project/project/org?organizationId=$selectedOrgId');
  }

  static Future<http.Response> fetchProjectsUserManage(
      int intOrganizationId) async {
    return await getRequest(
        baseUrl3, 'api/project/project/org?organizationId=$intOrganizationId');
  }

  static Future<http.Response> addUserManagementDetails(
      int projectId, int referenceId, int userId) async {
    return await postRequest(baseUrl4, 'api/lead/usermanage/add/SP', {
      'projectId': projectId,
      'referenceId': referenceId,
      'userId': userId,
    });
  }

  static Future<http.Response> fetchLeadSource() async {
    return await getRequest(
        baseUrl4, 'api/lead/leadsource/fetchall?leadSourceName=');
  }

  static Future<http.Response> saveVisit() async {
    return await getRequest(baseUrl4, 'api/lead/site/visit/save');
  }

  static Future<http.Response> saveSiteVisit(
    String name,
    String phoneNumber,
    String email,
    String address,
    int projectId,
    int flatTypeId,
    String budget,
    int sourceId,
    int subSourceId,
    DateTime followupDateTime,
    String remarks,
    int userId,
    int pincode,
    bool isSiteVisitForm,
  ) async {
    // Manually append query parameters to the endpoint
    String endpoint = 'api/lead/lead/save?isSiteVistForm=$isSiteVisitForm';

    return await postRequest(
      baseUrl4,
      endpoint,
      {
        'name': name,
        'phoneNumber': phoneNumber,
        'email': email,
        'homeLocation': address,
        'projectId': projectId,
        'preferredFlatType': flatTypeId.toString(),
        'budget': budget,
        'sourceId': sourceId,
        'subSourceId': subSourceId,
        'followupDateTime': followupDateTime.toIso8601String(),
        'remarks': remarks,
        'assignedToSales': userId,
        'pincode': pincode,
      },
    );
  }

  static Future<http.Response> updateRecord(
    int leadId,
    String name,
    String phoneNumber,
    String email,
    String address,
    int projectId,
    int flatTypeId,
    String budget,
    int sourceId,
    int subSourceId,
    DateTime followupDateTime,
    String remarks,
    int userId,
    int pincode,
    bool isSiteVisitForm,
  ) async {
    // Manually append query parameters to the endpoint
    String endpoint = 'api/lead/lead/update?isSiteVistForm=$isSiteVisitForm';

    return await putRequest(
      baseUrl4,
      endpoint,
      {
        'id': leadId,
        'name': name,
        'phoneNumber': phoneNumber,
        'email': email,
        'homeLocation': address,
        'projectId': projectId,
        'preferredFlatType': flatTypeId.toString(),
        'budget': budget,
        'sourceId': sourceId,
        'subSourceId': subSourceId,
        'followupDateTime': followupDateTime.toIso8601String(),
        'remarks': remarks,
        'assignedToSales': userId,
        'pincode': pincode,
      },
    );
  }

  static Future<http.Response> fetchLeadStatuses(String moduleNames) async {
    return await getRequest(baseUrl1,
        'api/user/commonreferencedetails/lead/status?typeName=Lead_Status&moduleNames=$moduleNames');
  }

  static Future<http.Response> fetchLeadTypes() async {
    return await getRequest(
        baseUrl1, 'api/user/commonreferencedetails/types/Lead_Type');
  }

  static Future<http.Response> fetchLeadSources() async {
    return await getRequest(
        baseUrl4, 'api/lead/leadsource/fetchall?leadSourceName=');
  }

  static Future<http.Response> fetchSubSources(int sourceId) async {
    return await getRequest(
        baseUrl4, 'api/lead/leadsubsource/fetchall?sourceId=$sourceId');
  }

  static Future<http.Response> fetchCountries() async {
    return await getRequest(
        baseUrl1, 'api/user/commonreferencedetails/types/Country_Code');
  }

  static Future<http.Response> fetchProjects() async {
    return await getRequest(baseUrl3, 'api/project/project/findAll?name=');
  }

  static Future<http.Response> fetchUnitTypes() async {
    return await getRequest(baseUrl3, 'api/project/unit/type/findAll');
  }

  static Future<http.Response> fetchBudgets() async {
    return await getRequest(
        baseUrl1, 'api/user/commonreferencedetails/types/Budget_Type');
  }

  static Future<http.Response> addLead(Map<String, dynamic> leadData) async {
    return await postRequest(baseUrl4, 'api/lead/lead/save', leadData);
  }

  static Future<http.Response> fetchRecord(String phoneNumber) async {
    // Ensure to handle null or invalid base URL and endpoint
    return await getRequest(
      baseUrl4,
      'api/lead/lead/fetchLeadByMobile?phoneNumber=$phoneNumber',
    );
  }

  static Future<http.Response> SalesUsers(
      int organizationId, int projectId) async {
    final String url =
        'api/lead/usermanage/users/S?organizationId=$organizationId&projectId=$projectId';
    return await getRequest(baseUrl1, url);
  }

  static Future<http.Response> sendAttendace(Map<String, dynamic> data) async {
    return await postRequest(
        baseUrl2, 'api/facility-management/attendance/submit', data);
  }

  static Future<http.Response> fetchTransactions({
    required String searchQuery,
    String beneficiaryName = '',
    String transactionType = '',
    String remiterName = '',
    String rangeOfDays = '0', // Default to '0'
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final endpoint = 'api/account/accountentry/fetchall';

    // Prepare the query parameters
    final queryParameters = {
      'remiterName': searchQuery,
      'beneficiaryName': beneficiaryName,
      'transactionType': transactionType,
      'startDate': startDate != null ? startDate.toIso8601String() : '',
      'endDate': endDate != null ? endDate.toIso8601String() : '',
    };

    // Include rangeOfDays only if no custom date range is set
    if (startDate == null || endDate == null) {
      queryParameters['rangeOfDays'] = rangeOfDays;
    } else {
      queryParameters['rangeOfDays'] =
          '0'; // Set rangeOfDays to '0' for custom date ranges
    }

    // Construct the URI with the query parameters
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParameters);

    // Call the getRequest method with the base URL and constructed endpoint
    return await getRequest(baseUrl1, uri.toString());
  }

  static Future<http.Response> getAddressByPinCode(
      String pincode, String location) async {
    final String endpoint =
        'api/lead/lead/pincode?pincode=$pincode&location=$location';
    return await getRequest(baseUrl1, endpoint);
  }

  static Future<http.Response> fetchUserAttendaceLocations(int userId) async {
    return await getRequest(baseUrl3,
        'api/facility-management/attendance/getqrassigned?userId=$userId');
  }

  static Future<http.Response> checkLoginStatus(int userId) async {
    return await getRequest(baseUrl3,
        'api/facility-management/attendance/loginorlogout?userId=$userId');
  }

  static Future<http.Response> fetchAccountEntries({
    required String searchQuery,
    String beneficiaryName = '',
    String transactionType = '',
    String amount = '',
    String minAmount = '',
    String maxAmount = '',
    String selectedAmountType = '',
    String rangeOfDays = '0',
    DateTime? startDate,
    DateTime? endDate,
    required int page,
    required int size,
  }) async {
    final String endpoint = 'api/account/accountentry/fetchallWithPagination';

    // Prepare the query parameters
    final Map<String, String> queryParameters = {
      'remiterName': searchQuery,
      'beneficiaryName': beneficiaryName,
      'transactionType': transactionType,
      'amount': amount,
      'minAmount': minAmount,
      'maxAmount': maxAmount,
      'selectedAmountType': selectedAmountType,
      'rangeOfDays': rangeOfDays,
      'startDate': startDate != null ? startDate.toIso8601String() : '',
      'endDate': endDate != null ? endDate.toIso8601String() : '',
      'page': page.toString(),
      'size': size.toString(),
    };
    // Include rangeOfDays only if no custom date range is set
    if (startDate == null || endDate == null) {
      queryParameters['rangeOfDays'] = rangeOfDays;
    } else {
      queryParameters['rangeOfDays'] =
          '0'; // Set rangeOfDays to '0' for custom date ranges
    }

    // final String queryString = Uri(queryParameters: queryParameters).query;
    // final String fullEndpoint = '$baseUrl1$endpoint?$queryString';
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParameters);
    return await getRequest(baseUrl1, uri.toString());
  }

  static Future<http.Response> fetchAccountEntryAmounts({
    String remiterName = '',
    String beneficiaryName = '',
    String transactionType = '',
    String amount = '',
    String minAmount = '',
    String maxAmount = '',
    String selectedAmountType = '',
    String rangeOfDays = '0',
    DateTime? startDate,
    DateTime? endDate,
    required String searchQuery,
  }) async {
    final String endpoint = 'api/account/accountentry/fetchamounts';

    // Prepare the query parameters
    final Map<String, String> queryParameters = {
      'remiterName': searchQuery,
      'beneficiaryName': beneficiaryName,
      'transactionType': transactionType,
      'amount': amount,
      'minAmount': minAmount,
      'maxAmount': maxAmount,
      'selectedAmountType': selectedAmountType,
      'rangeOfDays': rangeOfDays,
      'startDate': startDate != null ? startDate.toIso8601String() : '',
      'endDate': endDate != null ? endDate.toIso8601String() : '',
    };

    // Include rangeOfDays only if no custom date range is set
    if (startDate == null || endDate == null) {
      queryParameters['rangeOfDays'] = rangeOfDays;
    } else {
      queryParameters['rangeOfDays'] =
          '0'; // Set rangeOfDays to '0' for custom date ranges
    }

    final uri = Uri.parse(endpoint).replace(queryParameters: queryParameters);

    // final String queryString = Uri(queryParameters: queryParameters).query;
    // final String fullEndpoint = '$endpoint?$queryString';

    return await getRequest(baseUrl1, uri.toString());
  }

  static Future<http.Response> downloadImage({
    required String projectName,
    required String date,
    required String userName,
    required String phoneNumber,
    required String imageUrl,
  }) async {
    // Encode each query parameter to ensure proper URL formatting
    String encodedProjectName = Uri.encodeComponent(projectName);
    String encodedDate = Uri.encodeComponent(date);
    String encodedUserName = Uri.encodeComponent(userName);
    String encodedPhoneNumber = Uri.encodeComponent(phoneNumber);
    String encodedImageUrl = Uri.encodeComponent(imageUrl);

    // Use encoded values in the endpoint URL
    String endpoint =
        'api/facility-management/qrreport/get-image?projectName=$encodedProjectName&date=$encodedDate&userName=$encodedUserName&phoneNumber=$encodedPhoneNumber&imageUrl=$encodedImageUrl';

    // Make the HTTP request
    return await getRequest(baseUrl1, endpoint); // Use getRequest
  }

  static Future<http.Response> fetchScheduleReports(
    int organizationId,
    int projectId,
    String selectedDateRange,
  ) async {
    return await getRequest(baseUrl2,
        'api/facility-management/qrreport/getallschedulewithreports?organizationId=$organizationId&projectId=$projectId&range=$selectedDateRange');
  }

  static Future<http.Response> submitIssue(
      String issueData, File imageFile) async {
    final url = Uri.parse('${baseUrl2}api/project/issues/save');

    var request = http.MultipartRequest('POST', url);

    // Change the key from 'qrTransactionDataBean' to 'issues'
    request.fields['issues'] = issueData;

    if (imageFile != null && await imageFile.exists()) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'imageFile', // Ensure this key matches what the backend expects
          imageFile.path,
          contentType: MediaType(
            'image',
            path.extension(imageFile.path).replaceFirst('.', ''),
          ),
        ),
      );
    }

    request.headers['Authorization'] = 'Bearer $accessToken';

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return response;
    } catch (e) {
      throw Exception('Error during upload: $e');
    }
  }

  static Future<http.Response> fetchAttendanceReport(
      int userId,
      int organizationId,
      String selectedLocation,
      String shiftIds,
      String selectedRole,
      String selectedDateRange) async {
    return await getRequest(baseUrl2,
        'api/facility-management/shiftBasedAttendance/dashboard/attendance/data?userId=$userId&organizationId=$organizationId&shiftIds=$shiftIds&locationId=$selectedLocation&roleId=$selectedRole&range=$selectedDateRange');
  }

  static Future<http.Response> fetchAttendanceLocation(
      int? organizationId) async {
    return await getRequest(baseUrl2,
        'api/facility-management/facility/getQrByOrganizationId?organizationId=$organizationId');
  }

  static Future<http.Response> fetchshiftData() async {
    return await getRequest(
        baseUrl2, 'api/user/commonreferencedetails/types/Shift_Timings');
  }

  static Future<http.Response> fetchLocation(int? organizationId) async {
    return await getRequest(baseUrl2,
        'api/facility-management/facility/getattendancelocationbyorg?orgId=$organizationId');
  }

  // static fetchAttendanceDetails(int i, int j, String selectedLocation, String selectedShift, String selectedDateRange) {}

  static Future<http.Response> fetchAttendanceDetails(
      int userId,
      String userName,
      String attendanceStatus,
      String selectedLocation,
      String selectedShift,
      String selectedRole,
      String selectedDateRange,
      String page,
      int size) async {
    return await getRequest(
        baseUrl2,
        // 'api/facility-management/attendance/dashboard/attendance/data?userId=$userId&organizationId=$organizationId&shiftId=$selectedShift&locationId=$selectedLocation&range=$selectedDateRange'
        'api/facility-management/shiftBasedAttendance/allAttendance?userName=$userName&userId=$userId&page=$page&size=$size&&attendanceStatus=$attendanceStatus&shiftIds=$selectedShift&locationId=$selectedLocation&roleId=$selectedRole&range=$selectedDateRange');
  }

  // Method to store device token with query parameters (matching your Java backend)
  static Future<http.Response> storeDeviceToken(int userId, String deviceToken,
      String androidId, int organizationId) async {
    // Prepare the data as URL query parameters
    final String url = Uri.parse(
            '$notificationUrl/api/user/fcm/storetoken?userId=$userId&deviceToken=$deviceToken&androidId=$androidId&organizationId=$organizationId')
        .toString();

    // Headers setup: Adding Authorization header if accessToken exists
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      if (accessToken != null)
        'Authorization': 'Bearer $accessToken', // Add Authorization header
      if (userId != null) 'proxyId': userId.toString(),
      if (userId != null) 'userId': userId.toString(),
    };

    try {
      // Send the POST request with query parameters in the URL and headers
      final response = await http.post(
        Uri.parse(url),
        headers: headers, // Add the headers here
      );

      return response;
    } catch (e) {
      throw Exception("Error during post request: $e");
    }
  }

  // static updateDeviceTokenWithAndroidId(int userId, String newToken, String androidId) {}

  // Method to store device token with query parameters (using PUT method)
  static Future<http.Response> updateDeviceTokenWithAndroidId(int userId,
      String deviceToken, String androidId, int organizationId) async {
    // Prepare the data as URL query parameters
    final String url = Uri.parse(
            '$notificationUrl/api/user/fcm/updateDeviceToken?userId=$userId&deviceToken=$deviceToken&androidId=$androidId&organizationId=$organizationId')
        .toString();

    // Headers setup: Adding Authorization header if accessToken exists
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      if (accessToken != null)
        'Authorization': 'Bearer $accessToken', // Add Authorization header
      if (userId != null) 'proxyId': userId.toString(),
      if (userId != null) 'userId': userId.toString(),
    };

    try {
      // Send the PUT request with query parameters in the URL and headers
      final response = await http.put(
        Uri.parse(url),
        headers: headers, // Add the headers here
      );

      // Return the response for further processing
      return response;
    } catch (e) {
      throw Exception("Error during PUT request: $e");
    }
  }

  // Method to send notification using query parameters
  // Updated sendNotification method
  static Future<http.Response> sendNotification({
    required List<int> userIds,
    required String title,
    required String body,
    String? route = '', // Default route if not provided
    required int organizationId, // Organization ID passed as parameter
  }) async {
    if (userIds.isEmpty) {
      throw Exception("User IDs must not be empty.");
    }

    String userIdsString = userIds.join(',');

    // Prepare the URL with query parameters
    final String url = Uri.parse(
      '$notificationUrl/api/user/fcm/sendnotification?userIds=$userIdsString&title=$title&body=$body&route=$route&organizationId=$organizationId',
    ).toString();

    // Setup headers
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      if (accessToken != null)
        'Authorization':
            'Bearer $accessToken', // Add Authorization header if available
    };

    try {
      // Send the POST request with query parameters in the URL and headers
      final response = await http.post(
        Uri.parse(url),
        headers: headers, // Attach headers if necessary
      );

      if (response.statusCode == 200) {
        print('Notification sent successfully');
      } else {
        throw Exception('Failed to send notification: ${response.body}');
      }

      // Return the response
      return response;
    } catch (e) {
      throw Exception("Error sending notification: $e");
    }
  }

  static Future<http.Response> fetchRoleReport(
      int userId,
      int organizationId,
      String selectedLocation,
      String shiftIds,
      String selectedRole,
      String selectedDateRange) async {
    // Ensure that there are no invisible characters
    final String url =
        'api/facility-management/shiftBasedAttendance/rolebasedreport?userId=$userId&organizationId=$organizationId&shiftIds=$shiftIds&locationId=$selectedLocation&range=$selectedDateRange';

    return await getRequest(baseUrl2, url);
  }

  /// Site-wise logged in / not logged in counts, as the web dashboard's
  /// "SITE WISE ATTENDANCE" table shows. Same filter set as the role report.
  static Future<http.Response> fetchLocationWiseReport(
      int userId,
      int organizationId,
      String selectedLocation,
      String shiftIds,
      String selectedRole,
      String selectedDateRange) async {
    final String url =
        'api/facility-management/shiftBasedAttendance/dashboard/attendance/locationwise'
        '?userId=$userId&organizationId=$organizationId&shiftIds=$shiftIds'
        '&locationId=$selectedLocation&roleId=$selectedRole&range=$selectedDateRange';

    return await getRequest(baseUrl2, url);
  }

  static Future<http.Response> fetchRoles(
      int? organizationId, String selectedLocation) async {
    return await getRequest(baseUrl2,
        'api/hrm/employee/getrolebasedonproject?organizationId=$organizationId&locationId=$selectedLocation');
  }

  static Future<http.Response> deleteDeviceToken(
    int userId,
    String androidId,
    int organizationId,
    String deviceToken,
  ) async {
    // Prepare the data as URL query parameters
    final String url = Uri.parse(
            '$notificationUrl/api/user/fcm/delete?userId=$userId&androidId=$androidId&organizationId=$organizationId&deviceToken=$deviceToken')
        .toString();

    // Headers setup: Adding Authorization header if accessToken exists
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      if (accessToken != null)
        'Authorization': 'Bearer $accessToken', // Add Authorization header
      if (userId != null) 'proxyId': userId.toString(),
      if (userId != null) 'userId': userId.toString(),
    };

    try {
      // Send the PUT request with query parameters in the URL and headers
      final response = await http.delete(
        Uri.parse(url),
        headers: headers, // Add the headers here
      );

      // Return the response for further processing
      return response;
    } catch (e) {
      throw Exception("Error during PUT request: $e");
    }
  }

  static Future<http.Response> fetchOrgProjectsInOtScreen(
      int organizationId) async {
    return await getRequest(baseUrl3,
        'api/project/project/findAll?name=&organizationId=$organizationId');
  }

  static Future<http.Response> fetchOrgRoleInOtScreen(
      int intOraganizationId) async {
    return await getRequest(baseUrl1,
        'api/user/role/fetchall?roleName=&organizationId=$intOraganizationId');
  }

  static Future<http.Response> fetchOrgEmployeeInOtScreen(
      int intOraganizationId, int projectAssigned, int employeeRoleId) async {
    return await getRequest(baseUrl1,
        'api/hrm/employee/getall/org?organizationId=$intOraganizationId&firstName=&projectAssigned=$projectAssigned&employeeRoleId=$employeeRoleId');
  }

  static Future<http.Response> postOt(
      Map<String, dynamic> employeeOTBean) async {
    return await postRequest(
        baseUrl1, 'api/facility-management/employeeOT/save', employeeOTBean);
  }

  static Future<http.Response> fetchOtReport({
    required String projectId,
    required String roleId,
    required String firstName,
    required String range,
    required int? organizationId,
  }) async {
    return await getRequest(baseUrl2,
        'api/facility-management/employeeOT/employee/getall?toLocation=&projectId=$projectId&organizationId=$organizationId&roleId=$roleId&firstName=$firstName&range=$range');
  }

  static Future<http.Response> fetchOtReportProjectWise(
      int organizationId, String selectedDateRange) async {
    return await getRequest(baseUrl2,
        'api/facility-management/employeeOT/employee/otcount?toLocation=&projectId=&organizationId=$organizationId&range=$selectedDateRange');
  }

  static Future<http.Response> fetchRolesInOT(
      int? organizationId, String selectedLocation) async {
    return await getRequest(baseUrl2,
        'api/hrm/employee/getrolebasedonproject?organizationId=$organizationId&locationId=$selectedLocation');
  }

  static Future<http.Response> fetchProjectsInOtScreen(int? orgId) async {
    return await getRequest(
        baseUrl2, 'api/project/project/findAll?name=&organizationId=$orgId');
  }

  static Future<http.Response> submitFoTransactionData(
      String qrTransactionData, File imageFile) async {
    final url =
        Uri.parse('${baseUrl2}api/facility-management/fieldOfficerPatrol/save');

    var request = http.MultipartRequest('POST', url);

    request.fields['fieldOfficerPatrolBean'] = qrTransactionData;

    if (imageFile != null && await imageFile.exists()) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'imageFile',
          imageFile.path,
          contentType: MediaType(
            'image',
            path.extension(imageFile.path).replaceFirst('.', ''),
          ),
        ),
      );
    }

    request.headers['Authorization'] = 'Bearer $accessToken';

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return response;
    } catch (e) {
      throw Exception('Error during upload: $e');
    }
  }

  static Future<http.Response> fetchFieldOfficerPatrolReports(
    int organizationId,
    String projectId,
    String selectedDateRange,
    int page,
    int pageSize,
    String searchQuery,
  ) async {
    return await getRequest(baseUrl2,
        'api/facility-management/fieldOfficerPatrol/getallfiledofficepatrol?organizationId=$organizationId&projectId=$projectId&rangeOfDays=$selectedDateRange&page=$page&size=$pageSize&userName=$searchQuery');
  }

  /// Totals, per-project, per-officer and per-day figures for the FO report.
  /// Same date-range contract as [fetchFieldOfficerPatrolReports].
  static Future<http.Response> fetchFieldOfficerAnalytics(
    int organizationId,
    String projectId,
    String selectedDateRange,
    String searchQuery,
  ) async {
    return await getRequest(baseUrl2,
        'api/facility-management/fieldOfficerPatrol/analytics?organizationId=$organizationId&projectId=$projectId&rangeOfDays=$selectedDateRange&userName=${Uri.encodeQueryComponent(searchQuery)}');
  }

  /// Assigned FO visits with no scan: "Missed" on past days, "Pending" today.
  static Future<http.Response> fetchFieldOfficerMissedVisits(
    int organizationId,
    String projectId,
    String selectedDateRange,
    int page,
    int pageSize,
    String searchQuery,
  ) async {
    return await getRequest(baseUrl2,
        'api/facility-management/fieldOfficerPatrol/missed?organizationId=$organizationId&projectId=$projectId&rangeOfDays=$selectedDateRange&page=$page&size=$pageSize&userName=${Uri.encodeQueryComponent(searchQuery)}');
  }

  static Future<http.Response> FodownloadImage({
    required String projectName,
    required String date,
    required String userName,
    required String phoneNumber,
    required String imageUrl,
  }) async {
    // Encode each query parameter to ensure proper URL formatting
    String encodedProjectName = Uri.encodeComponent(projectName);
    String encodedDate = Uri.encodeComponent(date);
    String encodedUserName = Uri.encodeComponent(userName);
    String encodedPhoneNumber = Uri.encodeComponent(phoneNumber);
    String encodedImageUrl = Uri.encodeComponent(imageUrl);

    // Use encoded values in the endpoint URL
    String endpoint =
        'api/facility-management/fieldOfficerPatrol/get-fieldofficer-image?projectName=$encodedProjectName&date=$encodedDate&userName=$encodedUserName&phoneNumber=$encodedPhoneNumber&imageUrl=$encodedImageUrl';

    // Make the HTTP request
    return await getRequest(baseUrl1, endpoint); // Use getRequest
  }

  static Future<http.Response> submitRegisterFace(
    String empId,
    File imageFile,
    // List<double> embeddings
  ) async {
    final url = Uri.parse(
        '${baseUrl2}api/facility-management/shiftBasedAttendance/register');

    var request = http.MultipartRequest('POST', url);

    // Convert list to JSON string
    // String embeddingsJson = jsonEncode(embeddings);
    request.fields['employeeId'] = empId;
    // request.fields['embeddings'] = embeddingsJson;

    if (await imageFile.exists()) {
      final fileExtension = path.extension(imageFile.path).toLowerCase();
      final mimeType = fileExtension == '.png' ? 'png' : 'jpeg';

      request.files.add(
        await http.MultipartFile.fromPath(
          'fileName',
          imageFile.path,
          contentType: MediaType('image', mimeType),
        ),
      );
    } else {
      throw Exception('Image file does not exist: ${imageFile.path}');
    }

    // Add Authorization header
    request.headers['Authorization'] = 'Bearer $accessToken';

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        print('✅ Face registered: ${response.body}');
      } else {
        print('❌ Server error: ${response.statusCode}, Body: ${response.body}');
      }

      return response;
    } catch (e) {
      print('🚨 Error during face registration: $e');
      throw Exception('Error during upload: $e');
    }
  }

  static Future<http.Response> submitCaptureFace({
    required File imageFile,
    // required List<double> embeddings,
    required int shiftId,
    required int? organizationId,
    required bool isLogin,
    required int? locationId, // true = login, false = logout
    required double latitude,
    required double longitude,
  }) async {
    final endpoint = isLogin ? 'loginPersonDetection' : 'logoutPersonDetection';

    final url = Uri.parse(
      '${baseUrl2}api/facility-management/shiftBasedAttendance/$endpoint',
    );

    var request = http.MultipartRequest('POST', url);

    // request.fields['embeddings'] = jsonEncode(embeddings);
    request.fields['shiftId'] = shiftId.toString();
    request.fields['organizationId'] = organizationId.toString();
    request.fields['locationId'] = locationId.toString();
    request.fields['lat'] = latitude.toString();
    request.fields['lang'] = longitude.toString();

    if (await imageFile.exists()) {
      final fileExtension = path.extension(imageFile.path).toLowerCase();
      final mimeType = fileExtension == '.png' ? 'png' : 'jpeg';

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          contentType: MediaType('image', mimeType),
        ),
      );
    } else {
      throw Exception('Image file does not exist: ${imageFile.path}');
    }

    request.headers['Authorization'] = 'Bearer $accessToken';

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        print(
            '✅ [${isLogin ? 'IN' : 'OUT'}] Face capture submitted successfully');
      } else {
        print(
            '❌ [${isLogin ? 'IN' : 'OUT'}] Server responded with ${response.statusCode}: ${response.body}');
      }

      return response;
    } catch (e) {
      print('🚨 [${isLogin ? 'IN' : 'OUT'}] Error submitting capture: $e');
      throw Exception('Error during upload: $e');
    }
  }

  static Future<http.Response> fetchUsersForFace(
      String organizationId, String userName) async {
    return await getRequest(baseUrl1,
        'api/user/user/fetchall?organizationId=$organizationId&userName=$userName');
  }

  static Future<http.Response> fetchUsersForAbsent(
      String organizationId, String locationId, String userName) async {
    return await getRequest(baseUrl1,
        'api/user/user/location/users?organizationId=$organizationId&locationId=$locationId&userName=$userName');
  }

  static Future<http.Response> generateAttendanceExcel({
    required int locationId,
    required int month,
    required int year,
    required String? selectedStatus,
  }) async {
    final String url =
        'api/facility-management/shiftBasedAttendance/allAttendance?userName=&userId=$userId&page=0&size=15&range=0&startDate=&endDate=&attendanceStatus=$selectedStatus&shiftIds=0&locationId=$locationId&roleId=0&isExportExcel=true&month=$month&year=$year';

    // If you need headers, add them here
    // final headers = {'Accept': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'};
    // return await getRequest(baseUrl2, url, headers: headers);

    return await getRequest(baseUrl2, url);
  }

  static Future<http.Response> submitAbsentEmployees({
    required int shiftId,
    required int organizationId,
    required int locationId,
    required List<int> userIds,
  }) async {
    final userIdsParam = userIds.join(',');
    final String endpoint =
        'api/facility-management/shiftBasedAttendance/absentemployees?shiftId=$shiftId&organizationId=$organizationId&locationId=$locationId&userId=$userIdsParam';
    // Use postRequest with an empty body
    return await postRequest(baseUrl1, endpoint, {});
  }

  // ===========================================================================
  // PARKING
  // ---------------------------------------------------------------------------
  // Front-end for facility-management-service `/parking/*`. All setup (sites,
  // zones, lanes, tariffs, devices) is done on the WEB admin — the app only
  // reads the configured sites/lanes and runs the entry / exit / shift flows.
  // ===========================================================================
  static const String _parking = 'api/facility-management/parking';

  /// True for any 2xx.
  ///
  /// The parking controllers return **201 CREATED** from the POSTs that create
  /// something — `shift/open` and `exception/raise` — so comparing against 200
  /// alone reports a successful shift open as a failure.
  static bool isSuccess(int statusCode) =>
      statusCode >= 200 && statusCode < 300;

  /// Sites the attendant can pick from (web-configured).
  ///
  /// Sites belong to a project, so [projectId] narrows the list to one — an
  /// operator at Horizon should not be scrolling past Earth & Sky.
  static Future<http.Response> getParkingSites({
    int? projectId,
    String? siteName,
  }) async {
    final params = <String>[
      if (projectId != null) 'projectId=$projectId',
      if (siteName != null && siteName.trim().isNotEmpty)
        'siteName=${Uri.encodeQueryComponent(siteName.trim())}',
    ];
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    return await getRequest(baseUrl1, '$_parking/site/getall/sites$query');
  }

  /// Lanes for a site. Direction (IN/OUT/BIDIRECTIONAL) decides whether a lane
  /// is valid for entry or exit — the backend rejects an entry on an OUT lane.
  /// Zones (levels) at a site — used to filter the movement register by level,
  /// as the web's Zone dropdown does.
  static Future<http.Response> getParkingZonesBySite(int siteId) async {
    return await getRequest(baseUrl1, '$_parking/zone/site/$siteId');
  }

  static Future<http.Response> getParkingLanesBySite(int siteId) async {
    return await getRequest(baseUrl1, '$_parking/lane/site/$siteId');
  }

  /// Live occupancy for the whole site (zone by zone).
  static Future<http.Response> getParkingOccupancyBySite(int siteId) async {
    return await getRequest(baseUrl1, '$_parking/occupancy/site/$siteId');
  }

  /// Shops that can validate parking at this site.
  static Future<http.Response> getParkingMerchantsBySite(int siteId) async {
    return await getRequest(baseUrl1, '$_parking/merchant/site/$siteId');
  }

  /// Apply a shop's validation to a stay.
  ///
  /// The stamped bill is handed over at the barrier with a queue behind it, so
  /// this is called from the exit screen rather than a separate one — sending
  /// the cashier elsewhere to re-find the same ticket is how a validation gets
  /// skipped and the customer charged in full.
  static Future<http.Response> parkingApplyValidation({
    required int siteId,
    required int merchantId,
    required String ticketNumber,
    String? billNumber,
    double? billAmount,
    int? validatedBy,
  }) async {
    final Map<String, dynamic> body = {
      'siteId': siteId,
      'merchantId': merchantId,
      'ticketNumber': ticketNumber,
      if (billNumber != null && billNumber.trim().isNotEmpty)
        'billNumber': billNumber.trim(),
      if (billAmount != null) 'billAmount': billAmount,
      if (validatedBy != null) 'validatedBy': validatedBy,
    };
    return await postRequest(baseUrl1, '$_parking/validation/validate', body);
  }

  /// What each shop owes for the month's validations.
  ///
  /// `month` is an ISO date; the server takes the month it falls in.
  static Future<http.Response> getParkingRecoveryStatement({
    required int siteId,
    required String month,
  }) async {
    return await getRequest(baseUrl1,
        '$_parking/validation/recovery-statement?siteId=$siteId&month=$month');
  }

  // --- Entry -----------------------------------------------------------------

  /// Admit a vehicle. `laneId` is mandatory — the backend derives the zone from
  /// the lane and refuses if the lane is inactive or is an exit lane.
  ///
  /// For a normal public entry `credentialType` is MANUAL and `credentialValue`
  /// is the plate the attendant typed; the ticket is *issued by* this call.
  static Future<http.Response> parkingSessionEntry({
    required int laneId,
    required String credentialType,
    required String credentialValue,
    required String vehicleType,

    /// The plate actually on the vehicle at the barrier.
    ///
    /// Separate from `credentialValue`, which for a pass or tag is the pass or
    /// tag number. Without this the server cannot compare the two, and anyone
    /// who knows a live pass number parks free on someone else's pass.
    String? vehicleNumber,
    int? zoneId,
    int? operatorId,
    int? shiftId,
    String? entryImageUrl,
    bool overrideCapacity = false,
    String? overrideReason,
    String? remarks,
  }) async {
    final Map<String, dynamic> body = {
      'laneId': laneId,
      'credentialType': credentialType,
      'credentialValue': credentialValue,
      'vehicleType': vehicleType,
      'overrideCapacity': overrideCapacity,
      'syncSource': 'MOBILE',
      if (vehicleNumber != null && vehicleNumber.trim().isNotEmpty)
        'vehicleNumber': vehicleNumber.trim(),
      if (zoneId != null) 'zoneId': zoneId,
      if (operatorId != null) 'operatorId': operatorId,
      if (shiftId != null) 'shiftId': shiftId,
      if (entryImageUrl != null) 'entryImageUrl': entryImageUrl,
      if (overrideReason != null) 'overrideReason': overrideReason,
      if (remarks != null) 'remarks': remarks,
    };
    return await postRequest(baseUrl1, '$_parking/session/entry', body);
  }

  // --- Exit ------------------------------------------------------------------

  /// Price the stay before taking payment. Does NOT release the vehicle.
  static Future<http.Response> parkingExitLookup({
    required int siteId,
    required String credentialType,
    required String credentialValue,
  }) async {
    final String endpoint = '$_parking/exit/lookup'
        '?siteId=$siteId'
        '&credentialType=${Uri.encodeQueryComponent(credentialType)}'
        '&credentialValue=${Uri.encodeQueryComponent(credentialValue)}';
    return await getRequest(baseUrl1, endpoint);
  }

  /// Settle and release. Returns the receipt (including change due for cash).
  static Future<http.Response> parkingExitConfirm({
    required int sessionId,
    int? exitLaneId,
    int? operatorId,
    int? shiftId,
    String? paymentMode,
    double? tenderedAmount,
    String? referenceNo,
    bool waive = false,
    String? waiveReason,
    double? waiveAmount,
    int? approvedBy,
    String? exitImageUrl,
    String? remarks,
  }) async {
    final Map<String, dynamic> body = {
      'sessionId': sessionId,
      'waive': waive,
      'syncSource': 'MOBILE',
      if (exitLaneId != null) 'exitLaneId': exitLaneId,
      if (operatorId != null) 'operatorId': operatorId,
      if (shiftId != null) 'shiftId': shiftId,
      if (paymentMode != null) 'paymentMode': paymentMode,
      if (tenderedAmount != null) 'tenderedAmount': tenderedAmount,
      if (referenceNo != null) 'referenceNo': referenceNo,
      if (waiveReason != null) 'waiveReason': waiveReason,
      if (waiveAmount != null) 'waiveAmount': waiveAmount,
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (exitImageUrl != null) 'exitImageUrl': exitImageUrl,
      if (remarks != null) 'remarks': remarks,
    };
    return await postRequest(baseUrl1, '$_parking/exit/confirm', body);
  }

  // --- Shift (cash reconciliation) -------------------------------------------

  /// The operator's currently-open shift, if any. Used to resume after the app
  /// is killed mid-shift rather than opening a second one.
  static Future<http.Response> getParkingOpenShift(int operatorUserId) async {
    return await getRequest(
        baseUrl1, '$_parking/shift/open/operator/$operatorUserId');
  }

  static Future<http.Response> parkingShiftOpen({
    required int siteId,
    required int operatorUserId,
    int? laneId,
    double? openingFloat,
  }) async {
    String endpoint = '$_parking/shift/open'
        '?siteId=$siteId&operatorUserId=$operatorUserId';
    if (laneId != null) endpoint += '&laneId=$laneId';
    if (openingFloat != null) endpoint += '&openingFloat=$openingFloat';
    return await postRequest(baseUrl1, endpoint, {});
  }

  static Future<http.Response> parkingShiftClose({
    required int shiftId,
    required double declaredCash,
    String? varianceReason,
  }) async {
    String endpoint =
        '$_parking/shift/$shiftId/close?declaredCash=$declaredCash';
    if (varianceReason != null && varianceReason.isNotEmpty) {
      endpoint += '&varianceReason=${Uri.encodeQueryComponent(varianceReason)}';
    }
    return await postRequest(baseUrl1, endpoint, {});
  }

  static Future<http.Response> getParkingShiftSummary(int shiftId) async {
    return await getRequest(baseUrl1, '$_parking/shift/$shiftId');
  }

  // --- Register + dashboard ---------------------------------------------------

  /// Vehicle movement register. `status` is INSIDE | EXITED | ALL; `from`/`to`
  /// are ISO dates and only meaningful for the historical views.
  static Future<http.Response> parkingMovementSearch({
    required int siteId,
    String status = 'INSIDE',
    String? from,
    String? to,
    String? plate,
    int? zoneId,
    String? vehicleType,
    int page = 0,
    int pageSize = 50,
  }) async {
    final params = <String, String>{
      'siteId': '$siteId',
      'status': status,
      'page': '$page',
      'pageSize': '$pageSize',
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
      if (plate != null && plate.trim().isNotEmpty) 'plate': plate.trim(),
      if (zoneId != null) 'zoneId': '$zoneId',
      if (vehicleType != null && vehicleType.isNotEmpty)
        'vehicleType': vehicleType,
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return await getRequest(baseUrl1, '$_parking/movement/search?$query');
  }

  /// Takings cut by mode, vehicle type, lane and operator.
  static Future<http.Response> getParkingCollectionReport({
    required int siteId,
    required String fromDate,
    required String toDate,
  }) async {
    return await getRequest(
        baseUrl1,
        '$_parking/report/collection'
        '?siteId=$siteId&fromDate=$fromDate&toDate=$toDate');
  }

  /// Traffic, dwell distribution and utilisation.
  static Future<http.Response> getParkingOperationsReport({
    required int siteId,
    required String fromDate,
    required String toDate,
  }) async {
    return await getRequest(
        baseUrl1,
        '$_parking/report/operations'
        '?siteId=$siteId&fromDate=$fromDate&toDate=$toDate');
  }

  /// Excel export of a report.
  ///
  /// Returns the workbook bytes rather than JSON — the server builds the sheet
  /// from the same figures it reported, so the file cannot drift from what was
  /// on screen. `reportCode` is COLLECTION | OPERATIONS | SESSIONS.
  static Future<http.Response> exportParkingReport({
    required String reportCode,
    required int siteId,
    required String fromDate,
    required String toDate,
  }) async {
    return await getRequest(
        baseUrl1,
        '$_parking/report/$reportCode/export'
        '?siteId=$siteId&fromDate=$fromDate&toDate=$toDate');
  }

  /// The supervisor's wall screen — occupancy, today's money, dead devices,
  /// pending decisions.
  static Future<http.Response> getParkingLiveDashboard(int siteId) async {
    return await getRequest(
        baseUrl1, '$_parking/report/dashboard/live/$siteId');
  }

  /// Creates or updates a site incident.
  ///
  /// The same endpoint serves both: `siteIncidentId` 0 creates, any other value
  /// updates. The caller builds the whole body because the field set is fixed
  /// by the backend contract and a partial map is rejected rather than merged.
  static Future<http.Response> saveSiteIncident(
      Map<String, dynamic> incident) async {
    return await postRequest(
        baseUrl2, 'api/facility-management/siteIncident/save', incident);
  }

  /// Site incidents, paged and filtered.
  ///
  /// Every filter is optional: the backend reads `0` as "any" for the id
  /// filters and an empty string as "any" for [status] and the dates, so the
  /// defaults are passed through rather than omitted from the query string.
  static Future<http.Response> getAllSiteIncidents({
    required int organizationId,
    int page = 0,
    int size = 15,
    int locationId = 0,
    int incidentTypeId = 0,
    int severityId = 0,
    int responsibleEmployeeId = 0,
    String status = '',
    String startDate = '',
    String endDate = '',
  }) async {
    return await getRequest(
        baseUrl2,
        'api/facility-management/siteIncident/getAllSiteIncidents'
        '?page=$page&size=$size&organizationId=$organizationId'
        '&locationId=$locationId&incidentTypeId=$incidentTypeId'
        '&severityId=$severityId&responsibleEmployeeId=$responsibleEmployeeId'
        '&status=$status&startDate=$startDate&endDate=$endDate');
  }

  // ===========================================================================
  // MANUAL ATTENDANCE
  // ---------------------------------------------------------------------------
  // Front-end for facility-management-service `/manualattendance/*` — the same
  // sheet the web shows at `attendance/manualAttendance`.
  //
  // Face recognition decides who was present and nobody reviews it. The sheet
  // puts every punch made at one site on one day in front of the supervisor who
  // was there: tick the genuine ones, remove the ones that should never have
  // been recorded, move the ones worked at another site.
  //
  // The backend decides the state of every row (checked / selectable / movable /
  // restorable / undoMovable and the status label), so the screen renders what
  // it is handed rather than working any of it out.
  // ===========================================================================
  static const String _manualAttendance =
      'api/facility-management/manualattendance';

  /// Traces one manual attendance call: the verb, the full URL that was hit,
  /// what was sent with it and the status and body that came back.
  ///
  /// Every call on this screen is a query string built out of five filters, so
  /// when the sheet arrives empty or an action is refused the answer is nearly
  /// always in the URL rather than in the screen. It is logged here so the
  /// screen itself never has to show a status code to a supervisor.
  static http.Response _traceManualAttendance(
    String verb,
    String endpoint,
    http.Response response, {
    Object? payload,
  }) {
    final body = response.body.length > 400
        ? '${response.body.substring(0, 400)}…'
        : response.body;
    debugPrint('ManualAttendance → $verb $baseUrl1$endpoint'
        '${payload == null ? '' : '\n   body: ${json.encode(payload)}'}'
        '\n   ← ${response.statusCode} $body');
    return response;
  }

  /// The sheet itself, paged.
  ///
  /// The day is a **range**: the controller binds `startDate` and `endDate` and
  /// knows no `attendanceDate`, so a parameter by that name is dropped by Spring
  /// without a word and the sheet comes back unfiltered by date. Both are
  /// `yyyy-MM-dd`, and the same day in both is the single-day sheet the web
  /// opens on.
  ///
  /// Every filter is optional to the backend: `0` means "any" for the id
  /// filters and an empty string means "any" for the dates and the two text
  /// searches, so the defaults are passed through rather than omitted.
  static Future<http.Response> getManualAttendances({
    int page = 0,
    int size = 15,
    int locationId = 0,
    String startDate = '',
    String endDate = '',
    int shiftId = 0,
    int statusId = 0,
    String userName = '',
    String employeeNumber = '',
  }) async {
    final endpoint = '$_manualAttendance/getAllManualAttendances'
        '?page=$page&size=$size&locationId=$locationId'
        '&startDate=$startDate&endDate=$endDate'
        '&shiftId=$shiftId&statusId=$statusId'
        '&userName=${Uri.encodeQueryComponent(userName)}'
        '&employeeNumber=${Uri.encodeQueryComponent(employeeNumber)}';
    return _traceManualAttendance(
        'GET', endpoint, await getRequest(baseUrl1, endpoint));
  }

  /// Header counts for the chosen site and range — logged in, pending,
  /// verified, removed and moved out. Not affected by the status filter, which
  /// is why it is a separate call rather than a field on the page.
  ///
  /// Takes the same `startDate`/`endDate` pair as the sheet, so the counts and
  /// the rows under them always describe the same days.
  static Future<http.Response> getManualAttendanceCount({
    int locationId = 0,
    String startDate = '',
    String endDate = '',
    int shiftId = 0,
  }) async {
    final endpoint = '$_manualAttendance/count?locationId=$locationId'
        '&startDate=$startDate&endDate=$endDate&shiftId=$shiftId';
    return _traceManualAttendance(
        'GET', endpoint, await getRequest(baseUrl1, endpoint));
  }

  /// The options of the status filter.
  ///
  /// Read from common reference data, so which states exist and what they are
  /// called is configured rather than written into the app — the screen opens
  /// on the first one the backend returns.
  static Future<http.Response> getManualAttendanceStatuses() async {
    const endpoint = '$_manualAttendance/statuses';
    return _traceManualAttendance(
        'GET', endpoint, await getRequest(baseUrl1, endpoint));
  }

  /// Ticks the punches the supervisor accepted.
  static Future<http.Response> verifyManualAttendance({
    required List<int> attendanceIds,
    required int verifiedBy,
    String remarks = '',
  }) async {
    const endpoint = '$_manualAttendance/verify';
    final payload = {
      'attendanceIds': attendanceIds,
      'verifiedBy': verifiedBy,
      'remarks': remarks,
    };
    return _traceManualAttendance(
        'POST', endpoint, await postRequest(baseUrl1, endpoint, payload),
        payload: payload);
  }

  /// Takes back ticks that were saved earlier.
  static Future<http.Response> unVerifyManualAttendance({
    required List<int> attendanceIds,
    required int verifiedBy,
    String remarks = '',
  }) async {
    const endpoint = '$_manualAttendance/unverify';
    final payload = {
      'attendanceIds': attendanceIds,
      'verifiedBy': verifiedBy,
      'remarks': remarks,
    };
    return _traceManualAttendance(
        'POST', endpoint, await postRequest(baseUrl1, endpoint, payload),
        payload: payload);
  }

  /// Removes a punch that should never have been recorded.
  ///
  /// The attendance row is kept and flagged, never deleted — which is why this
  /// can be undone with [restoreManualAttendance].
  static Future<http.Response> removeManualAttendance({
    required int attendanceId,
    required int removedBy,
    String remarks = '',
  }) async {
    final endpoint = '$_manualAttendance/remove/$attendanceId'
        '?removedBy=$removedBy&remarks=${Uri.encodeQueryComponent(remarks)}';
    return _traceManualAttendance(
        'DELETE', endpoint, await deleteRequest(baseUrl1, endpoint));
  }

  /// Sends a punch to the site it was actually worked at — marked in at one
  /// gate, on duty at another. The punch is genuine, so it moves rather than
  /// being removed, and the other site's supervisor verifies it there.
  static Future<http.Response> moveManualAttendance({
    required int attendanceId,
    required int movedLocationId,
    required int movedBy,
    String remarks = '',
  }) async {
    final endpoint = '$_manualAttendance/move/$attendanceId'
        '?movedLocationId=$movedLocationId&movedBy=$movedBy'
        '&remarks=${Uri.encodeQueryComponent(remarks)}';
    return _traceManualAttendance(
        'PUT', endpoint, await putRequest(baseUrl1, endpoint, {}));
  }

  /// Brings a moved punch back to the site it was marked at.
  ///
  /// Raised against the MOVED row (`movedManualAttendanceId`), not the
  /// verification row — they are different records.
  static Future<http.Response> undoMoveManualAttendance({
    required int manualAttendanceId,
    required int movedBy,
  }) async {
    final endpoint =
        '$_manualAttendance/undo-move/$manualAttendanceId?movedBy=$movedBy';
    return _traceManualAttendance(
        'PUT', endpoint, await putRequest(baseUrl1, endpoint, {}));
  }

  /// Puts back a punch that was removed by mistake.
  static Future<http.Response> restoreManualAttendance({
    required int manualAttendanceId,
    required int restoredBy,
  }) async {
    final endpoint =
        '$_manualAttendance/restore/$manualAttendanceId?restoredBy=$restoredBy';
    return _traceManualAttendance(
        'PUT', endpoint, await putRequest(baseUrl1, endpoint, {}));
  }

  // ===========================================================================
  // EMPLOYEE (HRM)
  // ---------------------------------------------------------------------------
  // Front-end for hrm-service `/employee/*` — the same records the web keeps at
  // `employee/displayemployee` and `employee/addemployee`.
  //
  // An employee is NOT a user. `api/user/user/signUp` (see [signUp]) creates a
  // login; this creates the HR record — employment, position, pay, family,
  // documents. The employee row carries a userId when a login was asked for.
  //
  // Both writes are multipart, not JSON: the whole EmployeeSaveDto travels as a
  // JSON string in the `employeeSaveDto` part, with the identity documents
  // alongside it as `employeeDocuments` files.
  // ===========================================================================
  static const String _employee = 'api/hrm/employee';

  /// The employee list, paged and filtered.
  ///
  /// Every filter is optional and the backend reads an empty string as "any",
  /// so the defaults are passed through rather than omitted from the query —
  /// the same contract the web's `getall` call uses.
  static Future<http.Response> getEmployees({
    required int organizationId,
    int page = 0,
    int size = 15,
    String projectAssigned = '',
    String employeeRoleId = '',
    String reportingManager = '',
    String employeeId = '',
    String status = 'A',
    String firstName = '',
    String shiftId = '',
    String designation = '',
  }) async {
    return await getRequest(
        baseUrl1,
        '$_employee/getall?organizationId=$organizationId'
        '&page=$page&size=$size'
        '&projectAssigned=$projectAssigned&employeeRoleId=$employeeRoleId'
        '&reportingManager=$reportingManager'
        '&employeeId=${Uri.encodeQueryComponent(employeeId)}'
        '&status=$status'
        '&firstName=${Uri.encodeQueryComponent(firstName)}'
        '&shiftId=$shiftId'
        '&designation=${Uri.encodeQueryComponent(designation)}');
  }

  /// The whole record — employee, addresses, education, bank, family and
  /// experience — as one EmployeeSaveDto. This is what the edit form loads.
  ///
  /// Note the parameter is `employeeId` but takes the row's `id`, not the
  /// employee number. The backend names it that way; the web passes `employee.id`.
  static Future<http.Response> getEmployeeById(int id) async {
    return await getRequest(
        baseUrl1, '$_employee/getbyemployeeid?employeeId=$id');
  }

  /// Creates an employee.
  ///
  /// [employeeSaveDtoJson] is the encoded EmployeeSaveDto and [documents] the
  /// identity files, keyed by the filename to upload them under (see
  /// [_sendEmployee] for why the name matters). Documents are optional to the backend even though the web
  /// form marks Aadhaar required — that rule lives in the browser only.
  static Future<http.Response> submitEmployee(
    String employeeSaveDtoJson,
    Map<String, File> documents,
  ) async {
    return await _sendEmployee(
        'POST', '$_employee/submitEmployee', employeeSaveDtoJson, documents);
  }

  /// Updates an employee.
  ///
  /// The DTO REPLACES what is stored, so it has to carry every section — send
  /// it with an empty address or family list and that employee's addresses or
  /// family are gone. Always build this from a record loaded by
  /// [getEmployeeById], never from a blank form.
  static Future<http.Response> updateEmployee(
    String employeeSaveDtoJson,
    Map<String, File> documents,
  ) async {
    return await _sendEmployee(
        'PUT', '$_employee/update', employeeSaveDtoJson, documents);
  }

  /// The multipart body both employee writes share.
  ///
  /// The DTO goes in as a string field rather than as JSON: the endpoint takes
  /// it as `@RequestPart("employeeSaveDto") String` and parses it itself.
  ///
  /// THE FILENAME IS THE ROUTING. The backend decides which column a document
  /// belongs to from its original filename (`contains("Adhar")`, `"Pan"`, …),
  /// so each file is sent under the name the caller gives it — the web's
  /// `{docType}_{originalName}` — never the phone's own `IMG_1234.jpg`, which
  /// uploads to S3 but is linked to nothing.
  static Future<http.Response> _sendEmployee(
    String method,
    String endpoint,
    String employeeSaveDtoJson,
    Map<String, File> documents,
  ) async {
    await initialize();

    final request =
        http.MultipartRequest(method, Uri.parse('$baseUrl1$endpoint'));
    request.fields['employeeSaveDto'] = employeeSaveDtoJson;

    for (final entry in documents.entries) {
      if (!await entry.value.exists()) continue;
      request.files.add(
        await http.MultipartFile.fromPath('employeeDocuments', entry.value.path,
            filename: entry.key),
      );
    }

    if (accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    if (userId != null) {
      request.headers['proxyId'] = userId.toString();
      request.headers['userId'] = userId.toString();
    }

    final streamed = await request.send();
    return await http.Response.fromStream(streamed);
  }

  static Future<http.Response> deleteEmployee(int id) async {
    return await deleteRequest(baseUrl1, '$_employee/$id');
  }

  /// Email / phone uniqueness, as the web's Add Employee checks them on blur.
  /// The backend answers a duplicate with an error status, so any non-2xx
  /// response means "already exists".
  static Future<http.Response> checkEmailExists(String email) async {
    return await postRequest(
        baseUrl1, 'api/user/user/checkEmail', {'email': email});
  }

  static Future<http.Response> checkPhoneNumberExists(
      String phoneNumber) async {
    return await postRequest(baseUrl1, 'api/user/user/checkPhoneNumber',
        {'phoneNumber': phoneNumber});
  }

  /// The next free employee number, e.g. for an organisation with onboarding
  /// rules. The web treats a non-empty `employeeNumber` here as "onboarding
  /// rules are on" and pre-fills the number on a new employee.
  static Future<http.Response> getNextEmployeeNumber(int organizationId) async {
    return await getRequest(baseUrl1,
        '$_employee/nextEmployeeNumber?organizationId=$organizationId');
  }

  /// Working employees of the organisation — the web's Attendance Manager list.
  static Future<http.Response> getAttendanceManagers(int organizationId) async {
    return await getRequest(baseUrl1,
        '$_employee/getAllEmpoyees?orgId=$organizationId&employeeName=');
  }

  /// Attendance locations of one project — used instead of [fetchLocation]
  /// when onboarding rules are on and a project is chosen, as the web does.
  static Future<http.Response> fetchAttendanceLocationsByProject(
      int organizationId, int projectId) async {
    return await getRequest(baseUrl2,
        'api/facility-management/facility/getAllAttendanceLocation?orgId=$organizationId&projectId=$projectId');
  }

  /// Bulk-assigns reporting managers from an Excel sheet — the web's
  /// "Upload Managers" button. One multipart part, `file`.
  static Future<http.Response> uploadManagersExcel(File file) async {
    await initialize();

    final request = http.MultipartRequest(
        'POST', Uri.parse('$baseUrl1$_employee/upload-managers'));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    if (accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    if (userId != null) {
      request.headers['proxyId'] = userId.toString();
      request.headers['userId'] = userId.toString();
    }

    final streamed = await request.send();
    return await http.Response.fromStream(streamed);
  }

  // --- Employee child rows -------------------------------------------------
  //
  // Removing an education, family or experience row needs its own delete call.
  // The employee update is an UPSERT: it walks the lists it is given and
  // updates or inserts each row, but never removes one that is missing. So a
  // row dropped from the form and then saved would simply stay in the
  // database. The web deletes it the moment the row is removed, and so do we.

  static Future<http.Response> deleteEmployeeEducation(int id) async {
    return await deleteRequest(baseUrl1, 'api/hrm/employee-education/$id');
  }

  static Future<http.Response> deleteEmployeeFamily(int id) async {
    return await deleteRequest(baseUrl1, 'api/hrm/employee-family/$id');
  }

  static Future<http.Response> deleteEmployeeExperience(int id) async {
    return await deleteRequest(baseUrl1, 'api/hrm/employee-experience/$id');
  }

  /// The bytes of a stored employee document, for viewing — the web's
  /// `viewDocuments`. [filePath] is the S3 url saved on the record; the server
  /// fetches it, so the phone never needs bucket access. [fileType] only
  /// names the file in the response header.
  static Future<http.Response> downloadEmployeeDocument(
      String fileType, String filePath) async {
    return await getRequest(baseUrl3,
        'api/project/paymentdetails/download/$fileType?filePath=${Uri.encodeComponent(filePath)}&disposition=inline');
  }

  /// One reference row looked up by its key rather than by its type.
  ///
  /// Used for the form-status ids the save carries ('ews' when an employee is
  /// first submitted, 'esd' when a submitted one is sent on) — the web resolves
  /// these the same way rather than hard-coding the numbers.
  static Future<http.Response> getCommonReferenceByKey(String refKey) async {
    return await getRequest(
        baseUrl1, 'api/user/commonreferencedetails/mob?refKey=$refKey');
  }
}
