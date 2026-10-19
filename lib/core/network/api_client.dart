import 'package:dio/dio.dart';

import '../constant/api_constants.dart';
import 'api_exception.dart';
import 'token_provider.dart';

/// Thin Dio wrapper that understands the backend's `ApiResponse` envelope:
///
///   success: { status: SUCCESS, statusCode, message, body: {...} }
///   failure: { status: ERROR, statusCode, error: { code, message,
///              details: [{ field, message }] } }
///
/// Throws [ApiException] / [NetworkException] so repositories can map them to
/// failures in one place.
class ApiClient {
  ApiClient(this._dio);

  /// Client for unauthenticated endpoints (auth itself).
  factory ApiClient.plain({Dio? dio}) => ApiClient(dio ?? Dio(_baseOptions()));

  /// Client for protected endpoints: adds the bearer token and retries once
  /// after a refresh when the backend answers 401.
  factory ApiClient.authenticated(TokenProvider tokens, {Dio? dio}) {
    final d = dio ?? Dio(_baseOptions());
    d.interceptors.add(_AuthInterceptor(d, tokens));
    return ApiClient(d);
  }

  final Dio _dio;

  static BaseOptions _baseOptions() => BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: ApiConstants.connectTimeout,
    receiveTimeout: ApiConstants.receiveTimeout,
    sendTimeout: ApiConstants.receiveTimeout,
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
    // Status codes are interpreted in [unwrap].
    validateStatus: (_) => true,
  );

  /// Returns the envelope `body` (null for an empty 2xx such as 204).
  Future<Map<String, dynamic>?> post(
    String path, {
    Map<String, dynamic>? data,
  }) => _send(() => _dio.post<dynamic>(path, data: data));

  /// Returns the envelope `body`.
  Future<Map<String, dynamic>?> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _send(() => _dio.get<dynamic>(path, queryParameters: query));

  /// Returns the envelope `body`.
  Future<Map<String, dynamic>?> put(
    String path, {
    Map<String, dynamic>? data,
  }) => _send(() => _dio.put<dynamic>(path, data: data));

  /// Returns the envelope `body`.
  Future<Map<String, dynamic>?> patch(
    String path, {
    Map<String, dynamic>? data,
  }) => _send(() => _dio.patch<dynamic>(path, data: data));

  /// For endpoints that answer 204 No Content.
  Future<void> delete(String path) async {
    await _send(() => _dio.delete<dynamic>(path));
  }

  /// For endpoints whose envelope `body` is a JSON array.
  Future<List<dynamic>> getList(String path) async {
    final response = await _request(() => _dio.get<dynamic>(path));
    final body = unwrapBody(response);
    if (body is List) return body;
    throw ApiException(
      statusCode: response.statusCode ?? 0,
      message: 'Unexpected response from server',
    );
  }

  Future<Map<String, dynamic>?> _send(
    Future<Response<dynamic>> Function() call,
  ) async => unwrap(await _request(call));

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  static Map<String, dynamic>? unwrap(Response<dynamic> response) {
    final body = unwrapBody(response);
    if (body == null) return null;
    if (body is Map) return body.cast<String, dynamic>();
    throw ApiException(
      statusCode: response.statusCode ?? 0,
      message: 'Unexpected response from server',
    );
  }

  /// Validates the status and returns the raw envelope `body` (a map, a list
  /// or null). Throws [ApiException] for error responses.
  static Object? unwrapBody(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    final raw = response.data;
    final envelope = raw is Map ? raw.cast<String, dynamic>() : null;

    if (status >= 200 && status < 300) {
      if (status == 204 || envelope == null) return null;
      return envelope['body'];
    }

    final error = envelope?['error'];
    final err = error is Map ? error.cast<String, dynamic>() : null;
    final fields = <String, String>{};
    final details = err?['details'];
    if (details is List) {
      for (final d in details) {
        if (d is Map && d['field'] is String && d['message'] is String) {
          fields[d['field'] as String] = d['message'] as String;
        }
      }
    }
    throw ApiException(
      statusCode: status,
      message:
          (err?['message'] as String?) ??
          (envelope?['message'] as String?) ??
          'Request failed ($status)',
      code: err?['code'] as String?,
      fieldErrors: fields,
    );
  }

  static NetworkException _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException('Request timed out');
      case DioExceptionType.cancel:
        return const NetworkException('Request cancelled');
      default:
        return NetworkException(e.message ?? 'Network error');
    }
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio, this._tokens);

  final Dio _dio;
  final TokenProvider _tokens;

  static const _retriedKey = 'auth_retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokens.accessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    // validateStatus accepts everything, so a 401 arrives here, not in onError.
    final options = response.requestOptions;
    if (response.statusCode == 401 && options.extra[_retriedKey] != true) {
      final fresh = await _tokens.refreshAccessToken();
      if (fresh != null) {
        options.extra[_retriedKey] = true;
        options.headers['Authorization'] = 'Bearer $fresh';
        try {
          return handler.resolve(await _dio.fetch<dynamic>(options));
        } on DioException catch (e) {
          return handler.reject(e);
        }
      }
    }
    handler.next(response);
  }
}
