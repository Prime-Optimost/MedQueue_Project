import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:medqueue_frontend/utils/api_constants.dart';
import 'package:medqueue_frontend/utils/token_manager.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/api_response_model.dart';

/// HTTP API Client with automatic token refresh and error handling
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal();

  /// Perform a GET request with authentication
  static Future<ApiResponse<T>> getWithAuth<T>(
    String endpoint, {
    required T Function(Map<String, dynamic>) parser,
  }) async {
    return _performAuthenticatedRequest(
      method: 'GET',
      endpoint: endpoint,
      parser: parser,
    );
  }

  /// Perform a POST request with authentication
  static Future<ApiResponse<T>> postWithAuth<T>(
    String endpoint, {
    required Map<String, dynamic> body,
    required T Function(Map<String, dynamic>) parser,
  }) async {
    return _performAuthenticatedRequest(
      method: 'POST',
      endpoint: endpoint,
      body: body,
      parser: parser,
    );
  }

  /// Perform a PUT request with authentication
  static Future<ApiResponse<T>> putWithAuth<T>(
    String endpoint, {
    required Map<String, dynamic> body,
    required T Function(Map<String, dynamic>) parser,
  }) async {
    return _performAuthenticatedRequest(
      method: 'PUT',
      endpoint: endpoint,
      body: body,
      parser: parser,
    );
  }

  /// Perform a DELETE request with authentication
  static Future<ApiResponse<T>> deleteWithAuth<T>(
    String endpoint, {
    required T Function(Map<String, dynamic>) parser,
  }) async {
    return _performAuthenticatedRequest(
      method: 'DELETE',
      endpoint: endpoint,
      parser: parser,
    );
  }

  /// Perform a PATCH request with authentication
  static Future<ApiResponse<T>> patchWithAuth<T>(
    String endpoint, {
    required Map<String, dynamic> body,
    required T Function(Map<String, dynamic>) parser,
  }) async {
    return _performAuthenticatedRequest(
      method: 'PATCH',
      endpoint: endpoint,
      body: body,
      parser: parser,
    );
  }

  /// Perform a POST request without authentication
  static Future<ApiResponse<T>> post<T>(
    String endpoint, {
    required Map<String, dynamic> body,
    required T Function(Map<String, dynamic>) parser,
  }) async {
    return _performRequest(
      method: 'POST',
      endpoint: endpoint,
      body: body,
      parser: parser,
    );
  }

  /// Internal method to perform authenticated request with token refresh
  static Future<ApiResponse<T>> _performAuthenticatedRequest<T>({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    required T Function(Map<String, dynamic>) parser,
  }) async {
    String? accessToken = await TokenManager.getAccessToken();

    if (accessToken == null) {
      return ApiResponse(
        status: 'error',
        message: 'Not authenticated. Please log in.',
        errors: {'auth': 'No access token available'},
      );
    }

    // Check if token is expired
    if (await TokenManager.isAccessTokenExpired()) {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) {
        // Refresh failed, return auth error
        return ApiResponse(
          status: 'error',
          message: ApiConstants.sessionExpired,
          errors: {'auth': 'Token refresh failed'},
        );
      }
      accessToken = await TokenManager.getAccessToken();
    }

    // Perform the actual request
    final response = await _performRequest(
      method: method,
      endpoint: endpoint,
      body: body,
      parser: parser,
      authToken: accessToken,
    );

    // If 401, try to refresh token and retry once
    if (response.status == 'error' && 
        response.errors?['statusCode'] == 401) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        accessToken = await TokenManager.getAccessToken();
        return _performRequest(
          method: method,
          endpoint: endpoint,
          body: body,
          parser: parser,
          authToken: accessToken,
        );
      } else {
        // Refresh failed, user needs to log in again
        await TokenManager.clearAll();
        return ApiResponse(
          status: 'error',
          message: ApiConstants.sessionExpired,
          errors: {'auth': 'Session expired'},
        );
      }
    }

    return response;
  }

  /// Internal method to perform actual HTTP request
  static Future<ApiResponse<T>> _performRequest<T>({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    required T Function(Map<String, dynamic>) parser,
    String? authToken,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final headers = _buildHeaders(authToken: authToken);

      http.Response response;

      if (method == 'GET') {
        response = await http.get(uri, headers: headers)
            .timeout(ApiConstants.apiTimeout);
      } else if (method == 'POST') {
        response = await http.post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ).timeout(ApiConstants.apiTimeout);
      } else if (method == 'PUT') {
        response = await http.put(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ).timeout(ApiConstants.apiTimeout);
      } else if (method == 'PATCH') {
        response = await http.patch(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ).timeout(ApiConstants.apiTimeout);
      } else if (method == 'DELETE') {
        response = await http.delete(uri, headers: headers)
            .timeout(ApiConstants.apiTimeout);
      } else {
        throw Exception('Unsupported HTTP method: $method');
      }

      return _parseResponse(response, parser);
    } on SocketException {
      return ApiResponse(
        status: 'error',
        message: ApiConstants.networkError,
        errors: {'network': 'SocketException'},
      );
    } on TimeoutException {
      return ApiResponse(
        status: 'error',
        message: ApiConstants.timeoutError,
        errors: {'timeout': 'Request timeout'},
      );
    } catch (e) {
      return ApiResponse(
        status: 'error',
        message: '${ApiConstants.unexpectedError} ($e)',
        errors: {'exception': e.toString()},
      );
    }
  }

  /// Parse HTTP response into ApiResponse
  static ApiResponse<T> _parseResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>) parser,
  ) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // Check if it's already in the standard envelope format
      if (json.containsKey('status') && json.containsKey('message')) {
        return ApiResponse.fromJson(json, (data) => parser(data));
      }

      // Handle non-envelope responses (like token refresh)
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(
          status: 'success',
          message: 'Success',
          data: parser(json),
        );
      } else {
        return ApiResponse(
          status: 'error',
          message: 'Error: ${response.statusCode}',
          errors: {
            'statusCode': response.statusCode,
            'body': json,
          },
        );
      }
    } catch (e) {
      return ApiResponse(
        status: 'error',
        message: 'Failed to parse response: $e',
        errors: {
          'parseError': e.toString(),
          'statusCode': response.statusCode,
        },
      );
    }
  }

  /// Refresh access token using refresh token
  static Future<bool> _refreshAccessToken() async {
    try {
      final refreshToken = await TokenManager.getRefreshToken();
      if (refreshToken == null) return false;

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.refreshTokenEndpoint}');
      final headers = _buildHeaders();

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({'refresh': refreshToken}),
      ).timeout(ApiConstants.apiTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Extract new tokens from response
        String? newAccess;
        String? newRefresh;

        if (json.containsKey('data')) {
          final data = json['data'] as Map<String, dynamic>;
          newAccess = data['access'] as String?;
          newRefresh = data['refresh'] as String?;
        } else {
          // Fallback if response format is different
          newAccess = json['access'] as String?;
          newRefresh = json['refresh'] as String?;
        }

        if (newAccess != null && newRefresh != null) {
          await TokenManager.saveTokens(newAccess, newRefresh);
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Build HTTP headers with optional authentication
  static Map<String, String> _buildHeaders({String? authToken}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    return headers;
  }

  /// Perform a PATCH request with file upload (multipart/form-data) with authentication
  static Future<ApiResponse<T>> patchWithFileAuth<T>(
    String endpoint, {
    required Map<String, String> fields,
    required String fileFieldName,
    required Uint8List fileBytes,
    required String fileFilename,
    required T Function(Map<String, dynamic>) parser,
  }) async {
    String? accessToken = await TokenManager.getAccessToken();

    if (accessToken == null) {
      return ApiResponse(
        status: 'error',
        message: 'Not authenticated. Please log in.',
        errors: {'auth': 'No access token available'},
      );
    }

    // Check if token is expired
    if (await TokenManager.isAccessTokenExpired()) {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) {
        return ApiResponse(
          status: 'error',
          message: ApiConstants.sessionExpired,
          errors: {'auth': 'Token refresh failed'},
        );
      }
      accessToken = await TokenManager.getAccessToken();
    }

    // Perform the actual request
    final response = await _performMultipartRequest(
      method: 'PATCH',
      endpoint: endpoint,
      fields: fields,
      fileFieldName: fileFieldName,
      fileBytes: fileBytes,
      fileFilename: fileFilename,
      parser: parser,
      authToken: accessToken,
    );

    // If 401, try to refresh token and retry once
    if (response.status == 'error' && 
        response.errors?['statusCode'] == 401) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        accessToken = await TokenManager.getAccessToken();
        return _performMultipartRequest(
          method: 'PATCH',
          endpoint: endpoint,
          fields: fields,
          fileFieldName: fileFieldName,
          fileBytes: fileBytes,
          fileFilename: fileFilename,
          parser: parser,
          authToken: accessToken,
        );
      } else {
        await TokenManager.clearAll();
        return ApiResponse(
          status: 'error',
          message: ApiConstants.sessionExpired,
          errors: {'auth': 'Session expired'},
        );
      }
    }

    return response;
  }

  /// Perform a POST request with file upload (multipart/form-data) without authentication
  static Future<ApiResponse<T>> postWithFile<T>(
    String endpoint, {
    required Map<String, String> fields,
    required String fileFieldName,
    required Uint8List fileBytes,
    required String fileFilename,
    required T Function(Map<String, dynamic>) parser,
  }) async {
    return _performMultipartRequest(
      method: 'POST',
      endpoint: endpoint,
      fields: fields,
      fileFieldName: fileFieldName,
      fileBytes: fileBytes,
      fileFilename: fileFilename,
      parser: parser,
    );
  }

  /// Internal method to perform multipart/form-data request
  static Future<ApiResponse<T>> _performMultipartRequest<T>({
    required String method,
    required String endpoint,
    required Map<String, String> fields,
    required String fileFieldName,
    required Uint8List fileBytes,
    required String fileFilename,
    required T Function(Map<String, dynamic>) parser,
    String? authToken,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final request = http.MultipartRequest(method, uri);

      // Add authentication header if token provided
      if (authToken != null) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }

      // Add text fields
      for (final entry in fields.entries) {
        request.fields[entry.key] = entry.value;
      }

      // Add file (from bytes so it works on web where dart:io is unavailable)
      final file = http.MultipartFile.fromBytes(
        fileFieldName,
        fileBytes,
        filename: fileFilename,
        contentType: _mediaTypeFor(fileFilename),
      );
      request.files.add(file);

      // Send request
      final streamedResponse = await request.send()
          .timeout(ApiConstants.apiTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _parseResponse(response, parser);
    } on SocketException {
      return ApiResponse(
        status: 'error',
        message: ApiConstants.networkError,
        errors: {'network': 'SocketException'},
      );
    } on TimeoutException {
      return ApiResponse(
        status: 'error',
        message: ApiConstants.timeoutError,
        errors: {'timeout': 'Request timeout'},
      );
    } catch (e) {
      return ApiResponse(
        status: 'error',
        message: '${ApiConstants.unexpectedError} ($e)',
        errors: {'exception': e.toString()},
      );
    }
  }

  /// Infer a media type for an uploaded file from its filename extension.
  static MediaType _mediaTypeFor(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'bmp':
        return MediaType('image', 'bmp');
      case 'heic':
      case 'heif':
        return MediaType('image', 'heic');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      default:
        return MediaType('application', 'octet-stream');
    }
  }
}

// Exceptions
class SocketException implements Exception {
  final String message;
  SocketException(this.message);

  @override
  String toString() => 'SocketException: $message';
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
