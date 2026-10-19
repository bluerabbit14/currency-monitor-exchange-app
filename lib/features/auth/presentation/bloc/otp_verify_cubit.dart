import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/contact_identifier.dart';
import '../../domain/entities/otp_code.dart';
import '../../domain/usecases/send_otp.dart';
import '../../domain/usecases/verify_google_link.dart';
import '../../domain/usecases/verify_otp.dart';

/// What the code screen is verifying. Adding phone OTP later is a new
/// [ContactIdentifier] subtype, not a new flow: [ContactOtpFlow] already
/// works with any contact the backend accepts.
sealed class OtpFlow extends Equatable {
  const OtpFlow();
}

/// Sign in / sign up with a code sent to [contact].
class ContactOtpFlow extends OtpFlow {
  const ContactOtpFlow(
    this.contact, {
    this.expiresInSeconds = 300,
    this.sendOnOpen = false,
  });

  final ContactIdentifier contact;
  final int expiresInSeconds;

  /// The code has not been requested yet: the code screen opens first and
  /// sends it in the background.
  final bool sendOnOpen;

  @override
  List<Object?> get props => [contact, expiresInSeconds, sendOnOpen];
}

/// Confirms ownership of an existing account before linking a Google identity.
/// There is no resend: the backend ties the code to [linkToken], so a new code
/// means starting Google sign-in again.
class GoogleLinkOtpFlow extends OtpFlow {
  const GoogleLinkOtpFlow({
    required this.linkToken,
    required this.maskedEmail,
    required this.expiresInSeconds,
  });

  final String linkToken;
  final String maskedEmail;
  final int expiresInSeconds;

  @override
  List<Object?> get props => [linkToken, maskedEmail, expiresInSeconds];
}

class OtpVerifyState extends Equatable {
  const OtpVerifyState({
    this.isVerifying = false,
    this.isResending = false,
    this.resendInSeconds = 0,
    this.error,
    this.resent = false,
  });

  final bool isVerifying;
  final bool isResending;
  final int resendInSeconds;
  final String? error;

  /// True briefly after a successful resend, for a confirmation message.
  final bool resent;

  bool get isBusy => isVerifying || isResending;

  OtpVerifyState copyWith({
    bool? isVerifying,
    bool? isResending,
    int? resendInSeconds,
    String? Function()? error,
    bool? resent,
  }) => OtpVerifyState(
    isVerifying: isVerifying ?? this.isVerifying,
    isResending: isResending ?? this.isResending,
    resendInSeconds: resendInSeconds ?? this.resendInSeconds,
    error: error != null ? error() : this.error,
    resent: resent ?? this.resent,
  );

  @override
  List<Object?> get props => [
    isVerifying,
    isResending,
    resendInSeconds,
    error,
    resent,
  ];
}

class OtpVerifyCubit extends Cubit<OtpVerifyState> {
  OtpVerifyCubit(
    this.flow,
    this._verifyOtp,
    this._verifyGoogleLink,
    this._sendOtp, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const OtpVerifyState()) {
    _expiresAt = _now().add(Duration(seconds: _initialExpirySeconds));
    final current = flow;
    if (current is ContactOtpFlow && current.sendOnOpen) {
      _send(current.contact, initial: true);
    } else if (canResend) {
      _startCooldown();
    }
  }

  /// Client-side throttle. The backend has no resend limit, and every resend
  /// sends an email.
  static const resendCooldownSeconds = 30;

  final OtpFlow flow;
  final VerifyOtp _verifyOtp;
  final VerifyGoogleLink _verifyGoogleLink;
  final SendOtp _sendOtp;
  final DateTime Function() _now;

  late DateTime _expiresAt;
  Timer? _timer;

  bool get canResend => flow is ContactOtpFlow;

  int get _initialExpirySeconds => switch (flow) {
    ContactOtpFlow(:final expiresInSeconds) => expiresInSeconds,
    GoogleLinkOtpFlow(:final expiresInSeconds) => expiresInSeconds,
  };

  /// Verification success is not a state: the repository stores the session
  /// and the app routes to the home screen.
  Future<void> submit(String code) async {
    if (state.isBusy) return;
    final otp = code.trim();
    if (!OtpCode.isValid(otp)) {
      emit(
        state.copyWith(
          error: () => 'Enter the ${OtpCode.length}-digit code',
          resent: false,
        ),
      );
      return;
    }
    if (!_now().isBefore(_expiresAt)) {
      emit(
        state.copyWith(
          error: () => canResend
              ? 'This code has expired. Request a new one'
              : 'This code has expired. Go back and sign in with Google again',
          resent: false,
        ),
      );
      return;
    }
    emit(state.copyWith(isVerifying: true, error: () => null, resent: false));
    final result = switch (flow) {
      ContactOtpFlow(:final contact) => await _verifyOtp(
        VerifyOtpParams(contact: contact, otp: otp),
      ),
      GoogleLinkOtpFlow(:final linkToken) => await _verifyGoogleLink(
        VerifyGoogleLinkParams(linkToken: linkToken, otp: otp),
      ),
    };
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(isVerifying: false, error: () => failure.message),
      ),
      (_) => emit(state.copyWith(isVerifying: false)),
    );
  }

  Future<void> resend() async {
    final current = flow;
    if (current is! ContactOtpFlow) return;
    if (state.isBusy || state.resendInSeconds > 0) return;
    await _send(current.contact, initial: false);
  }

  /// Requests a code. [initial] is the send that opened this screen, so it
  /// is not announced as "a new code".
  Future<void> _send(ContactIdentifier contact, {required bool initial}) async {
    emit(state.copyWith(isResending: true, error: () => null, resent: false));
    final result = await _sendOtp(contact);
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(isResending: false, error: () => failure.message),
      ),
      (challenge) {
        _expiresAt = _now().add(Duration(seconds: challenge.expiresInSeconds));
        emit(state.copyWith(isResending: false, resent: !initial));
        _startCooldown();
      },
    );
  }

  void clearError() {
    if (state.error != null || state.resent) {
      emit(state.copyWith(error: () => null, resent: false));
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    emit(state.copyWith(resendInSeconds: resendCooldownSeconds));
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = state.resendInSeconds - 1;
      if (left <= 0) timer.cancel();
      emit(state.copyWith(resendInSeconds: left < 0 ? 0 : left));
    });
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
