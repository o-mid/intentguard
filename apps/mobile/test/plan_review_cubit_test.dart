import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intentguard/features/intents/data/intents_api.dart';
import 'package:intentguard/features/intents/data/plan_models.dart';
import 'package:intentguard/features/intents/presentation/cubit/plan_review_cubit.dart';
import 'package:intentguard/features/intents/presentation/cubit/plan_review_state.dart';
import 'package:mocktail/mocktail.dart';

class _FakeIntentsApi extends Mock implements IntentsApi {}

const _pendingPlan = PlanModel(
  id: 'plan-1',
  intentId: 'intent-1',
  status: 'awaiting_approval',
  summary: 'Swap 10 USDC',
  steps: [
    PlanStepModel(
      index: 0,
      action: 'approve',
      decodedSummary: 'Approve 10 MOCK_USDC for MockSwapRouter',
      status: 'pending',
    ),
    PlanStepModel(
      index: 1,
      action: 'swap',
      decodedSummary: 'Swap 10 MOCK_USDC → MOCK_WETH',
      status: 'pending',
    ),
  ],
);

const _afterApprove = PlanModel(
  id: 'plan-1',
  intentId: 'intent-1',
  status: 'executing',
  summary: 'Swap 10 USDC',
  steps: [
    PlanStepModel(
      index: 0,
      action: 'approve',
      decodedSummary: 'Approve 10 MOCK_USDC for MockSwapRouter',
      status: 'succeeded',
      txHash: '0xabc',
    ),
    PlanStepModel(
      index: 1,
      action: 'swap',
      decodedSummary: 'Swap 10 MOCK_USDC → MOCK_WETH',
      status: 'pending',
    ),
  ],
);

const _cancelled = PlanModel(
  id: 'plan-1',
  intentId: 'intent-1',
  status: 'cancelled',
  summary: 'Swap 10 USDC',
  steps: [
    PlanStepModel(
      index: 0,
      action: 'approve',
      decodedSummary: 'Approve 10 MOCK_USDC for MockSwapRouter',
      status: 'pending',
    ),
  ],
);

void main() {
  late _FakeIntentsApi api;

  setUp(() {
    api = _FakeIntentsApi();
  });

  blocTest<PlanReviewCubit, PlanReviewState>(
    'load ready',
    build: () {
      when(() => api.getPlan('plan-1')).thenAnswer((_) async => _pendingPlan);
      return PlanReviewCubit(api, 'plan-1');
    },
    act: (cubit) => cubit.load(),
    expect: () => [
      const PlanReviewState(status: PlanReviewStatus.loading),
      const PlanReviewState(status: PlanReviewStatus.ready, plan: _pendingPlan),
    ],
  );

  blocTest<PlanReviewCubit, PlanReviewState>(
    'load error',
    build: () {
      when(() => api.getPlan('plan-1')).thenThrow(Exception('boom'));
      return PlanReviewCubit(api, 'plan-1');
    },
    act: (cubit) => cubit.load(),
    expect: () => [
      const PlanReviewState(status: PlanReviewStatus.loading),
      const PlanReviewState(
        status: PlanReviewStatus.error,
        message: 'This plan could not be loaded.',
      ),
    ],
  );

  blocTest<PlanReviewCubit, PlanReviewState>(
    'approve step refreshes plan',
    build: () {
      when(() => api.getPlan('plan-1')).thenAnswer((_) async => _afterApprove);
      when(() => api.approveStep('plan-1', 0)).thenAnswer(
        (_) async => const PlanStepModel(
          index: 0,
          action: '',
          decodedSummary: '',
          status: 'succeeded',
          txHash: '0xabc',
        ),
      );
      return PlanReviewCubit(api, 'plan-1');
    },
    seed: () => const PlanReviewState(
      status: PlanReviewStatus.ready,
      plan: _pendingPlan,
    ),
    act: (cubit) => cubit.approveStep(0),
    expect: () => [
      const PlanReviewState(
        status: PlanReviewStatus.ready,
        plan: _pendingPlan,
        busyStepIndex: 0,
      ),
      const PlanReviewState(status: PlanReviewStatus.ready, plan: _afterApprove),
    ],
  );

  blocTest<PlanReviewCubit, PlanReviewState>(
    'reject cancels plan',
    build: () {
      when(() => api.rejectPlan('plan-1')).thenAnswer((_) async => _cancelled);
      return PlanReviewCubit(api, 'plan-1');
    },
    seed: () => const PlanReviewState(
      status: PlanReviewStatus.ready,
      plan: _pendingPlan,
    ),
    act: (cubit) => cubit.reject(),
    expect: () => [
      const PlanReviewState(
        status: PlanReviewStatus.ready,
        plan: _pendingPlan,
        busyStepIndex: -1,
      ),
      const PlanReviewState(status: PlanReviewStatus.ready, plan: _cancelled),
    ],
  );

  blocTest<PlanReviewCubit, PlanReviewState>(
    'approve failure keeps plan and shows message',
    build: () {
      when(() => api.approveStep('plan-1', 0)).thenThrow(Exception('fail'));
      return PlanReviewCubit(api, 'plan-1');
    },
    seed: () => const PlanReviewState(
      status: PlanReviewStatus.ready,
      plan: _pendingPlan,
    ),
    act: (cubit) => cubit.approveStep(0),
    expect: () => [
      const PlanReviewState(
        status: PlanReviewStatus.ready,
        plan: _pendingPlan,
        busyStepIndex: 0,
      ),
      const PlanReviewState(
        status: PlanReviewStatus.ready,
        plan: _pendingPlan,
        message: 'That step failed to approve. Try again.',
      ),
    ],
  );
}
