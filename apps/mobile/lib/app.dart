import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/auth/presentation/cubit/auth_state.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/register_page.dart';
import 'features/home/presentation/home_page.dart';

class IntentGuardApp extends StatelessWidget {
  const IntentGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<AuthCubit>()..bootstrap(),
      child: MaterialApp(
        title: 'IntentGuard',
        theme: AppTheme.light(),
        routes: {
          '/login': (_) => const LoginPage(),
          '/register': (_) => const RegisterPage(),
          '/home': (_) => const HomePage(),
        },
        home: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            switch (state.status) {
              case AuthStatus.authenticated:
                return const HomePage();
              case AuthStatus.loading:
              case AuthStatus.initial:
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              case AuthStatus.unauthenticated:
              case AuthStatus.error:
                return const LoginPage();
            }
          },
        ),
      ),
    );
  }
}
