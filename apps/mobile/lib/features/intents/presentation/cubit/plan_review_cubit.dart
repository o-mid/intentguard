import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/intents_api.dart';
import 'plan_review_state.dart';

class PlanReviewCubit extends Cubit<PlanReviewState> {
  PlanReviewCubit(this._api, this.planId) : super(const PlanReviewState());

  final IntentsApi _api;
  final String planId;

  Future<void> load() async {
    emit(state.copyWith(status: PlanReviewStatus.loading, clearMessage: true));
    try {
      final plan = await _api.getPlan(planId);
      emit(PlanReviewState(status: PlanReviewStatus.ready, plan: plan));
    } catch (_) {
      emit(state.copyWith(
        status: PlanReviewStatus.error,
        message: 'Could not load plan',
      ));
    }
  }

  Future<void> approveStep(int index) async {
    final plan = state.plan;
    if (plan == null || state.busyStepIndex != null) {
      return;
    }
    emit(state.copyWith(busyStepIndex: index, clearMessage: true));
    try {
      await _api.approveStep(plan.id, index);
      final refreshed = await _api.getPlan(plan.id);
      emit(PlanReviewState(status: PlanReviewStatus.ready, plan: refreshed));
    } catch (_) {
      emit(state.copyWith(
        clearBusy: true,
        message: 'Step approval failed',
      ));
    }
  }

  Future<void> reject() async {
    final plan = state.plan;
    if (plan == null || !state.canReject || state.busyStepIndex != null) {
      return;
    }
    emit(state.copyWith(busyStepIndex: -1, clearMessage: true));
    try {
      final cancelled = await _api.rejectPlan(plan.id);
      emit(PlanReviewState(status: PlanReviewStatus.ready, plan: cancelled));
    } catch (_) {
      emit(state.copyWith(
        clearBusy: true,
        message: 'Could not reject plan',
      ));
    }
  }
}
