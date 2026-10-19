import '../entities/start_screen.dart';

abstract class StartScreenRepository {
  /// The saved start screen, or [StartScreen.defaultScreen] when none is saved
  /// or it cannot be read.
  Future<StartScreen> getStartScreen();

  Future<void> setStartScreen(StartScreen screen);
}
