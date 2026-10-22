import 'package:get_it/get_it.dart';

import '../../features/alerts/data/datasources/alert_remote_data_source.dart';
import '../../features/alerts/data/repositories/alert_repository_impl.dart';
import '../../features/alerts/domain/repositories/alert_repository.dart';
import '../../features/alerts/domain/usecases/alert_usecases.dart';
import '../../features/alerts/presentation/bloc/alerts_cubit.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/datasources/google_sign_in_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/token_manager.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/send_otp.dart';
import '../../features/auth/domain/usecases/sign_in_with_google.dart';
import '../../features/auth/domain/usecases/verify_google_link.dart';
import '../../features/auth/domain/usecases/verify_otp.dart';
import '../../features/auth/presentation/bloc/auth_session_cubit.dart';
import '../../features/auth/presentation/bloc/login_cubit.dart';
import '../../features/auth/presentation/bloc/otp_verify_cubit.dart';
import '../../features/converter/data/datasources/converter_local_data_source.dart';
import '../../features/converter/data/repositories/converter_repository_impl.dart';
import '../../features/converter/domain/repositories/converter_repository.dart';
import '../../features/converter/domain/usecases/convert_currency.dart';
import '../../features/converter/presentation/bloc/converter_bloc.dart';
import '../../features/currency/data/datasources/currency_remote_data_source.dart';
import '../../features/currency/data/repositories/currency_repository_impl.dart';
import '../../features/currency/domain/repositories/currency_repository.dart';
import '../../features/currency/domain/usecases/get_currencies.dart';
import '../../features/currency/domain/usecases/preload_currencies.dart';
import '../../features/currency/domain/usecases/set_base_currency.dart';
import '../../features/currency/presentation/bloc/base_currency_cubit.dart';
import '../../features/browse/presentation/bloc/browse_cubit.dart';
import '../../features/favourite/data/datasources/favorite_remote_data_source.dart';
import '../../features/favourite/data/repositories/favorite_repository_impl.dart';
import '../../features/favourite/domain/repositories/favorite_repository.dart';
import '../../features/favourite/domain/usecases/favorite_usecases.dart';
import '../../features/favourite/presentation/bloc/asset_picker_cubit.dart';
import '../../features/favourite/presentation/bloc/favorites_cubit.dart';
import '../../features/notifications/data/datasources/notification_remote_data_source.dart';
import '../../features/notifications/data/repositories/notification_repository_impl.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/notifications/domain/usecases/notification_usecases.dart';
import '../../features/notifications/presentation/bloc/notifications_cubit.dart';
import '../../features/settings/data/datasources/start_screen_local_data_source.dart';
import '../../features/settings/data/repositories/start_screen_repository_impl.dart';
import '../../features/settings/domain/repositories/start_screen_repository.dart';
import '../../features/settings/presentation/bloc/start_screen_cubit.dart';
import '../../features/profile/data/datasources/profile_remote_data_source.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/domain/usecases/get_profile.dart';
import '../../features/profile/presentation/bloc/profile_cubit.dart';
import '../network/api_client.dart';
import '../push/push_token_provider.dart';

final sl = GetIt.instance;

/// Registration name of the [ApiClient] that attaches the bearer token and
/// refreshes it on 401. Features other than auth use this one:
/// `sl<ApiClient>(instanceName: authenticatedApiClient)`.
const authenticatedApiClient = 'authenticated';

Future<void> init() async {
  // Auth
  sl.registerLazySingleton(() => AuthSessionCubit(sl()));
  sl.registerFactory(() => LoginCubit(sl()));
  sl.registerFactoryParam<OtpVerifyCubit, OtpFlow, void>(
    (flow, _) => OtpVerifyCubit(flow, sl(), sl(), sl()),
  );
  sl.registerLazySingleton(() => SendOtp(sl()));
  sl.registerLazySingleton(() => VerifyOtp(sl()));
  sl.registerLazySingleton(() => SignInWithGoogle(sl()));
  sl.registerLazySingleton(() => VerifyGoogleLink(sl()));
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl(), sl(), sl()),
  );
  sl.registerLazySingleton(() => TokenManager(sl(), sl()));
  sl.registerLazySingleton(() => AuthRemoteDataSource(ApiClient.plain()));
  sl.registerLazySingleton(AuthLocalDataSource.new);
  sl.registerLazySingleton(GoogleSignInDataSource.new);
  sl.registerLazySingleton<ApiClient>(
    () => ApiClient.authenticated(sl<TokenManager>()),
    instanceName: authenticatedApiClient,
  );

  // Currency
  sl.registerFactory(() => BaseCurrencyCubit(sl(), sl()));
  sl.registerLazySingleton(() => GetCurrencies(sl()));
  sl.registerLazySingleton(() => PreloadCurrencies(sl()));
  sl.registerLazySingleton(() => SetBaseCurrency(sl()));
  sl.registerLazySingleton<CurrencyRepository>(
    () => CurrencyRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(
    () => CurrencyRemoteDataSource(
      sl<ApiClient>(instanceName: authenticatedApiClient),
    ),
  );

  // Notifications (preferences + device registration)
  sl.registerFactory(() => NotificationsCubit(sl(), sl(), sl(), sl()));
  sl.registerLazySingleton(() => GetNotificationPreferences(sl()));
  sl.registerLazySingleton(() => SetPushEnabled(sl()));
  sl.registerLazySingleton(() => RegisterDevice(sl()));
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(
    () => NotificationRemoteDataSource(
      sl<ApiClient>(instanceName: authenticatedApiClient),
    ),
  );
  // Replace with a Firebase-backed provider to actually register devices.
  sl.registerLazySingleton<PushTokenProvider>(
    () => const NoPushTokenProvider(),
  );

  // Settings (start screen, stored on the device)
  sl.registerLazySingleton(() => StartScreenCubit(sl()));
  sl.registerLazySingleton<StartScreenRepository>(
    () => StartScreenRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(() => const StartScreenLocalDataSource());

  // Favorites
  sl.registerFactory(() => FavoritesCubit(sl(), sl(), sl(), sl(), sl()));
  sl.registerFactory(() => AssetPickerCubit(sl(), sl(), sl()));
  sl.registerFactory(() => BrowseCubit(sl(), sl(), sl()));
  sl.registerLazySingleton(() => GetFavorites(sl()));
  sl.registerLazySingleton(() => GetAssetCatalog(sl()));
  sl.registerLazySingleton(() => AddFavorite(sl()));
  sl.registerLazySingleton(() => RemoveFavorite(sl()));
  sl.registerLazySingleton(() => GetAssetQuote(sl()));
  sl.registerLazySingleton(() => GetAssetHistory(sl()));
  sl.registerLazySingleton<FavoriteRepository>(
    () => FavoriteRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(
    () => FavoriteRemoteDataSource(
      sl<ApiClient>(instanceName: authenticatedApiClient),
    ),
  );

  // Alerts
  sl.registerFactory(() => AlertsCubit(sl(), sl(), sl(), sl()));
  sl.registerLazySingleton(() => GetAlerts(sl()));
  sl.registerLazySingleton(() => CreateAlert(sl()));
  sl.registerLazySingleton(() => UpdateAlert(sl()));
  sl.registerLazySingleton(() => DeleteAlert(sl()));
  sl.registerLazySingleton<AlertRepository>(() => AlertRepositoryImpl(sl()));
  sl.registerLazySingleton(
    () => AlertRemoteDataSource(
      sl<ApiClient>(instanceName: authenticatedApiClient),
    ),
  );

  // Profile
  sl.registerFactory(() => ProfileCubit(sl()));
  sl.registerLazySingleton(() => GetProfile(sl()));
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(
    () => ProfileRemoteDataSource(
      sl<ApiClient>(instanceName: authenticatedApiClient),
    ),
  );

  // Converter
  sl.registerFactory(() => ConverterBloc(convertCurrency: sl()));
  sl.registerLazySingleton(() => ConvertCurrency(sl()));
  sl.registerLazySingleton<ConverterRepository>(
    () => ConverterRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(ConverterLocalDataSource.new);
}
