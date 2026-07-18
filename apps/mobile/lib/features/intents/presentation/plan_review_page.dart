import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/plan_models.dart';
import 'cubit/plan_review_cubit.dart';
import 'cubit/plan_review_state.dart';
import 'status_labels.dart';
import 'widgets/step_status_chip.dart';

class PlanReviewPage extends StatelessWidget {
  const PlanReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Plan review')),
      body: SafeArea(
        child: BlocBuilder<PlanReviewCubit, PlanReviewState>(
          builder: (context, state) {
            if (state.status == PlanReviewStatus.loading ||
                state.status == PlanReviewStatus.initial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == PlanReviewStatus.error || state.plan == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    state.message ?? 'This plan is unavailable.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final plan = state.plan!;
            final busy = state.busyStepIndex != null;
            final rejected = plan.isRejected;
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    children: [
                      Text(
                        plan.summary.isEmpty ? 'Untitled plan' : plan.summary,
                        style: GoogleFonts.fraunces(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _MetaSection(plan: plan),
                      if (plan.rejectionReasons.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _RejectionSection(reasons: plan.rejectionReasons),
                      ],
                      if (state.message != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          state.message!,
                          style: TextStyle(color: scheme.error, height: 1.35),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Text(
                        rejected ? 'Planned steps (blocked)' : 'Execution steps',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rejected
                            ? 'Policy/schema blocked this plan. Steps below show what the planner produced.'
                            : 'Approve each step in order. A tx hash is returned from the local Anvil executor.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.6),
                              height: 1.35,
                            ),
                      ),
                      const SizedBox(height: 12),
                      if (plan.steps.isEmpty)
                        Text(
                          'No steps were produced for this plan.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.65),
                              ),
                        )
                      else
                        ...plan.steps.map(
                          (step) => _StepCard(
                            step: step,
                            busy: state.busyStepIndex == step.index,
                            canApprove: !busy &&
                                !rejected &&
                                step.status == 'pending' &&
                                _priorSucceeded(plan, step.index),
                            onApprove: () => context
                                .read<PlanReviewCubit>()
                                .approveStep(step.index),
                          ),
                        ),
                    ],
                  ),
                ),
                if (state.canReject)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => context.read<PlanReviewCubit>().reject(),
                      child: Text(
                        state.busyStepIndex == -1 ? 'Rejecting…' : 'Reject plan',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

bool _priorSucceeded(PlanModel plan, int index) {
  for (final step in plan.steps) {
    if (step.index >= index) {
      break;
    }
    if (step.status != 'succeeded') {
      return false;
    }
  }
  return true;
}

class _MetaSection extends StatelessWidget {
  const _MetaSection({required this.plan});

  final PlanModel plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5E0DA)),
      ),
      child: Column(
        children: [
          _MetaRow(label: 'Plan status', trailing: StepStatusChip(status: plan.status)),
          const Divider(height: 20),
          _MetaRow(
            label: 'Schema',
            value: plan.schemaVersion.isEmpty ? '—' : plan.schemaVersion,
          ),
          const SizedBox(height: 10),
          _MetaRow(
            label: 'Steps',
            value: '${plan.steps.length}',
          ),
          const SizedBox(height: 10),
          _MetaRow(
            label: 'Plan ID',
            value: shortHash(plan.id),
            mono: true,
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    this.value,
    this.trailing,
    this.mono = false,
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
        ),
        if (trailing != null)
          trailing!
        else
          Text(
            value ?? '',
            style: (mono
                    ? GoogleFonts.robotoMono(fontSize: 13)
                    : Theme.of(context).textTheme.bodyMedium)
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
      ],
    );
  }
}

class _RejectionSection extends StatelessWidget {
  const _RejectionSection({required this.reasons});

  final List<RejectionReason> reasons;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gpp_bad_outlined, color: Color(0xFF912018), size: 20),
              const SizedBox(width: 8),
              Text(
                'Backend rejection details',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF912018),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatRejectionTitle(reason),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF912018),
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reason.message.isEmpty
                        ? 'code: ${reason.code}'
                        : '${reason.code} · ${reason.message}',
                    style: GoogleFonts.robotoMono(
                      fontSize: 12,
                      height: 1.35,
                      color: const Color(0xFF912018).withValues(alpha: 0.9),
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

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.busy,
    required this.canApprove,
    required this.onApprove,
  });

  final PlanStepModel step;
  final bool busy;
  final bool canApprove;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final details = step.payload.detailRows;
    final hasHash = step.txHash != null && step.txHash!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD5E0DA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step ${step.index + 1}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.action.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                      ),
                    ],
                  ),
                ),
                StepStatusChip(status: step.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              step.decodedSummary.isEmpty ? step.action : step.decodedSummary,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6F4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < details.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 88,
                            child: Text(
                              details[i].$1,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurface.withValues(alpha: 0.55),
                                  ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              details[i].$2,
                              style: GoogleFonts.robotoMono(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (hasHash) ...[
              const SizedBox(height: 12),
              _TxHashBlock(hash: step.txHash!),
            ],
            if (step.error != null && step.error!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                step.error!,
                style: TextStyle(color: scheme.error, height: 1.3),
              ),
            ],
            if (canApprove || busy) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(140, 44),
                  ),
                  onPressed: busy ? null : onApprove,
                  child: Text(busy ? 'Submitting…' : 'Approve'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TxHashBlock extends StatelessWidget {
  const _TxHashBlock({required this.hash});

  final String hash;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'TX HASH',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF95D5B2),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
              ),
              const Spacer(),
              InkWell(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: hash));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tx hash copied')),
                    );
                  }
                },
                child: Text(
                  'Copy',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            hash,
            style: GoogleFonts.robotoMono(
              fontSize: 12.5,
              height: 1.4,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
