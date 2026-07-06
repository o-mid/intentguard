import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/intents_api.dart';
import 'composer_state.dart';

class ComposerCubit extends Cubit<ComposerState> {
  ComposerCubit(this._api) : super(const ComposerState());

  final IntentsApi _api;

  static const exampleChips = [
    'swap 10 USDC',
    'transfer 5 USDC',
    'bridge funds somewhere',
    'swap 150 USDC',
  ];

  void setText(String value) {
    emit(state.copyWith(text: value, clearMessage: true));
  }

  void useChip(String chip) {
    emit(state.copyWith(text: chip, clearMessage: true));
  }

  Future<void> submit() async {
    final text = state.text.trim();
    if (text.isEmpty) {
      emit(state.copyWith(
        status: ComposerStatus.error,
        message: 'Enter an intent',
      ));
      return;
    }
    emit(state.copyWith(status: ComposerStatus.loading, clearMessage: true));
    try {
      final result = await _api.submit(text);
      emit(ComposerState(
        status: ComposerStatus.ready,
        text: text,
        result: result,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: ComposerStatus.error,
        message: 'Plan rejected or unavailable',
      ));
    }
  }
}
