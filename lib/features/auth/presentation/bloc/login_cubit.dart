import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../data/datasources/google_sign_in_data_source.dart';
import '../../domain/entities/contact_identifier.dart';
import '../../domain/entities/google_sign_in_outcome.dart';
import '../../domain/usecases/send_otp.dart';
import '../../domain/usecases/sign_in_with_google.dart';

enum LoginMethod { email, google }

sealed class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object?> get props => [];
}

class LoginIdle extends LoginState {
  const LoginIdle();
}

class LoginLoading extends LoginState {
  const LoginLoading(this.method);

  final LoginMethod method;

  @override
  List<Object?> get props => [method];
}

/// An OTP was emailed; the UI should open the code screen.
class LoginOtpSent extends LoginState {
  const LoginOtpSent(this.contact, this.expiresInSeconds);

  final ContactIdentifier contact;
  final int expiresInSeconds;

  @override
  List<Object?> get props => [contact, expiresInSeconds];
}

/// Google email already has an account; an OTP was emailed to it.
class LoginGoogleLinkRequired extends LoginState {
  const LoginGoogleLinkRequired(this.link);

  final GoogleLinkRequired link;

  @override
  List<Object?> get props => [link];
}

/// [isEmailFieldError] distinguishes inline validation from a request error
/// that is shown in a snack bar.
class LoginFailed extends LoginState {
  const LoginFailed(this.message, {this.isEmailFieldError = false});

  final String message;
  final bool isEmailFieldError;

  @override
  List<Object?> get props => [message, isEmailFieldError];
}

/// Drives the login screen. A successful sign-in is not a state here: the
/// session is stored by the repository and the app reacts to
/// `AuthSessionCubit`.
class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._sendOtp, this._signInWithGoogle) : super(const LoginIdle());

  final SendOtp _sendOtp;
  final SignInWithGoogle _signInWithGoogle;

  bool get _busy => state is LoginLoading;

  Future<void> continueWithEmail(String input) async {
    if (_busy) return; // ignore repeated taps
    if (input.trim().isEmpty) {
      emit(
        const LoginFailed('Enter your email address', isEmailFieldError: true),
      );
      return;
    }
    final contact = EmailContact.tryParse(input);
    if (contact == null) {
      emit(
        const LoginFailed(
          'Enter a valid email address',
          isEmailFieldError: true,
        ),
      );
      return;
    }
    emit(const LoginLoading(LoginMethod.email));
    final result = await _sendOtp(contact);
    if (isClosed) return;
    emit(
      result.fold(
        (failure) => LoginFailed(failure.message),
        (challenge) =>
            LoginOtpSent(challenge.contact, challenge.expiresInSeconds),
      ),
    );
  }

  Future<void> continueWithGoogle() async {
    if (_busy) return;
    emit(const LoginLoading(LoginMethod.google));
    final result = await _signInWithGoogle(const NoParams());
    if (isClosed) return;
    emit(
      result.fold(
        (failure) => failure is GoogleSignInCancelledFailure
            ? const LoginIdle()
            : LoginFailed(failure.message),
        (outcome) => switch (outcome) {
          // Session already stored; the app routes away from the login page.
          GoogleSignedIn() => const LoginIdle(),
          GoogleLinkRequired() => LoginGoogleLinkRequired(outcome),
        },
      ),
    );
  }
}
