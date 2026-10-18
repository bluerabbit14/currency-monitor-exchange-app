import 'dart:async';

import 'package:currency/core/error/failures.dart';
import 'package:currency/features/auth/data/datasources/google_sign_in_data_source.dart';
import 'package:currency/features/auth/presentation/bloc/google_sign_in_cubit.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDataSource implements GoogleSignInDataSource {
  _FakeDataSource(this.completer);

  final Completer<Either<Failure, GoogleSignInResult>> completer;
  int calls = 0;

  @override
  Future<Either<Failure, GoogleSignInResult>> signIn() {
    calls++;
    return completer.future;
  }
}

void main() {
  test('ignores repeated taps while loading and emits the token', () async {
    final completer = Completer<Either<Failure, GoogleSignInResult>>();
    final source = _FakeDataSource(completer);
    final cubit = GoogleSignInCubit(source);

    final first = cubit.signIn();
    await cubit.signIn();
    expect(cubit.state, const GoogleSignInLoading());

    completer.complete(const Right(GoogleSignInResult('token')));
    await first;

    expect(source.calls, 1);
    expect(cubit.state, const GoogleSignInTokenReceived('token'));
  });

  test('cancellation returns to idle, errors surface a message', () async {
    final cancelled = GoogleSignInCubit(
      _FakeDataSource(
        Completer()..complete(const Left(GoogleSignInCancelledFailure())),
      ),
    );
    await cancelled.signIn();
    expect(cancelled.state, const GoogleSignInIdle());

    final failed = GoogleSignInCubit(
      _FakeDataSource(Completer()..complete(const Left(AuthFailure('boom')))),
    );
    await failed.signIn();
    expect(failed.state, const GoogleSignInError('boom'));
  });
}
