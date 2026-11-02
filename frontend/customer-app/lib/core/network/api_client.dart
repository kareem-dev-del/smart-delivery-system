import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shopease_mobile/core/config/app_config.dart';
import 'package:shopease_mobile/core/network/api_error.dart';
import 'package:shopease_mobile/core/utils/token_storage.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
    required TokenStorage tokenStorage,
    this.onSessionExpired, // [جديد]
  }) : _httpClient = httpClient ?? http.Client(),
       _tokenStorage = tokenStorage;

  final String baseUrl;
  final Duration timeout;
  final http.Client _httpClient;
  final TokenStorage _tokenStorage;

  /// [جديد] بينادَى لما الـrefresh نفسه يفشل — يعني الجلسة خلصت فعلًا.
  /// اربطها بأي منطق logout + navigate to login في الـDI.
  final Future<void> Function()? onSessionExpired;

  // [جديد] عشان لو أكتر من request جالها 401 في نفس اللحظة، يشتركوا
  // في نفس محاولة الـrefresh بدل ما كل واحد يعمل refresh لوحده.
  Future<bool>? _refreshFuture;

  Future<T> get<T>(
    String path, {
    Map<String, String?> queryParameters = const {},
    T Function(dynamic data)? parser,
  }) {
    return _send<T>(
      'GET',
      path,
      queryParameters: queryParameters,
      parser: parser,
    );
  }

  Future<T> post<T>(
    String path, {
    Map<String, String?> queryParameters = const {},
    Object? body,
    T Function(dynamic data)? parser,
    // [جديد] — عشان لو الـcaller محتاج يبعت header زي Idempotency-Key
    // من غير ما نعمل method جديد أو نغيّر توقيع _send بالكامل
    Map<String, String> headers = const {},
  }) {
    return _send<T>(
      'POST',
      path,
      queryParameters: queryParameters,
      body: body,
      parser: parser,
      headers: headers,
    );
  }

  Future<T> put<T>(
    String path, {
    Map<String, String?> queryParameters = const {},
    Object? body,
    T Function(dynamic data)? parser,
  }) {
    return _send<T>(
      'PUT',
      path,
      queryParameters: queryParameters,
      body: body,
      parser: parser,
    );
  }

  Future<T> patch<T>(
    String path, {
    Map<String, String?> queryParameters = const {},
    Object? body,
    T Function(dynamic data)? parser,
  }) {
    return _send<T>(
      'PATCH',
      path,
      queryParameters: queryParameters,
      body: body,
      parser: parser,
    );
  }

  Future<T> delete<T>(
    String path, {
    Map<String, String?> queryParameters = const {},
    T Function(dynamic data)? parser,
  }) {
    return _send<T>(
      'DELETE',
      path,
      queryParameters: queryParameters,
      parser: parser,
    );
  }

  Future<T> uploadFile<T>(
    String path, {
    required String fieldName,
    required File file,
    T Function(dynamic data)? parser,
  }) async {
    final uri = _buildUri(path, const {});
    final request = http.MultipartRequest('POST', uri);

    final token = await _tokenStorage.readToken();
    if (token != null && token.isNotEmpty) {
      request.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        fieldName,
        file.path,
        // [جديد] — من غير ده، http.MultipartFile.fromPath() مبيحددش الـ
        // content-type من نفسه وبيبعت 'application/octet-stream' كـdefault،
        // فالسيرفر بيرفضها حتى لو الصورة JPG فعلاً وصح 100%
        contentType: _mediaTypeForPath(file.path),
      ),
    );

    final streamedResponse = await _httpClient.send(request).timeout(timeout);
    final response = await http.Response.fromStream(
      streamedResponse,
    ).timeout(timeout);

    if (response.statusCode < HttpStatus.ok ||
        response.statusCode >= HttpStatus.multipleChoices) {
      throw ApiException(
        statusCode: response.statusCode,
        message:
            _readErrorMessage(response.body) ??
            'Request failed with status ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (parser != null) return parser(decoded);
    return decoded as T;
  }

  Future<T> _send<T>(
    String method,
    String path, {
    Map<String, String?> queryParameters = const {},
    Object? body,
    T Function(dynamic data)? parser,
    bool isRetry = false, // [جديد]
    Map<String, String> headers = const {}, // [جديد]
  }) async {
    try {
      final uri = _buildUri(path, queryParameters);

      final request = http.Request(method, uri)
        ..headers[HttpHeaders.acceptHeader] = 'application/json';

      if (kDebugMode) {
        debugPrint('API request: $method ${uri.origin}${uri.path}');
      }

      final token = await _tokenStorage.readToken();
      final hadToken = token != null && token.isNotEmpty;
      if (hadToken) {
        request.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      }

      // [جديد] — extra headers زي Idempotency-Key. بعد الـauth header
      // القياسي عشان لو حد بعت override لـAuthorization غلط بالغلط
      // الافتراضي (token) هو اللي يفوز، مش أي حاجة جاية من الـcaller
      for (final entry in headers.entries) {
        if (entry.value.trim().isNotEmpty) {
          request.headers[entry.key] = entry.value;
        }
      }

      if (body != null) {
        request.headers[HttpHeaders.contentTypeHeader] = 'application/json';
        request.body = jsonEncode(body);
      }

      if (kDebugMode) {
        debugPrint(
          'API dispatch: ${request.method} ${uri.path} '
          'bodyBytes=${request.bodyBytes.length}',
        );
      }

      final http.StreamedResponse streamedResponse;
      try {
        streamedResponse = await _httpClient.send(request).timeout(timeout);
      } on TimeoutException catch (error) {
        if (kDebugMode) {
          debugPrint('API response timeout: ${request.method} ${uri.path}: $error');
        }
        rethrow;
      }
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(timeout);
      final rawBody = response.body;

      if (kDebugMode) {
        debugPrint('API response: $method ${uri.path} ${response.statusCode}');
      }

      // [تعديل] — لو الـ401 راجع لطلب أصلاً ماكانش معاه token (يعني اليوزر
      // مش عامل sign in أو عامل sign out بالفعل)، ده مش "انتهت الجلسة"،
      // ده مجرد endpoint محتاج تسجيل دخول. من غير الشرط ده، أي كول لـ
      // endpoint محمي بيحصل تلقائي وقت فتح التطبيق (زي restoreCart/
      // restoreWishlist/loadOrders في الـDI) كان بيرجع 401 لأي حد لسه
      // مسجلش دخول، وده كان بيمسح أي user متخزن ويرجّع المستخدم لصفحة
      // الـlogin بالقوة — حتى لو هو أصلاً مسجل دخول وصح، بس صادف إن ده
      // أول request بيتبعت قبل ما restoreSession() يخلص.
      if (response.statusCode == HttpStatus.unauthorized &&
          !isRetry &&
          !_isAuthenticationPath(path)) {
        if (!hadToken) {
          throw const ApiException(
            statusCode: HttpStatus.unauthorized,
            message: 'Please sign in to continue.',
          );
        }
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          return _send<T>(
            method,
            path,
            queryParameters: queryParameters,
            body: body,
            parser: parser,
            isRetry: true,
            headers: headers,
          );
        }
        await _handleSessionExpired();
        throw const ApiException(
          statusCode: HttpStatus.unauthorized,
          message: 'Your session has expired. Please sign in again.',
        );
      }

      if (response.statusCode < HttpStatus.ok ||
          response.statusCode >= HttpStatus.multipleChoices) {
        throw ApiException(
          statusCode: response.statusCode,
          message:
              _readErrorMessage(rawBody) ??
              'Request failed with status ${response.statusCode}.',
        );
      }

      if (rawBody.trim().isEmpty) {
        return null as T;
      }

      final decodedBody = jsonDecode(rawBody);

      if (parser != null) {
        return parser(decodedBody);
      }

      return decodedBody as T;
    } on ApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw ApiException(
        message: 'The server took too long to respond.',
        cause: error,
      );
    } on SocketException catch (error) {
      throw ApiException(
        message: 'Could not connect to the server.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        message: 'Could not complete the request to the server.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw ApiException(
        message: 'The server returned invalid data.',
        cause: error,
      );
    } on TypeError catch (error) {
      throw ApiException(
        message: 'The server returned data in an unexpected format.',
        cause: error,
      );
    }
  }

  // [جديد] — الـmutex بتاع الـrefresh
  Future<bool> _refreshAccessToken() {
    return _refreshFuture ??= _performRefresh().whenComplete(() {
      _refreshFuture = null;
    });
  }

  // [جديد] — نداء منفصل تمامًا لـ/auth/refresh (مش عن طريق _send عشان نتفادى infinite loop)
  Future<bool> _performRefresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final uri = _buildUri(AppConfig.refreshPath, const {});
      final request = http.Request('POST', uri)
        ..headers[HttpHeaders.acceptHeader] = 'application/json'
        ..headers[HttpHeaders.contentTypeHeader] = 'application/json'
        ..body = jsonEncode({'refresh': refreshToken});

      final streamedResponse = await _httpClient.send(request).timeout(timeout);
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(timeout);
      final rawBody = response.body;

      if (response.statusCode < HttpStatus.ok ||
          response.statusCode >= HttpStatus.multipleChoices) {
        return false;
      }
      if (rawBody.trim().isEmpty) return false;

      final decoded = jsonDecode(rawBody);
      if (decoded is! Map<String, dynamic>) return false;

      final newToken = decoded['access'];
      final newRefreshToken = decoded['refresh'];
      if (newToken is! String || newToken.isEmpty) return false;

      await _tokenStorage.saveTokens(
        token: newToken,
        refreshToken: newRefreshToken is String ? newRefreshToken : null,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isAuthenticationPath(String path) =>
      path == AppConfig.loginPath || path == AppConfig.registerPath;

  // [جديد]
  Future<void> _handleSessionExpired() async {
    await _tokenStorage.clearToken();
    if (onSessionExpired != null) {
      await onSessionExpired!();
    }
  }

  // [جديد] — بيحدد الـcontent-type الصح حسب امتداد الملف عشان الـfileFilter
  // بتاع multer في السيرفر (اللي بيتأكد إن الصورة jpeg/png/webp) يقبلها
  MediaType? _mediaTypeForPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      default:
        return null; // سيب http يحدد الافتراضي لو امتداد غريب
    }
  }

  Uri _buildUri(String path, Map<String, String?> queryParameters) {
    final trimmedBaseUrl =
        baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$trimmedBaseUrl$normalizedPath');

    final filteredQuery = <String, String>{
      ...uri.queryParameters,
      for (final entry in queryParameters.entries)
        if (entry.value != null && entry.value!.trim().isNotEmpty)
          entry.key: entry.value!.trim(),
    };

    return uri.replace(
      queryParameters: filteredQuery.isEmpty ? null : filteredQuery,
    );
  }

  String? _readErrorMessage(String rawBody) {
  if (rawBody.trim().isEmpty) return null;

  try {
    final decoded = jsonDecode(rawBody);
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail;

      String? fieldError(Map<String, dynamic> fields) {
        for (final entry in fields.entries) {
          final value = entry.value;

          if (value is List && value.isNotEmpty) {
            return '${entry.key}: ${value.first}';
          }
          if (value is String && value.trim().isNotEmpty) {
            return '${entry.key}: $value';
          }
        }
        return null;
      }

      final errors = decoded['errors'];
      if (errors is Map<String, dynamic>) {
        final error = fieldError(errors);
        if (error != null) return error;
      }

      final error = fieldError(decoded);
      if (error != null) return error;

      final message =
          decoded['message'] ?? decoded['error'] ?? decoded['title'];
      if (message != null && '$message'.trim().isNotEmpty) {
        return '$message';
      }
    }
  } on FormatException {
    return rawBody.trim();
  }

  return null;
}

  void close() {
    _httpClient.close();
  }
}
