import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/start_screen.dart';
import '../../domain/repositories/start_screen_repository.dart';

/// The app-wide start screen. Loaded once before the app starts, so the home
/// shell already knows which tab to open on.
class StartScreenCubit extends Cubit<StartScreen> {
  StartScreenCubit(this._repository) : super(StartScreen.defaultScreen);

  final StartScreenRepository _repository;

  Future<void> load() async {
    final saved = await _repository.getStartScreen();
    if (!isClosed) emit(saved);
  }

  /// Applies the choice at once and saves it. A failed save only means the
  /// choice is forgotten on the next launch.
  Future<void> select(StartScreen screen) async {
    if (screen == state) return;
    emit(screen);
    try {
      await _repository.setStartScreen(screen);
    } catch (_) {
      // Keep the in-memory choice for this session.
    }
  }
}
