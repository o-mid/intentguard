import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/plan_models.dart';
import 'cubit/plan_review_cubit.dart';
import 'cubit/plan_review_state.dart';
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
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StepStatusChip(status: plan.status),
                          if (plan.rejectionReasons.isNotEmpty)
                            StepStatusChip(
                              status: plan.rejectionReasons.join(', '),
                              tone: StepChipTone.danger,
                            ),
                        ],
                      ),
                      if (state.message != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          state.message!,
                          style: TextStyle(color: scheme.error, height: 1.35),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Text(
                        'Steps',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      if (plan.steps.isEmpty)
                        Text(
                          'No executable steps. Rejected plans stay here for review.',
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
                                plan.status != 'cancelled' &&
                                plan.status != 'rejected_schema' &&
                                plan.status != 'rejected_policy' &&
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
              children: [
                Expanded(
                  child: Text(
                    'Step ${step.index + 1}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Flexible(child: StepStatusChip(status: step.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              step.decodedSummary.isEmpty ? step.action : step.decodedSummary,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.35),
            ),
            if (step.txHash != null && step.txHash!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                step.txHash!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
              ),
            ],
            if (step.error != null && step.error!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                step.error!,
                style: TextStyle(color: scheme.error, height: 1.3),
              ),
            ],
            if (canApprove || busy) ...[
              const SizedBox(height: 12),
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
