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
      'pickup_restriction_reason': authorizedPickup ? null : restrictionReason,
    };
  }
}