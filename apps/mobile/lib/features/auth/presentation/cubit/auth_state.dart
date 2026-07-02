import 'package:equatable/equatable.dart';

import '../../data/auth_models.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.message,
  });

  final AuthStatus status;
  final AuthUser? user;
  final String? message;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    String? message,
    bool clearUser = false,
    bool clearMessage = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  List<Object?> get props => [status, user, message];
}
