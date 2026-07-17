import 'package:flutter_bloc/flutter_bloc.dart';

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
    } catch (_) {
      emit(const AuthState(
        status: AuthStatus.unauthenticated,
        message: 'Login failed',
      ));
    }
  }

  Future<void> register(String email, String password) async {
    emit(state.copyWith(status: AuthStatus.loading, clearMessage: true));
    try {
      final user = await _repo.register(email: email, password: password);
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } catch (_) {
      emit(const AuthState(
        status: AuthStatus.unauthenticated,
        message: 'Register failed',
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
}
