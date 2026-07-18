import 'package:flutter/material.dart';

import '../status_labels.dart';

enum StepChipTone { auto, danger, success, warning, neutral }

class StepStatusChip extends StatelessWidget {
  const StepStatusChip({
    super.key,
    required this.status,
    this.tone = StepChipTone.auto,
    this.label,
  });

  final String status;
  final StepChipTone tone;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveTone(status, tone);
    final colors = _colorsFor(resolved);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.$2),
      ),
      child: Text(
        label ?? formatStatus(status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.$3,
            ),
      ),
    );
  }
}

StepChipTone _resolveTone(String status, StepChipTone tone) {
  if (tone != StepChipTone.auto) {
    return tone;
  }
  switch (status) {
    case 'succeeded':
    case 'completed':
      return StepChipTone.success;
    case 'failed':
    case 'rejected_schema':
    case 'rejected_policy':
    case 'cancelled':
      return StepChipTone.danger;
    case 'submitting':
    case 'approved':
    case 'executing':
    case 'awaiting_approval':
      return StepChipTone.warning;
    default:
      return StepChipTone.neutral;
  }
}

(Color, Color, Color) _colorsFor(StepChipTone tone) {
  switch (tone) {
    case StepChipTone.danger:
      return (
        const Color(0xFFFEE4E2),
        const Color(0xFFFECACA),
        const Color(0xFF912018),
      );
    case StepChipTone.success:
      return (
        const Color(0xFFD8F3DC),
        const Color(0xFF95D5B2),
        const Color(0xFF1B4332),
      );
    case StepChipTone.warning:
      return (
        const Color(0xFFFFF4D6),
        const Color(0xFFF6DE9A),
        const Color(0xFF7A5B00),
      );
    case StepChipTone.neutral:
    case StepChipTone.auto:
      return (
        const Color(0xFFE8EFEC),
        const Color(0xFFC5D4CD),
        const Color(0xFF1B4332),
      );
  }
}
