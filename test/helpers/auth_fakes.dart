import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:currency/core/error/failures.dart';
import 'package:currency/core/network/api_client.dart';
import 'package:currency/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:currency/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:currency/features/auth/data/datasources/google_sign_in_data_source.dart';
import 'package:currency/features/auth/domain/entities/auth_session.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

typedef RequestHandler = FutureOr<ResponseBody> Function(RequestOptions);

/// Plays the backend: every request goes through [handler].
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  RequestHandler handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  List<RequestOptions> to(String path) =>
      requests.where((r) => r.path == path).toList();
}

ResponseBody jsonBody(int status, Map<String, dynamic> json) =>
    ResponseBody.fromString(
      jsonEncode(json),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody noContent() => ResponseBody.fromString('', 204);

/// `{ status: SUCCESS, statusCode, message, body }` like the real backend.
ResponseBody ok(Map<String, dynamic> body, {int status = 200}) =>
    jsonBody(status, {
      'status': 'SUCCESS',
      'statusCode': status,
      'message': 'ok',
      'body': body,
      'meta': {'timestamp': '2026-01-01T00:00:00Z', 'path': '/x'},
    });

ResponseBody apiError(
  int status,
  String message, {
  String? code,
  List<Map<String, String>>? details,
}) => jsonBody(status, {
  'status': 'ERROR',
  'statusCode': status,
  'message': message,
  'error': {
    'code': code ?? 'ERROR',
    'title': 'Error',
    'message': message,
    'details': ?details,
  },
});

Map<String, dynamic> tokenBody({
  String access = 'access-1',
  String refresh = 'refresh-1',
  int expiresIn = 900,
  bool? newUser,
  String? baseCurrencyId = 'base-1',
}) => {
  'accessToken': access,
  'refreshToken': refresh,
  'tokenType': 'Bearer',
  'expiresInSeconds': expiresIn,
  'newUser': ?newUser,
  'baseCurrencyId': baseCurrencyId,
};

ApiClient clientFor(FakeAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://test',
      validateStatus: (_) => true,
      contentType: Headers.jsonContentType,
    ),
  )..httpClientAdapter = adapter;
  return ApiClient(dio);
}

AuthRemoteDataSource remoteFor(FakeAdapter adapter) =>
    AuthRemoteDataSource(clientFor(adapter));

class InMemoryAuthStorage implements AuthLocalDataSource {
  AuthSession? stored;
  int clears = 0;

  @override
  Future<AuthSession?> read() async => stored;

  @override
  Future<void> write(AuthSession session) async => stored = session;

  @override
  Future<void> clear() async {
    clears++;
    stored = null;
  }
}

class FakeGoogle implements GoogleSignInDataSource {
  Either<Failure, GoogleSignInResult> result = const Right(
    GoogleSignInResult('google-id-token'),
  );
  int signIns = 0;
  int signOuts = 0;

  @override
  Future<Either<Failure, GoogleSignInResult>> signIn() async {
    signIns++;
    return result;
  }

  @override
  Future<void> signOut() async => signOuts++;
}
