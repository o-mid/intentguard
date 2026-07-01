import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Attaches the access token. On 401, clears the session (no refresh endpoint yet).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.storage,
    required this.onSessionExpired,
  });

  final TokenStorage storage;
  final void Function() onSessionExpired;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await storage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await storage.clear();
      onSessionExpired();
    }
    handler.next(err);
  }
}
