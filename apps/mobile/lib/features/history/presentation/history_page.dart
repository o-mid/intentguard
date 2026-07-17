import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../intents/data/intents_api.dart';
import '../../intents/data/plan_models.dart';
import '../../../core/di/injection.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<IntentResult>> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<IntentsApi>().listIntents();
  }

  Future<void> _reload() async {
    setState(() {
      _future = getIt<IntentsApi>().listIntents();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: FutureBuilder<List<IntentResult>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('History could not be loaded.'),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _reload, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('No intents yet. Compose one from Home.'),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final item = items[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.text),
                  subtitle: Text('${item.status} · plan ${item.plan.status}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/plans/${item.plan.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
