import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/plan_models.dart';
import 'cubit/plan_review_cubit.dart';
import 'cubit/plan_review_state.dart';
import 'widgets/step_status_chip.dart';

class PlanReviewPage extends StatelessWidget {
  const PlanReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                  child: Text(state.message ?? 'Plan unavailable'),
                ),
              );
            }
            final plan = state.plan!;
            final busy = state.busyStepIndex != null;
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        plan.summary,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(label: Text(plan.status)),
                          if (plan.rejectionReasons.isNotEmpty)
                            Chip(
                              label: Text(plan.rejectionReasons.join(', ')),
                              backgroundColor:
                                  Theme.of(context).colorScheme.errorContainer,
                            ),
                        ],
                      ),
                      if (state.message != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          state.message!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Steps',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      if (plan.steps.isEmpty)
                        const Text('No steps in this plan.')
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Step ${step.index + 1}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const Spacer(),
                  StepStatusChip(status: step.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                step.decodedSummary.isEmpty ? step.action : step.decodedSummary,
              ),
              if (step.txHash != null && step.txHash!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  step.txHash!,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (step.error != null && step.error!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  step.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (canApprove || busy) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: busy ? null : onApprove,
                    child: Text(busy ? 'Submitting…' : 'Approve'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
