import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intentguard/core/storage/token_storage.dart';
import 'package:intentguard/features/auth/data/auth_api.dart';
import 'package:intentguard/features/auth/data/auth_models.dart';
import 'package:intentguard/features/auth/data/auth_repository.dart';
import 'package:intentguard/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:intentguard/features/auth/presentation/cubit/auth_state.dart';
import 'package:mocktail/mocktail.dart';

class _FakeAuthApi extends Mock implements AuthApi {}

void main() {
  late _FakeAuthApi api;
  late MemoryTokenStorage storage;
  late AuthRepository repo;

  setUp(() {
    api = _FakeAuthApi();
    storage = MemoryTokenStorage();
    repo = AuthRepository(api: api, storage: storage);
  });

  blocTest<AuthCubit, AuthState>(
    'login success',
    build: () {
      when(() => api.login(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer(
        (_) async => const AuthTokens(
          accessToken: 'a',
          refreshToken: 'r',
          user: AuthUser(id: '1', email: 'alice@wallet.test'),
        ),
      );
      return AuthCubit(repo);
    },
    act: (cubit) => cubit.login('alice@wallet.test', 'password123'),
    expect: () => [
      const AuthState(status: AuthStatus.loading),
      const AuthState(
        status: AuthStatus.authenticated,
        user: AuthUser(id: '1', email: 'alice@wallet.test'),
      ),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'login failure',
    build: () {
      when(() => api.login(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(Exception('bad'));
      return AuthCubit(repo);
    },
    act: (cubit) => cubit.login('alice@wallet.test', 'wrong'),
    expect: () => [
      const AuthState(status: AuthStatus.loading),
      const AuthState(
        status: AuthStatus.unauthenticated,
        message: 'Login failed',
      ),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'bootstrap restores session',
    build: () {
      return AuthCubit(repo);
    },
    setUp: () async {
      await storage.saveTokens(
        accessToken: 'a',
        refreshToken: 'r',
        email: 'alice@wallet.test',
      );
      when(() => api.me()).thenAnswer(
        (_) async => const AuthUser(id: '1', email: 'alice@wallet.test'),
      );
    },
    act: (cubit) => cubit.bootstrap(),
    expect: () => [
      const AuthState(status: AuthStatus.loading),
      const AuthState(
        status: AuthStatus.authenticated,
        user: AuthUser(id: '1', email: 'alice@wallet.test'),
      ),
    ],
  );
}
