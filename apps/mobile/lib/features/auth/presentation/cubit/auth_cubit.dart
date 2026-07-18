import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants.dart';
import '../../data/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repo) : super(const AuthState());

  final AuthRepository _repo;

  Future<void> bootstrap() async {
    emit(state.copyWith(status: AuthStatus.loading, clearMessage: true));
    final user = await _repo.restoreSession();
    if (user == null) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
      return;
    }
    emit(AuthState(status: AuthStatus.authenticated, user: user));
  }

  Future<void> login(String email, String password) async {
    emit(state.copyWith(status: AuthStatus.loading, clearMessage: true));
    try {
      final user = await _repo.login(email: email, password: password);
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } catch (e) {
      emit(AuthState(
        status: AuthStatus.unauthenticated,
        message: _authError('Login failed', e),
      ));
    }
  }

  Future<void> register(String email, String password) async {
    emit(state.copyWith(status: AuthStatus.loading, clearMessage: true));
    try {
      final user = await _repo.register(email: email, password: password);
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } catch (e) {
      emit(AuthState(
        status: AuthStatus.unauthenticated,
        message: _authError('Register failed', e),
      ));
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  void sessionExpired() {
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  String _authError(String fallback, Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'Cannot reach API at $kApiBase. On a phone use your Mac LAN IP (not 127.0.0.1).';
      }
      final code = e.response?.statusCode;
      if (code == 401 || code == 400) {
        return '$fallback. Check email/password.';
      }
      if (code != null) {
        return '$fallback (HTTP $code).';
      }
    }
    return fallback;
  }
}
