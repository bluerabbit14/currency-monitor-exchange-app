import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/google_sign_in_data_source.dart';
import '../../features/auth/presentation/bloc/google_sign_in_cubit.dart';
import '../../features/converter/data/datasources/converter_local_data_source.dart';
import '../../features/converter/data/repositories/converter_repository_impl.dart';
import '../../features/converter/domain/repositories/converter_repository.dart';
import '../../features/converter/domain/usecases/convert_currency.dart';
import '../../features/converter/presentation/bloc/converter_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  sl.registerFactory(() => GoogleSignInCubit(sl()));
  sl.registerLazySingleton(GoogleSignInDataSource.new);

  sl.registerFactory(() => ConverterBloc(convertCurrency: sl()));
  sl.registerLazySingleton(() => ConvertCurrency(sl()));
  sl.registerLazySingleton<ConverterRepository>(
    () => ConverterRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(ConverterLocalDataSource.new);
}
