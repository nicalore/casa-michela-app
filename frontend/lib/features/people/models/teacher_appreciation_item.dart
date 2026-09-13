import '../../../core/utils/json_parsing.dart';
import '../../lessons/models/person_option_item.dart';

class TeacherAppreciationItem
{
  final PersonOptionItem teacher;

  // Each pupil weighs at most a hundred either way, however often they come.
  final int score;
  final int preferringStudentCount;
  final int avoidingStudentCount;

  const TeacherAppreciationItem({
    required this.teacher,
    required this.score,
    required this.preferringStudentCount,
    required this.avoidingStudentCount,
  });

  factory TeacherAppreciationItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherAppreciationItem(
      teacher: PersonOptionItem.fromJson(json['teacher'] as Map<String, dynamic>),
      score: json['score'] as int,
      preferringStudentCount: json['preferring_student_count'] as int,
      avoidingStudentCount: json['avoiding_student_count'] as int,
    );
  }
}

// Everyone with a signal in the period, best first.
class TeacherAppreciationRankingItem
{
  final List<TeacherAppreciationItem> ranking;

  const TeacherAppreciationRankingItem({required this.ranking});

  factory TeacherAppreciationRankingItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherAppreciationRankingItem(
      ranking: parseList(json['ranking'], TeacherAppreciationItem.fromJson),
    );
  }
}
