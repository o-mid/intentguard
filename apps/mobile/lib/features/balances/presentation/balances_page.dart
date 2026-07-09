import 'package:flutter/material.dart';

/// Demo balances for local Anvil tokens (no chain read wired yet).
class BalancesPage extends StatelessWidget {
  const BalancesPage({super.key});

  static const _rows = [
    ('MOCK_USDC', '1,000.00'),
    ('MOCK_WETH', '5.0000'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balances')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Demo balances (Anvil)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Shown for local demos. Live chain reads land later.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ..._rows.map(
            (row) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(row.$1),
              trailing: Text(
                row.$2,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
