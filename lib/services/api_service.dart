import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../exceptions/api_exception.dart';
import '../constants/constants.dart';

/// Service responsible for handling HTTP communication.
/// It centralizes authentication via Firebase ID Tokens, token refreshing, and error handling.
class ApiService {
  static const String _defaultBaseUrl = apiBaseUrl;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern for ApiService.
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Core method for making HTTP requests.
  Future<dynamic> request({
    required String path,
    required String method,
    Map<String, String>? headers,
    Object? body,
    bool isRetry = false,
    bool requireAuth = true,
  }) async {
    final bool isExternal = path.startsWith('http');
    final Uri url = isExternal ? Uri.parse(path) : Uri.parse('$_defaultBaseUrl$path');
    
    final bool shouldAddToken = requireAuth && !isExternal;

    String? token;
    if (shouldAddToken) {
      final user = _auth.currentUser;
      if (user == null) {
        await _signOutAndRedirect();
        throw UnauthorizedException('Authentication required.');
      }
      token = await user.getIdToken(isRetry);
      if (token == null) {
        await _signOutAndRedirect();
        throw UnauthorizedException('Could not authenticate with server.');
      }
    }

    final Map<String, String> requestHeaders = {
      if (body != null && body is! List<int> && body is! Uint8List) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };

    try {
      final response = await _sendRequest(method, url, requestHeaders, body)
          .timeout(const Duration(seconds: 30));

      return await _handleResponse(response, path, method, headers, body, isRetry, requireAuth);
    } on SocketException {
      throw NetworkException('Network error: Please check your internet connection.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(e.toString());
    }
  }

  Future<void> _signOutAndRedirect() async {
    await _auth.signOut();
  }

  void _showMessage(String message, {bool isError = true}) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<http.Response> _sendRequest(String method, Uri url, Map<String, String> headers, Object? body) async {
    Object? finalBody;
    final contentType = headers['Content-Type'] ?? headers['content-type'];
    
    if (body != null) {
      if (contentType == 'application/json' && (body is Map || body is List)) {
        finalBody = jsonEncode(body);
      } else {
        // For x-www-form-urlencoded or raw bytes, keep as is
        finalBody = body;
      }
    }

    switch (method.toUpperCase()) {
      case 'GET': return await http.get(url, headers: headers);
      case 'POST': return await http.post(url, headers: headers, body: finalBody);
      case 'PUT': return await http.put(url, headers: headers, body: finalBody);
      case 'PATCH': return await http.patch(url, headers: headers, body: finalBody);
      case 'DELETE': return await http.delete(url, headers: headers);
      default: throw ApiException('Method $method not supported.');
    }
  }

  Future<dynamic> _handleResponse(
    http.Response response,
    String path,
    String method,
    Map<String, String>? headers,
    Object? body,
    bool isRetry,
    bool requireAuth,
  ) async {
    final int statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (e) {
        return response.body;
      }
    }

    if (statusCode == 401 && requireAuth && !path.startsWith('http')) {
      if (!isRetry) {
        return await request(path: path, method: method, headers: headers, body: body, isRetry: true, requireAuth: requireAuth);
      } else {
        await _signOutAndRedirect();
        throw UnauthorizedException('Session expired. Please log in again.');
      }
    }

    if (statusCode == 403) {
      const msg = 'You do not have permission to access this resource.';
      _showMessage(msg);
      throw ForbiddenException(msg);
    }

    if (statusCode == 404) throw NotFoundException();
    if (statusCode == 429) throw RateLimitException();
    if (statusCode >= 500) throw ServerException();

    String errorMsg = 'Error $statusCode';
    try {
      final decoded = jsonDecode(response.body);
      errorMsg = decoded['message'] ?? decoded['error'] ?? errorMsg;
    } catch (_) {}
    throw ApiException(errorMsg, statusCode);
  }

  // Convenience methods
  Future<dynamic> get(String path, {Map<String, String>? headers, bool requireAuth = true}) =>
      request(path: path, method: 'GET', headers: headers, requireAuth: requireAuth);

  Future<dynamic> post(String path, {Map<String, String>? headers, Object? body, bool requireAuth = true}) =>
      request(path: path, method: 'POST', headers: headers, body: body, requireAuth: requireAuth);

  Future<dynamic> put(String path, {Map<String, String>? headers, Object? body, bool requireAuth = true}) =>
      request(path: path, method: 'PUT', headers: headers, body: body, requireAuth: requireAuth);

  Future<dynamic> delete(String path, {Map<String, String>? headers, bool requireAuth = true}) =>
      request(path: path, method: 'DELETE', headers: headers, requireAuth: requireAuth);
}
