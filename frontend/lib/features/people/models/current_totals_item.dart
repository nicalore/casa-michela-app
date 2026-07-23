import '../../../core/utils/json_parsing.dart';

class CurrentTotalsItem
{
  final int currentTotalMembers;
  final int membersDeltaMonth;
  final int membersDeltaYear;
  final int currentActiveCollaborators;
  final int collabDeltaMonth;
  final int collabDeltaYear;
  final double? percentageOfTotalMembers;
  final double? percentageOfTotalCollaborators;

  const CurrentTotalsItem({
    required this.currentTotalMembers,
    required this.membersDeltaMonth,
    required this.membersDeltaYear,
    required this.currentActiveCollaborators,
    required this.collabDeltaMonth,
    required this.collabDeltaYear,
    this.percentageOfTotalMembers,
    this.percentageOfTotalCollaborators,
  });

  factory CurrentTotalsItem.fromJson(Map<String, dynamic> json)
  {
    return CurrentTotalsItem(
      currentTotalMembers: json['current_total_members'],
      membersDeltaMonth: json['members_delta_month'],
      membersDeltaYear: json['members_delta_year'],
      currentActiveCollaborators: json['current_active_collaborators'],
      collabDeltaMonth: json['collab_delta_month'],
      collabDeltaYear: json['collab_delta_year'],
      percentageOfTotalMembers: parseOptionalDouble(json['percentage_of_total_members']),
      percentageOfTotalCollaborators: parseOptionalDouble(json['percentage_of_total_collaborators']),
    );
  }
}