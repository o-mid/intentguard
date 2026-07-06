import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/cubit/auth_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthCubit>().state.user?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('IntentGuard'),
        actions: [
          TextButton(
            onPressed: () => context.read<AuthCubit>().logout(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(email, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('New intent'),
            subtitle: const Text('Compose and plan'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/compose'),
          ),
        ],
      ),
    );
  }
}
