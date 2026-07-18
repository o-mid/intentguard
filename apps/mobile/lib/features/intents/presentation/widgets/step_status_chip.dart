import 'package:flutter/material.dart';

enum StepChipTone { auto, danger }

class StepStatusChip extends StatelessWidget {
  const StepStatusChip({
    super.key,
    required this.status,
    this.tone = StepChipTone.auto,
  });

  final String status;
  final StepChipTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color bg;
    if (tone == StepChipTone.danger) {
      bg = scheme.errorContainer;
    } else {
      switch (status) {
        case 'succeeded':
        case 'completed':
        case 'awaiting_approval':
          bg = scheme.primaryContainer;
        case 'failed':
        case 'rejected_schema':
        case 'rejected_policy':
        case 'cancelled':
          bg = scheme.errorContainer;
        case 'submitting':
        case 'approved':
        case 'executing':
          bg = scheme.tertiaryContainer;
        default:
          bg = scheme.surfaceContainerHigh;
      }
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
