import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Demo balances for local Anvil tokens (no chain read wired yet).
class BalancesPage extends StatelessWidget {
  const BalancesPage({super.key});

  static const _rows = [
    ('MOCK_USDC', '1,000.00'),
    ('MOCK_ETH', '5.0000'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Balances')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'Demo balances',
            style: GoogleFonts.fraunces(
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seeded Anvil demo balances used by the mock planner (MOCK_USDC / MOCK_ETH).',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.65),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 20),
          ..._rows.map(
            (row) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD5E0DA)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.$1,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Text(
                    row.$2,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
