import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';

/// Exception thrown when a backend API request fails.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Centralized HTTP client for communicating with the FastAPI backend.
/// Automatically injects Firebase Auth Bearer tokens into headers.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  String get _baseUrl => AppConfig.backendBaseUrl;

  Future<Map<String, String>> _getHeaders({Map<String, String>? extraHeaders}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final urlStr = '$_baseUrl$cleanPath';
    final uri = Uri.parse(urlStr);
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(
        queryParameters: queryParams.map(
          (key, value) => MapEntry(key, value.toString()),
        ),
      );
    }
    return uri;
  }

  dynamic _handleResponse(http.Response response) {
    dynamic responseData;
    try {
      if (response.body.isNotEmpty) {
        responseData = jsonDecode(response.body);
      }
    } catch (_) {
      responseData = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseData;
    }

    String errorDetail = 'Request failed with status ${response.statusCode}';
    if (responseData is Map && responseData.containsKey('detail')) {
      final detail = responseData['detail'];
      if (detail is String) {
        errorDetail = detail;
      } else if (detail is List) {
        errorDetail = detail.map((e) => e.toString()).join(', ');
      } else {
        errorDetail = detail.toString();
      }
    }

    throw ApiException(response.statusCode, errorDetail);
  }

  /// Performs a GET request
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams, Map<String, String>? headers}) async {
    final uri = _buildUri(path, queryParams);
    final reqHeaders = await _getHeaders(extraHeaders: headers);
    final response = await http.get(uri, headers: reqHeaders);
    return _handleResponse(response);
  }

  /// Performs a POST request
  Future<dynamic> post(String path, {dynamic body, Map<String, String>? headers}) async {
    Object? traceException;
    try {
      final uri = _buildUri(path);
      final reqHeaders = await _getHeaders(extraHeaders: headers);
      final encodedBody = body != null ? jsonEncode(body) : null;
      final response = await http.post(uri, headers: reqHeaders, body: encodedBody);
      return _handleResponse(response);
    } catch (e) {
      traceException = e;
      rethrow;
    } finally {
      debugPrint(
        'STEP 3\n'
        'Executed: YES\n'
        'Timestamp: ${DateTime.now().toUtc().toIso8601String()}\n'
        'Exception: ${traceException == null ? 'None' : '${traceException.runtimeType}: $traceException'}',
      );
    }
  }

  /// Performs a PATCH request
  Future<dynamic> patch(String path, {dynamic body, Map<String, String>? headers}) async {
    final uri = _buildUri(path);
    final reqHeaders = await _getHeaders(extraHeaders: headers);
    final encodedBody = body != null ? jsonEncode(body) : null;
    final response = await http.patch(uri, headers: reqHeaders, body: encodedBody);
    return _handleResponse(response);
  }

  /// Performs a PUT request
  Future<dynamic> put(String path, {dynamic body, Map<String, String>? headers}) async {
    final uri = _buildUri(path);
    final reqHeaders = await _getHeaders(extraHeaders: headers);
    final encodedBody = body != null ? jsonEncode(body) : null;
    final response = await http.put(uri, headers: reqHeaders, body: encodedBody);
    return _handleResponse(response);
  }

  /// Performs a DELETE request
  Future<dynamic> delete(String path, {dynamic body, Map<String, String>? headers}) async {
    final uri = _buildUri(path);
    final reqHeaders = await _getHeaders(extraHeaders: headers);
    final encodedBody = body != null ? jsonEncode(body) : null;
    final response = await http.delete(uri, headers: reqHeaders, body: encodedBody);
    return _handleResponse(response);
  }
}
