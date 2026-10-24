import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'features/auth/presentation/bloc/auth_session_cubit.dart';
import 'features/settings/presentation/bloc/start_screen_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Push is optional: without Firebase the app still runs, just without it.
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  await init();
  // The home shell opens on the saved start screen, so read it first.
  await sl<StartScreenCubit>().load();
  // Checks the stored session; the app shows a splash until it resolves.
  unawaited(sl<AuthSessionCubit>().start());
  runApp(const CurrencyApp());
}
