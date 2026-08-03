import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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

  // --- Messaging Methods ---

  Future<List<Map<String, dynamic>>> fetchMessageThreads({int page = 1, int limit = 20}) async {
    try {
      final response = await get('/admin/messages/users?page=$page&limit=$limit');
      if (response != null && response['success'] == true) {
        return List<Map<String, dynamic>>.from(response['threads'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('ApiService fetchMessageThreads Error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserMessages(String userId) async {
    try {
      final response = await get('/messages/$userId');
      if (response != null && response['success'] == true) {
        return List<Map<String, dynamic>>.from(response['messages'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('ApiService fetchUserMessages Error: $e');
      return [];
    }
  }

  /// Helper to resolve relative API URLs (e.g. /images/...) to full absolute URLs
  static String resolveUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    const String baseUrl = 'https://my-api.sayadulmorsalin123.workers.dev';
    if (path.startsWith('/')) {
      return '$baseUrl$path';
    }
    return '$baseUrl/$path';
  }

  /// Upload multiple files (images or documents) to the Cloudflare Worker R2 endpoint
  Future<List<String>> uploadMultipartFiles(List<File> files, {String folder = 'chat'}) async {
    if (files.isEmpty) return [];
    try {
      final user = _auth.currentUser;
      final token = await user?.getIdToken();

      final uri = Uri.parse('$_defaultBaseUrl/images/upload');
      final request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['folder'] = folder;

      for (final file in files) {
        final stream = http.ByteStream(file.openRead());
        final length = await file.length();
        final filename = file.path.split('/').last;

        final multipartFile = http.MultipartFile(
          'files',
          stream,
          length,
          filename: filename,
        );
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          final List uploadedFiles = decoded['files'] ?? [];
          final List<String> urls = [];
          for (final f in uploadedFiles) {
            final String? relUrl = f['imageUrl'] ?? f['key'];
            if (relUrl != null && relUrl.isNotEmpty) {
              urls.add(resolveUrl(relUrl));
            }
          }
          if (urls.isEmpty && decoded['imageUrl'] != null) {
            urls.add(resolveUrl(decoded['imageUrl']));
          }
          return urls;
        }
      }
      return [];
    } catch (e) {
      debugPrint('ApiService uploadMultipartFiles Error: $e');
      return [];
    }
  }

  /// Upload a voice note file to the Cloudflare Worker R2 endpoint
  Future<String?> uploadVoiceNote(File voiceNoteFile) async {
    try {
      final user = _auth.currentUser;
      final token = await user?.getIdToken();

      final uri = Uri.parse('$_defaultBaseUrl/images/upload');
      final request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['folder'] = 'voice-notes';

      final stream = http.ByteStream(voiceNoteFile.openRead());
      final length = await voiceNoteFile.length();
      final filename = voiceNoteFile.path.split('/').last.split('\\').last;

      final multipartFile = http.MultipartFile(
        'voiceNote',
        stream,
        length,
        filename: filename,
        contentType: MediaType('audio', 'm4a'),
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          final String? relUrl = decoded['imageUrl'] ?? decoded['key'] ?? (decoded['files'] != null && decoded['files'].isNotEmpty ? decoded['files'][0]['imageUrl'] : null);
          if (relUrl != null && relUrl.isNotEmpty) {
            return resolveUrl(relUrl);
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('ApiService uploadVoiceNote Error: $e');
      return null;
    }
  }

  Future<bool> sendReply(String userId, String message, {
    String? imageUrl,
    String? voiceNoteUrl,
    String? replyToId,
    String? replyToText,
    String? replyToSenderRole,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'userId': userId,
        'message': message,
      };
      if (imageUrl != null) body['imageUrl'] = imageUrl;
      if (voiceNoteUrl != null) body['voiceNoteUrl'] = voiceNoteUrl;
      if (replyToId != null) body['replyToId'] = replyToId;
      if (replyToText != null) body['replyToText'] = replyToText;
      if (replyToSenderRole != null) body['replyToSenderRole'] = replyToSenderRole;

      final response = await post('/messages', body: body);
      return response != null && response['success'] == true;
    } catch (e) {
      debugPrint('ApiService sendReply Error: $e');
      return false;
    }
  }

  Future<bool> toggleBlockUser(String userId, bool block) async {
    try {
      final response = await post('/admin/users/block', body: {
        'userId': userId,
        'block': block,
      });
      return response != null && response['success'] == true;
    } catch (e) {
      debugPrint('ApiService toggleBlockUser Error: $e');
      return false;
    }
  }

  // --- Admin Review Methods ---

  Future<List<Map<String, dynamic>>> fetchAllReviews() async {
    try {
      final response = await get('/admin/reviews');
      if (response != null && response['success'] == true) {
        return List<Map<String, dynamic>>.from(response['reviews'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('ApiService fetchAllReviews Error: $e');
      return [];
    }
  }

  Future<bool> deleteReview(String reviewId) async {
    try {
      final response = await delete('/admin/reviews/$reviewId');
      return response != null && response['success'] == true;
    } catch (e) {
      debugPrint('ApiService deleteReview Error: $e');
      return false;
    }
  }
}
