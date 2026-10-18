import 'package:flutter/material.dart';

import 'features/auth/presentation/pages/login_page.dart';
import 'features/shell/presentation/pages/home_shell_page.dart';

/// Decides the launch screen. Set to true to skip the login screen.
const bool isLoggedIn = false;

class CurrencyApp extends StatelessWidget {
  const CurrencyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Currency',
      home: isLoggedIn ? const HomeShellPage() : const LoginPage(),
    );
  }
}
