import 'package:get_it/get_it.dart';

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
import '../network/api_client.dart';

final sl = GetIt.instance;

/// Registration name of the [ApiClient] that attaches the bearer token and
/// refreshes it on 401. Features other than auth use this one:
/// `sl<ApiClient>(instanceName: authenticatedApiClient)`.
const authenticatedApiClient = 'authenticated';

Future<void> init() async {
  // Auth
  sl.registerLazySingleton(() => AuthSessionCubit(sl()));
  sl.registerFactory(() => LoginCubit(sl(), sl()));
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

  // Converter
  sl.registerFactory(() => ConverterBloc(convertCurrency: sl()));
  sl.registerLazySingleton(() => ConvertCurrency(sl()));
  sl.registerLazySingleton<ConverterRepository>(
    () => ConverterRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(ConverterLocalDataSource.new);
}
