import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../currency/domain/usecases/preload_currencies.dart';
import '../bloc/login_cubit.dart';
import '../bloc/otp_verify_cubit.dart';
import '../widgets/animated_globe.dart';
import '../widgets/auth_bottom_sheet.dart';
import 'otp_page.dart';

/// Login screen: a hero and a "Get started" button that opens the sign-in
/// sheet (email + OTP, or Google). Success is not handled here; the session is
/// stored and the app swaps this page for the home screen.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
    // The currency list is needed right after sign-in; fetch it now, in the
    // background, so that screen opens with the data already cached.
    unawaited(sl<PreloadCurrencies>()());
  }

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
            case LoginOtpRequested(:final contact):
              OtpPage.open(context, ContactOtpFlow(contact, sendOnOpen: true));
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

  /// The sheet can be dismissed by dragging down, tapping outside or back.
  /// It also goes away when sign-in succeeds and the app swaps this page out.
  void _openSheet(BuildContext context) {
    final cubit = context.read<LoginCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      // Slower than the default (250ms) so the sheet glides in.
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 400),
        reverseDuration: Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      ),
      constraints: const BoxConstraints(maxWidth: double.infinity),
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // Its own Scaffold so snackbars show above the sheet, not behind it.
      builder: (_) => Scaffold(
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
          center: Alignment(0, -0.2),
          radius: 0.9,
          colors: [Color(0xFF16253F), Colors.black],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            // Pieces drop out when there is not enough room (small phones,
            // landscape) so nothing can overflow.
            final showTitle = height >= 260;
            final titleHeight = showTitle ? 96.0 : 0.0;
            final globeSize = math.min(
              constraints.maxWidth,
              height - titleHeight,
            );
            final showGlobe = globeSize >= 100;

            return ClipRect(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showGlobe) AnimatedGlobe(size: globeSize),
                  if (showTitle)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: SizedBox(
                        height: titleHeight - 8,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Convert Multiple Currencies\n and Set Price Alerts',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              height: 1.25,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFFF7E8),
                            ),
                          ),
                        ),
                      ),
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
