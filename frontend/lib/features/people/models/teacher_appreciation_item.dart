import '../../../core/utils/json_parsing.dart';
import '../../lessons/models/person_option_item.dart';

// One place of a ranking: who was named, and by how many requests.
//
// The teacher travels as the same minimal person every picker and every
// availability carries, so the circle beside the name is drawn by the same
// widget here as everywhere else.
class TeacherAppreciationItem
{
  final PersonOptionItem teacher;

  // A request may name three teachers on each side, so the counts of a period
  // add up to more than the requests that period holds.
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

// The two ends of the same question, asked of one period: who the pupils asked
// for, and who they asked to be spared.
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
