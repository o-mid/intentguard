import '../data/plan_models.dart';

String formatStatus(String status) {
  switch (status) {
    case 'awaiting_approval':
      return 'Awaiting approval';
    case 'executing':
      return 'Executing';
    case 'completed':
      return 'Completed';
    case 'rejected_schema':
      return 'Rejected · schema';
    case 'rejected_policy':
      return 'Rejected · policy';
    case 'cancelled':
      return 'Cancelled';
    case 'planning':
      return 'Planning';
    case 'pending':
      return 'Pending';
    case 'approved':
      return 'Approved';
    case 'submitting':
      return 'Submitting';
    case 'succeeded':
      return 'Succeeded';
    case 'failed':
      return 'Failed';
    default:
      return status.replaceAll('_', ' ');
  }
}

String formatRejectionTitle(RejectionReason reason) {
  switch (reason.code) {
    case 'schema_invalid':
      return 'Schema validation failed';
    case 'amount_over_cap':
      return 'Amount over policy cap';
    case 'too_many_steps':
      return 'Too many steps';
    case 'bad_token':
      return 'Token not allowlisted';
    case 'bad_recipient':
      return 'Recipient not allowlisted';
    case 'bad_spender':
      return 'Spender not allowlisted';
    case 'infinite_approve':
      return 'Infinite approve blocked';
    case 'slippage_too_high':
      return 'Slippage too high';
    case 'unknown_action':
      return 'Unknown action';
    case 'bad_amount':
      return 'Invalid amount';
    default:
      return reason.code.replaceAll('_', ' ');
  }
}

String formatRejectionDetail(RejectionReason reason) {
  final title = formatRejectionTitle(reason);
  if (reason.message.isEmpty) {
    return title;
  }
  return '$title — ${reason.message}';
}

String shortHash(String hash) {
  if (hash.length <= 18) {
    return hash;
  }
  return '${hash.substring(0, 10)}…${hash.substring(hash.length - 6)}';
}
