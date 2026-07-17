import 'package:dio/dio.dart';

import 'auth_models.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthTokens> register({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'email': email, 'password': password},
    );
    return AuthTokens.fromJson(res.data!);
  }

  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return AuthTokens.fromJson(res.data!);
  }

  Future<AuthUser> me() async {
    final res = await _dio.get<Map<String, dynamic>>('/auth/me');
    return AuthUser.fromJson(res.data!);
  }
}
