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
}
