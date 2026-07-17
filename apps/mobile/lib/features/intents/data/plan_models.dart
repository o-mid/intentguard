import 'package:equatable/equatable.dart';

class PlanStepModel extends Equatable {
  const PlanStepModel({
    required this.index,
    required this.action,
    required this.decodedSummary,
    required this.status,
    this.txHash,
    this.error,
  });

  final int index;
  final String action;
  final String decodedSummary;
  final String status;
  final String? txHash;
  final String? error;

  factory PlanStepModel.fromJson(Map<String, dynamic> json) {
    return PlanStepModel(
      index: json['index'] as int,
      action: json['action'] as String,
      decodedSummary: json['decoded_summary'] as String? ?? '',
      status: json['status'] as String,
      txHash: json['tx_hash'] as String?,
      error: json['error'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [index, action, decodedSummary, status, txHash, error];
}

class PlanModel extends Equatable {
  const PlanModel({
    required this.id,
    required this.intentId,
    required this.status,
    required this.summary,
    required this.steps,
    this.rejectionReasons = const [],
  });

  final String id;
  final String intentId;
  final String status;
  final String summary;
  final List<PlanStepModel> steps;
  final List<String> rejectionReasons;

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    final steps = (json['steps'] as List<dynamic>? ?? [])
        .map((e) => PlanStepModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final reasonsRaw = json['rejection_reasons'];
    final reasons = <String>[];
    if (reasonsRaw is List) {
      for (final r in reasonsRaw) {
        reasons.add(r.toString());
      }
    }
    return PlanModel(
      id: json['id'] as String,
      intentId: json['intent_id'] as String,
      status: json['status'] as String,
      summary: json['summary'] as String? ?? '',
      steps: steps,
      rejectionReasons: reasons,
    );
  }

  @override
  List<Object?> get props =>
      [id, intentId, status, summary, steps, rejectionReasons];
}

class IntentResult extends Equatable {
  const IntentResult({
    required this.id,
    required this.text,
    required this.status,
    required this.plan,
  });

  final String id;
  final String text;
  final String status;
  final PlanModel plan;

  factory IntentResult.fromJson(Map<String, dynamic> json) {
    return IntentResult(
      id: json['id'] as String,
      text: json['text'] as String,
      status: json['status'] as String,
      plan: PlanModel.fromJson(json['plan'] as Map<String, dynamic>),
    );
  }

  @override
  List<Object?> get props => [id, text, status, plan];
}
