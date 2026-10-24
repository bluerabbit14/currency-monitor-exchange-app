import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart';
import 'features/auth/presentation/bloc/auth_session_cubit.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/currency/presentation/pages/base_currency_page.dart';
import 'features/shell/presentation/pages/home_shell_page.dart';
import 'features/splash/presentation/pages/splash_page.dart';

class CurrencyApp extends StatefulWidget {
  const CurrencyApp({super.key, this.sessionCubit});

  /// Defaults to the registered app-wide cubit; tests pass their own.
  final AuthSessionCubit? sessionCubit;

  @override
  State<CurrencyApp> createState() => _CurrencyAppState();
}

class _CurrencyAppState extends State<CurrencyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.sessionCubit ?? sl<AuthSessionCubit>(),
      child: MaterialApp(
        title: 'MoneyEx',
        navigatorKey: _navigatorKey,
        // Signing in or out swaps `home`, but routes pushed on top of it (the
        // OTP screen, anything opened from Settings) would stay on screen.
        builder: (context, child) =>
            BlocListener<AuthSessionCubit, AuthSessionState>(
              listener: (_, _) => _navigatorKey.currentState?.popUntil(
                (route) => route.isFirst,
              ),
              child: child,
            ),
        home: BlocBuilder<AuthSessionCubit, AuthSessionState>(
          builder: (context, state) => switch (state) {
            AuthSessionUnknown() => const SplashPage(),
            // A just-created account must pick a base currency first.
            AuthSessionAuthenticated(needsBaseCurrency: true) =>
              const BaseCurrencyPage(),
            AuthSessionAuthenticated() => const HomeShellPage(),
            AuthSessionUnauthenticated() => const LoginPage(),
          },
        ),
      ),
    );
  }
}
