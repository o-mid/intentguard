import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/auth/presentation/cubit/auth_state.dart';

class IntentGuardApp extends StatefulWidget {
  const IntentGuardApp({super.key});

  @override
  State<IntentGuardApp> createState() => _IntentGuardAppState();
}

class _IntentGuardAppState extends State<IntentGuardApp> {
  late final AuthCubit _authCubit = getIt<AuthCubit>()..bootstrap();
  late final _router = createAppRouter(_authCubit);

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authCubit,
      child: BlocBuilder<AuthCubit, AuthState>(
        buildWhen: (prev, next) =>
            prev.status == AuthStatus.initial ||
            next.status == AuthStatus.initial ||
            prev.status == AuthStatus.loading ||
            next.status == AuthStatus.loading,
        builder: (context, state) {
          if (state.status == AuthStatus.initial ||
              state.status == AuthStatus.loading) {
            return MaterialApp(
              theme: AppTheme.light(),
              home: const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          return MaterialApp.router(
            title: 'IntentGuard',
            theme: AppTheme.light(),
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
