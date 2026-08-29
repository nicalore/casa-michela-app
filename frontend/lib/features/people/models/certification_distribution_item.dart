// Uncertified students are counted under the "Nessuna" label.
class CertificationDistributionItem
{
  final String label;
  final int count;

  const CertificationDistributionItem({required this.label, required this.count});

  factory CertificationDistributionItem.fromJson(Map<String, dynamic> json)
  {
    return CertificationDistributionItem(
      label: json['label'],
      count: json['count'],
    );
  }
}
