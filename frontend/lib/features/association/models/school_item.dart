class SchoolItem {
  final String mechanographicCode;
  final String name;
  final String city;
  final String province;

  const SchoolItem({
    required this.mechanographicCode,
    required this.name,
    required this.city,
    required this.province,
  });

  bool get isPrivate => mechanographicCode.startsWith('PRIV-');
}
