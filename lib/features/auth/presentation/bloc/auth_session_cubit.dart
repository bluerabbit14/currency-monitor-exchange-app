import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

sealed class AuthSessionState extends Equatable {
  const AuthSessionState();

  @override
  List<Object?> get props => [];
}

/// Launch: the stored session has not been checked yet.
class AuthSessionUnknown extends AuthSessionState {
  const AuthSessionUnknown();
}

class AuthSessionAuthenticated extends AuthSessionState {
  const AuthSessionAuthenticated();
}

class AuthSessionUnauthenticated extends AuthSessionState {
  const AuthSessionUnauthenticated();
}

/// App-wide "is the user signed in" state. It follows the repository's session
/// stream, so a sign-in, a logout, or the backend rejecting the refresh token
/// all route the app without anyone calling this cubit explicitly.
class AuthSessionCubit extends Cubit<AuthSessionState> {
  AuthSessionCubit(this._repository) : super(const AuthSessionUnknown());

  final AuthRepository _repository;
  StreamSubscription<AuthSession?>? _subscription;

  Future<void> start() async {
    _subscription ??= _repository.sessionChanges.listen(_onSession);
    final session = await _repository.restoreSession();
    if (isClosed) return;
    _onSession(session);
  }

  Future<void> logout() => _repository.logout();

  void _onSession(AuthSession? session) {
    if (isClosed) return;
    emit(
      session == null
          ? const AuthSessionUnauthenticated()
          : const AuthSessionAuthenticated(),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
