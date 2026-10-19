import '../../domain/entities/start_screen.dart';
import '../../domain/repositories/start_screen_repository.dart';
import '../datasources/start_screen_local_data_source.dart';

class StartScreenRepositoryImpl implements StartScreenRepository {
  const StartScreenRepositoryImpl(this.local);

  final StartScreenLocalDataSource local;

  @override
  Future<StartScreen> getStartScreen() async {
    try {
      return StartScreen.fromName(await local.read());
    } catch (_) {
      // Storage unavailable: open on the default rather than fail to start.
      return StartScreen.defaultScreen;
    }
  }

  @override
  Future<void> setStartScreen(StartScreen screen) => local.write(screen.name);
}
