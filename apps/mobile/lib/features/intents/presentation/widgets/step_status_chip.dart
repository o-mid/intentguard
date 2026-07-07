import 'package:flutter/material.dart';

class StepStatusChip extends StatelessWidget {
  const StepStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color bg;
    switch (status) {
      case 'succeeded':
        bg = scheme.primaryContainer;
      case 'failed':
      case 'rejected_schema':
      case 'rejected_policy':
        bg = scheme.errorContainer;
      case 'submitting':
      case 'approved':
        bg = scheme.tertiaryContainer;
      default:
        bg = scheme.surfaceContainerHigh;
    }
    return Chip(
      label: Text(status),
      visualDensity: VisualDensity.compact,
      backgroundColor: bg,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
