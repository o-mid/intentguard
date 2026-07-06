import 'package:equatable/equatable.dart';

import '../../data/plan_models.dart';

enum ComposerStatus { initial, loading, ready, error }

class ComposerState extends Equatable {
  const ComposerState({
    this.status = ComposerStatus.initial,
    this.text = '',
    this.result,
    this.message,
  });

  final ComposerStatus status;
  final String text;
  final IntentResult? result;
  final String? message;

  ComposerState copyWith({
    ComposerStatus? status,
    String? text,
    IntentResult? result,
    String? message,
    bool clearResult = false,
    bool clearMessage = false,
  }) {
    return ComposerState(
      status: status ?? this.status,
      text: text ?? this.text,
      result: clearResult ? null : (result ?? this.result),
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  List<Object?> get props => [status, text, result, message];
}
