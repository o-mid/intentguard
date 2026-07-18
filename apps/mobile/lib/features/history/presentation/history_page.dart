import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/di/injection.dart';
import '../../intents/data/intents_api.dart';
import '../../intents/data/plan_models.dart';
import '../../intents/presentation/status_labels.dart';
import '../../intents/presentation/widgets/step_status_chip.dart';

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
    final scheme = Theme.of(context).colorScheme;
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
                    Text(
                      'History could not be loaded.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _reload, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No intents yet. Compose one from Home.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                ),
              ),
            );
          }

          final completed = items.where((e) => e.plan.isCompleted).toList();
          final active = items.where((e) => e.plan.isActive).toList();
          final rejected = items.where((e) => e.plan.isRejected).toList();

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  'Backend outcomes',
                  style: GoogleFonts.fraunces(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Separated by plan status from the API — completed executions vs policy/schema rejects.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.65),
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 18),
                if (completed.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Completed',
                    count: completed.length,
                    tone: StepChipTone.success,
                  ),
                  const SizedBox(height: 10),
                  ...completed.map((item) => _HistoryCard(item: item)),
                  const SizedBox(height: 18),
                ],
                if (active.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'In progress',
                    count: active.length,
                    tone: StepChipTone.warning,
                  ),
                  const SizedBox(height: 10),
                  ...active.map((item) => _HistoryCard(item: item)),
                  const SizedBox(height: 18),
                ],
                if (rejected.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Rejected',
                    count: rejected.length,
                    tone: StepChipTone.danger,
                  ),
                  const SizedBox(height: 10),
                  ...rejected.map((item) => _HistoryCard(item: item, showReject: true)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.tone,
  });

  final String title;
  final int count;
  final StepChipTone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(width: 8),
        StepStatusChip(
          status: title.toLowerCase(),
          tone: tone,
          label: '$count',
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, this.showReject = false});

  final IntentResult item;
  final bool showReject;

  @override
  Widget build(BuildContext context) {
    final plan = item.plan;
    final succeeded = plan.steps.where((s) => s.status == 'succeeded').length;
    final hashes = plan.steps
        .where((s) => s.txHash != null && s.txHash!.isNotEmpty)
        .map((s) => s.txHash!)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/plans/${plan.id}'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: showReject
                    ? const Color(0xFFFECACA)
                    : const Color(0xFFD5E0DA),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    StepStatusChip(status: plan.status),
                  ],
                ),
                if (plan.summary.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    plan.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.65),
                        ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  plan.isCompleted
                      ? '$succeeded/${plan.steps.length} steps executed'
                      : plan.isActive
                          ? '${plan.steps.length} steps · approve in order'
                          : plan.rejectionReasons.isEmpty
                              ? 'Cancelled by user'
                              : '${plan.rejectionReasons.length} rejection reason(s)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (showReject && plan.rejectionReasons.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...plan.rejectionReasons.take(3).map(
                        (reason) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF5F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatRejectionTitle(reason),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        color: const Color(0xFF912018),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                if (reason.message.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    reason.message,
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 11.5,
                                      color: const Color(0xFF912018)
                                          .withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                ],
                if (hashes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Last tx ${shortHash(hashes.last)}',
                    style: GoogleFonts.robotoMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1B4332),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
