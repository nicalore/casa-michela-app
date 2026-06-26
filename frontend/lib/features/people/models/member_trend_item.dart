class MemberTrendItem 
{
  final int  year;
  final int? month;
  final int  totalMembers;

  MemberTrendItem({
    required this.year,
    this.month,
    required this.totalMembers,
  });

  factory MemberTrendItem.fromJson(Map<String, dynamic> json) 
  {
    return MemberTrendItem(
      year:         json['year'],
      month:        json['month'],
      totalMembers: json['total_members'],
    );
  }
}