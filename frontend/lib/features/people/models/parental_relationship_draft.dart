import '../../../core/utils/text_case.dart';

class ParentalRelationshipDraft
{
  final String taxCode;
  final bool authorizedPickup;
  final String? restrictionReason;

  const ParentalRelationshipDraft({
    required this.taxCode,
    this.authorizedPickup = true,
    this.restrictionReason,
  });

  Map<String, dynamic> toJson()
  {
    return {
      'tax_code': taxCode,
      'authorized_pickup': authorizedPickup,
      // Dropped when pickup is allowed: a stale reason must not survive.
      'pickup_restriction_reason':
          authorizedPickup ? null : _shapedReason(restrictionReason),
    };
  }

  static String? _shapedReason(String? reason)
  {
    final String trimmed = (reason ?? '').trim();

    return trimmed.isEmpty ? null : sentenceCase(trimmed);
  }
}