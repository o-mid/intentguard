import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'core/storage/token_storage.dart';

Future<void> bootstrapApp({
  TokenStorage? storage,
  String? apiBase,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies(storage: storage, apiBase: apiBase);
  runApp(const IntentGuardApp());
}
