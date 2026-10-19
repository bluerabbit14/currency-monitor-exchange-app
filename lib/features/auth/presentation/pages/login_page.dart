import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../bloc/login_cubit.dart';
import '../bloc/otp_verify_cubit.dart';
import '../widgets/auth_bottom_sheet.dart';
import 'otp_page.dart';

/// Login screen: a hero and a "Get started" button that opens the sign-in
/// sheet (email + OTP, or Google). Success is not handled here; the session is
/// stored and the app swaps this page for the home screen.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LoginCubit>(),
      child: BlocListener<LoginCubit, LoginState>(
        listener: (context, state) {
          switch (state) {
            case LoginFailed(isEmailFieldError: false, :final message):
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(message)));
            case LoginOtpSent(:final contact, :final expiresInSeconds):
              OtpPage.open(
                context,
                ContactOtpFlow(contact, expiresInSeconds: expiresInSeconds),
              );
            case LoginGoogleLinkRequired(:final link):
              OtpPage.open(
                context,
                GoogleLinkOtpFlow(
                  linkToken: link.linkToken,
                  maskedEmail: link.maskedEmail,
                  expiresInSeconds: link.expiresInSeconds,
                ),
              );
            default:
              break;
          }
        },
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            // No inputs here; the sheet has its own Scaffold for the keyboard.
            resizeToAvoidBottomInset: false,
            body: Column(
              children: [
                const Expanded(child: _HeroSection()),
                _GetStartedButton(onPressed: () => _openSheet(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The sheet cannot be dismissed: no tap outside, no drag, no back button.
  /// It goes away when sign-in succeeds and the app swaps this page out.
  void _openSheet(BuildContext context) {
    final cubit = context.read<LoginCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PopScope(
        canPop: false,
        // Its own Scaffold so snackbars show above the sheet, not behind it.
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: BlocBuilder<LoginCubit, LoginState>(
              bloc: cubit,
              builder: (context, state) => _sheet(context, cubit, state),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheet(BuildContext context, LoginCubit cubit, LoginState state) {
    return AuthBottomSheet(
      isContinueLoading:
          state is LoginLoading && state.method == LoginMethod.email,
      isGoogleLoading:
          state is LoginLoading && state.method == LoginMethod.google,
      emailError: state is LoginFailed && state.isEmailFieldError
          ? state.message
          : null,
      onContinue: cubit.continueWithEmail,
      onGoogle: cubit.continueWithGoogle,
      // The backend has no Apple sign-in yet, so this only explains that
      // instead of pretending to sign in.
      onApple: () => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Sign in with Apple is not available yet'),
          ),
        ),
    );
  }
}

class _GetStartedButton extends StatelessWidget {
  const _GetStartedButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF0505F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Get started',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, 0.35),
          radius: 0.9,
          colors: [Color(0xFF16253F), Colors.black],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            // Everything is sized from the space actually available, and
            // pieces drop out entirely when there is not enough room (small
            // phones, keyboard open) so nothing can overflow.
            final topGap = (height * 0.1).clamp(12.0, 80.0);
            final showTitle = height >= 150;
            final titleHeight = showTitle ? 80.0 : 0.0;
            final badgeSpace = height - topGap - titleHeight - 16;
            final badgeSize = badgeSpace.clamp(0.0, 190.0) * 0.9;
            final showBadge = badgeSize >= 80;

            return ClipRect(
              child: Column(
                children: [
                  if (showBadge)
                    Expanded(
                      child: Center(child: _CoinBadge(size: badgeSize)),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CoinBadge extends StatelessWidget {
  const _CoinBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6FA2E0), Color(0xFF2A4F8F)],
        ),
        border: Border.all(color: const Color(0xFF9CC2F0), width: 4),
        boxShadow: const [
          BoxShadow(color: Color(0x663B82F6), blurRadius: 50, spreadRadius: 4),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.currency_exchange_rounded,
        size: size * 0.5,
        color: Color(0xFFFBEBD3),
      ),
    );
  }
}
