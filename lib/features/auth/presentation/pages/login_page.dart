import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../bloc/login_cubit.dart';
import '../bloc/otp_verify_cubit.dart';
import '../widgets/auth_bottom_sheet.dart';
import 'otp_page.dart';

/// Login screen: email + OTP, or Google. Success is not handled here; the
/// session is stored and the app swaps this page for the home screen.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LoginCubit>(),
      child: BlocConsumer<LoginCubit, LoginState>(
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
        builder: (context, state) {
          final cubit = context.read<LoginCubit>();
          return Scaffold(
            backgroundColor: Colors.black,
            resizeToAvoidBottomInset: true,
            body: LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  const Expanded(child: _HeroSection()),
                  // The sheet scrolls internally if it ever needs more than this
                  // (large text, small screen, keyboard open) instead of
                  // overflowing the page.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * 0.85,
                    ),
                    child: AuthBottomSheet(
                      isContinueLoading:
                          state is LoginLoading &&
                          state.method == LoginMethod.email,
                      isGoogleLoading:
                          state is LoginLoading &&
                          state.method == LoginMethod.google,
                      emailError:
                          state is LoginFailed && state.isEmailFieldError
                          ? state.message
                          : null,
                      onContinue: cubit.continueWithEmail,
                      onGoogle: cubit.continueWithGoogle,
                      // The backend has no Apple sign-in yet, so this only
                      // explains that instead of pretending to sign in.
                      onApple: () => ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Sign in with Apple is not available yet',
                            ),
                          ),
                        ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
                  SizedBox(height: topGap),
                  if (showTitle)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'TRACK THE BEST RATE\nON EVERY EXCHANGE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFFF7E8),
                          ),
                        ),
                      ),
                    ),
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
