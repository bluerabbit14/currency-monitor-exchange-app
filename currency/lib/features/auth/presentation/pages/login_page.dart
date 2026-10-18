import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../bloc/google_sign_in_cubit.dart';
import '../widgets/auth_bottom_sheet.dart';

/// Login screen. Phone/OTP is UI-only; Google sign-in only obtains an ID token
/// (backend verification is not implemented yet, so nobody is logged in).
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<GoogleSignInCubit>(),
      child: BlocConsumer<GoogleSignInCubit, GoogleSignInState>(
        listener: (context, state) {
          if (state is GoogleSignInError) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message)));
          }
          // GoogleSignInTokenReceived: hand the ID token to the backend once
          // that endpoint exists. Do not treat it as a completed login.
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Column(
              children: [
                const Expanded(child: _HeroSection()),
                AuthBottomSheet(
                  isGoogleLoading: state is GoogleSignInLoading,
                  onGoogle: () => context.read<GoogleSignInCubit>().signIn(),
                ),
              ],
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
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 80),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
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
                const Expanded(child: Center(child: _CoinBadge())),
                const _PageDots(),
                const SizedBox(height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoinBadge extends StatelessWidget {
  const _CoinBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      height: 190,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6FA2E0), Color(0xFF2A4F8F)],
        ),
        border: Border.all(color: const Color(0xFF9CC2F0), width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x663B82F6),
            blurRadius: 50,
            spreadRadius: 4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.currency_exchange_rounded,
        size: 96,
        color: Color(0xFFFBEBD3),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final active = i == 1;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 26 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white38,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
