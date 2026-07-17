import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/auth_state.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/balances/presentation/balances_page.dart';
import '../../features/history/presentation/history_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/intents/presentation/composer_page.dart';
import '../../features/intents/presentation/cubit/composer_cubit.dart';
import '../../features/intents/presentation/cubit/plan_review_cubit.dart';
import '../../features/intents/presentation/plan_review_page.dart';
import '../di/injection.dart';

GoRouter createAppRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: GoRouterRefreshStream(authCubit.stream),
    redirect: (context, state) {
      final status = authCubit.state.status;
      final onAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (status == AuthStatus.initial || status == AuthStatus.loading) {
        return null;
      }
      if (status != AuthStatus.authenticated) {
        return onAuth ? null : '/login';
      }
      if (onAuth) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/home', builder: (_, __) => const HomePage()),
      GoRoute(
        path: '/compose',
        builder: (_, __) => BlocProvider(
          create: (_) => getIt<ComposerCubit>(),
          child: const ComposerPage(),
        ),
      ),
      GoRoute(
        path: '/plans/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider(
            create: (_) => getIt<PlanReviewCubit>(param1: id)..load(),
            child: const PlanReviewPage(),
          );
        },
      ),
      GoRoute(path: '/history', builder: (_, __) => const HistoryPage()),
      GoRoute(path: '/balances', builder: (_, __) => const BalancesPage()),
    ],
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
