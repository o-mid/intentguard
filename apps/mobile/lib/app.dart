import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

class IntentGuardApp extends StatelessWidget {
  const IntentGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IntentGuard',
      theme: AppTheme.light(),
      home: const Scaffold(
        body: Center(child: Text('IntentGuard')),
      ),
    );
  }
}
