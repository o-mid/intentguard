import 'package:equatable/equatable.dart';

class RejectionReason extends Equatable {
  const RejectionReason({required this.code, this.message = ''});

  final String code;
  final String message;

  factory RejectionReason.fromJson(dynamic raw) {
    if (raw is String) {
      return RejectionReason(code: raw);
    }
    if (raw is Map<String, dynamic>) {
      return RejectionReason(
        code: raw['code']?.toString() ?? 'unknown',
        message: raw['message']?.toString() ?? '',
      );
    }
    return RejectionReason(code: raw.toString());
  }

  @override
  List<Object?> get props => [code, message];
}

class StepPayload extends Equatable {
  const StepPayload({
    this.action = '',
    this.token,
    this.amount,
    this.spender,
    this.to,
    this.tokenIn,
    this.tokenOut,
    this.amountIn,
    this.minAmountOut,
    this.maxSlippageBps,
  });

  final String action;
  final String? token;
  final String? amount;
  final String? spender;
  final String? to;
  final String? tokenIn;
  final String? tokenOut;
  final String? amountIn;
  final String? minAmountOut;
  final int? maxSlippageBps;

  factory StepPayload.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const StepPayload();
    }
    return StepPayload(
      action: json['action']?.toString() ?? '',
      token: json['token']?.toString(),
      amount: json['amount']?.toString(),
      spender: json['spender']?.toString(),
      to: json['to']?.toString(),
      tokenIn: json['tokenIn']?.toString(),
      tokenOut: json['tokenOut']?.toString(),
      amountIn: json['amountIn']?.toString(),
      minAmountOut: json['minAmountOut']?.toString(),
      maxSlippageBps: json['maxSlippageBps'] is int
          ? json['maxSlippageBps'] as int
          : int.tryParse('${json['maxSlippageBps'] ?? ''}'),
    );
  }

  List<(String, String)> get detailRows {
    final rows = <(String, String)>[];
    void add(String label, String? value) {
      if (value != null && value.isNotEmpty) {
        rows.add((label, value));
      }
    }

    add('Token', token);
    add('Amount', amount);
    add('Spender', spender);
    add('To', to);
    add('Token in', tokenIn);
    add('Token out', tokenOut);
    add('Amount in', amountIn);
    add('Min out', minAmountOut);
    if (maxSlippageBps != null && maxSlippageBps! > 0) {
      rows.add(('Max slippage', '$maxSlippageBps bps'));
    }
    return rows;
  }

  @override
  List<Object?> get props => [
        action,
        token,
        amount,
        spender,
        to,
        tokenIn,
        tokenOut,
        amountIn,
        minAmountOut,
        maxSlippageBps,
      ];
}

class PlanStepModel extends Equatable {
  const PlanStepModel({
    required this.index,
    required this.action,
    required this.decodedSummary,
    required this.status,
    this.txHash,
    this.error,
    this.payload = const StepPayload(),
  });

  final int index;
  final String action;
  final String decodedSummary;
  final String status;
  final String? txHash;
  final String? error;
  final StepPayload payload;

  factory PlanStepModel.fromJson(Map<String, dynamic> json) {
    final payloadRaw = json['payload'];
    return PlanStepModel(
      index: json['index'] as int,
      action: json['action'] as String? ?? '',
      decodedSummary: json['decoded_summary'] as String? ?? '',
      status: json['status'] as String,
      txHash: json['tx_hash'] as String?,
      error: json['error'] as String?,
      payload: StepPayload.fromJson(
        payloadRaw is Map<String, dynamic> ? payloadRaw : null,
      ),
    );
  }

  @override
  List<Object?> get props =>
      [index, action, decodedSummary, status, txHash, error, payload];
}

class PlanModel extends Equatable {
  const PlanModel({
    required this.id,
    required this.intentId,
    required this.status,
    required this.summary,
    required this.steps,
    this.schemaVersion = '',
    this.rejectionReasons = const [],
  });

  final String id;
  final String intentId;
  final String status;
  final String summary;
  final String schemaVersion;
  final List<PlanStepModel> steps;
  final List<RejectionReason> rejectionReasons;

  bool get isRejected =>
      status == 'rejected_schema' ||
      status == 'rejected_policy' ||
      status == 'cancelled';

  bool get isCompleted => status == 'completed';

  bool get isActive =>
      status == 'awaiting_approval' ||
      status == 'executing' ||
      status == 'planning';

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    final steps = (json['steps'] as List<dynamic>? ?? [])
        .map((e) => PlanStepModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final reasonsRaw = json['rejection_reasons'];
    final reasons = <RejectionReason>[];
    if (reasonsRaw is List) {
      for (final r in reasonsRaw) {
        reasons.add(RejectionReason.fromJson(r));
      }
    }
    return PlanModel(
      id: json['id'] as String,
      intentId: json['intent_id'] as String,
      status: json['status'] as String,
      summary: json['summary'] as String? ?? '',
      schemaVersion: json['schema_version'] as String? ?? '',
      steps: steps,
      rejectionReasons: reasons,
    );
  }

  @override
  List<Object?> get props =>
      [id, intentId, status, summary, schemaVersion, steps, rejectionReasons];
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
