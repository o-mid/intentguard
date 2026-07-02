import 'package:get_it/get_it.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies({TokenStorage? storage}) async {
  final tokenStorage = storage ?? SecureTokenStorage();
  getIt.registerSingleton<TokenStorage>(tokenStorage);

  late final AuthCubit authCubit;
  final api = ApiClient(
    storage: tokenStorage,
    onSessionExpired: () => authCubit.sessionExpired(),
  );
  getIt.registerSingleton<ApiClient>(api);

  final repo = AuthRepository(api: api.authApi, storage: tokenStorage);
  getIt.registerSingleton<AuthRepository>(repo);

  authCubit = AuthCubit(repo);
  getIt.registerSingleton<AuthCubit>(authCubit);
}
