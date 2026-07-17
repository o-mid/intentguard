import '../../../core/storage/token_storage.dart';
import 'auth_api.dart';
import 'auth_models.dart';

class AuthRepository {
  AuthRepository({
    required AuthApi api,
    required TokenStorage storage,
  })  : _api = api,
        _storage = storage;

  final AuthApi _api;
  final TokenStorage _storage;

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final tokens = await _api.login(email: email, password: password);
    await _storage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      email: tokens.user.email,
    );
    return tokens.user;
  }

  Future<AuthUser> register({
    required String email,
    required String password,
  }) async {
    final tokens = await _api.register(email: email, password: password);
    await _storage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      email: tokens.user.email,
    );
    return tokens.user;
  }

  Future<AuthUser?> restoreSession() async {
    final token = await _storage.readAccessToken();
    if (token == null || token.isEmpty) {
      return null;
    }
    try {
      return await _api.me();
    } catch (_) {
      await _storage.clear();
      return null;
    }
  }

  Future<void> logout() => _storage.clear();
}
