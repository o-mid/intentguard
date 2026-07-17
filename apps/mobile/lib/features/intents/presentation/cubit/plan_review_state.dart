import 'package:equatable/equatable.dart';

import '../../data/plan_models.dart';

enum PlanReviewStatus { initial, loading, ready, error }

class PlanReviewState extends Equatable {
  const PlanReviewState({
    this.status = PlanReviewStatus.initial,
    this.plan,
    this.message,
    this.busyStepIndex,
  });

  final PlanReviewStatus status;
  final PlanModel? plan;
  final String? message;
  final int? busyStepIndex;

  bool get canReject =>
      plan != null &&
      (plan!.status == 'awaiting_approval' || plan!.status == 'executing');

  PlanReviewState copyWith({
    PlanReviewStatus? status,
    PlanModel? plan,
    String? message,
    int? busyStepIndex,
    bool clearMessage = false,
    bool clearBusy = false,
  }) {
    return PlanReviewState(
      status: status ?? this.status,
      plan: plan ?? this.plan,
      message: clearMessage ? null : (message ?? this.message),
      busyStepIndex: clearBusy ? null : (busyStepIndex ?? this.busyStepIndex),
    );
  }

  @override
  List<Object?> get props => [status, plan, message, busyStepIndex];
}
