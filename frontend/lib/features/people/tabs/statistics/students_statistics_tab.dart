import 'package:flutter/material.dart';
import 'role_specific_statistics_view.dart';

class StudentsStatisticsTab extends StatelessWidget 
{
  const StudentsStatisticsTab({super.key});

  @override
  Widget build(BuildContext context) 
  {
    return const RoleSpecificStatisticsView(roleKey: 'student');
  }
}