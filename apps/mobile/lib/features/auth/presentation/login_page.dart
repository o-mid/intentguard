import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import 'cubit/auth_cubit.dart';
import 'cubit/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController(text: 'demo@wallet.test');
  final _password = TextEditingController(text: 'password123');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7FAF8), Color(0xFFE4EFE9), Color(0xFFD7E8DF)],
          ),
        ),
        child: SafeArea(
          child: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              final loading = state.status == AuthStatus.loading;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'IntentGuard',
                      style: GoogleFonts.fraunces(
                        fontSize: 40,
                        fontWeight: FontWeight.w600,
                        height: 1.05,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Natural-language intents. Schema, policy, then you approve each step.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.72),
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFD5E0DA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                                  Text(
                                    'Welcome back',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(labelText: 'Email'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _password,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!loading) {
                                context.read<AuthCubit>().login(
                                      _email.text.trim(),
                                      _password.text,
                                    );
                              }
                            },
                            decoration: const InputDecoration(labelText: 'Password'),
                          ),
                          if (state.message != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              state.message!,
                              style: TextStyle(
                                color: scheme.error,
                                height: 1.35,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: loading
                                ? null
                                : () => context.read<AuthCubit>().login(
                                      _email.text.trim(),
                                      _password.text,
                                    ),
                            child: Text(loading ? 'Signing in…' : 'Sign in'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed:
                                loading ? null : () => context.push('/register'),
                            child: const Text('Create account'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'API  $kApiBase',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.45),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'On a physical phone use your Mac LAN IP, not 127.0.0.1',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.4),
                          ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
