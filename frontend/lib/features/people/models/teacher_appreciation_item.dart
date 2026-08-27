import '../../../core/utils/json_parsing.dart';
import '../../lessons/models/person_option_item.dart';

class TeacherAppreciationItem
{
  final PersonOptionItem teacher;

  // A request may name three teachers per side, so a period's counts add up to
  // more than its requests.
  final int requestCount;

  const TeacherAppreciationItem({
    required this.teacher,
    required this.requestCount,
  });

  factory TeacherAppreciationItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherAppreciationItem(
      teacher: PersonOptionItem.fromJson(json['teacher'] as Map<String, dynamic>),
      requestCount: json['request_count'] as int,
    );
  }
}

class TeacherAppreciationRankingItem
{
  final List<TeacherAppreciationItem> mostAppreciated;
  final List<TeacherAppreciationItem> leastAppreciated;

  const TeacherAppreciationRankingItem({
    required this.mostAppreciated,
    required this.leastAppreciated,
  });

  factory TeacherAppreciationRankingItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherAppreciationRankingItem(
      mostAppreciated: parseList(json['most_appreciated'], TeacherAppreciationItem.fromJson),
      leastAppreciated: parseList(json['least_appreciated'], TeacherAppreciationItem.fromJson),
    );
  }
}
