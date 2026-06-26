import 'package:flutter/material.dart';
import 'role_specific_statistics_view.dart';

class CourseParticipantsStatisticsTab extends StatelessWidget 
{
  const CourseParticipantsStatisticsTab({super.key});

  @override
  Widget build(BuildContext context) 
  {
    return const RoleSpecificStatisticsView(roleKey: 'course_participant');
  }
}