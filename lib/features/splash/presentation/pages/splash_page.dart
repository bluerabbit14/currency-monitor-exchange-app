import 'package:flutter/material.dart';

/// Brand colours taken from the app icon (assets/images/moneyEx.jpg).
const splashBackground = Color(0xFF001640);
const splashGold = Color(0xFFD8B266);

/// Shown while the stored session is being checked.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: splashBackground,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/moneyEx.jpg',
                width: 180,
                height: 180,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(height: 8),
              const Text(
                'MoneyEx',
                style: TextStyle(
                  color: splashGold,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
