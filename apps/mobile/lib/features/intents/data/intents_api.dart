import 'package:dio/dio.dart';

import 'plan_models.dart';

class IntentsApi {
  IntentsApi(this._dio);

  final Dio _dio;

  Future<IntentResult> submit(String text) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/intents',
      data: {'text': text},
    );
    return IntentResult.fromJson(res.data!);
  }

  Future<PlanModel> getPlan(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/plans/$id');
    return PlanModel.fromJson(res.data!);
  }

  Future<PlanStepModel> approveStep(String planId, int index) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/plans/$planId/steps/$index/approve',
    );
    final data = res.data!;
    return PlanStepModel(
      index: data['index'] as int,
      action: '',
      decodedSummary: '',
      status: data['status'] as String,
      txHash: data['tx_hash'] as String?,
      error: data['error'] as String?,
    );
  }

  Future<PlanModel> rejectPlan(String planId) async {
    final res = await _dio.post<Map<String, dynamic>>('/plans/$planId/reject');
    return PlanModel.fromJson(res.data!);
  }

  Future<List<IntentResult>> listIntents() async {
    final res = await _dio.get<List<dynamic>>('/intents');
    return (res.data ?? [])
        .map((e) => IntentResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
