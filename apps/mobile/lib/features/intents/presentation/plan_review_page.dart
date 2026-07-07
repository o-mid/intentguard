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
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(plan.summary, style: Theme.of(context).textTheme.titleMedium),
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
                const SizedBox(height: 16),
                Text('Steps', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (plan.steps.isEmpty)
                  const Text('No steps in this plan.')
                else
                  ...plan.steps.map((step) => _StepCard(step: step)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});

  final PlanStepModel step;

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
              Text(step.decodedSummary.isEmpty ? step.action : step.decodedSummary),
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
            ],
          ),
        ),
      ),
    );
  }
}
