import 'package:flutter/material.dart';
import 'role_specific_statistics_view.dart';

class TeachersStatisticsTab extends StatelessWidget 
{
  const TeachersStatisticsTab({super.key});

  @override
  Widget build(BuildContext context) 
  {
    return const RoleSpecificStatisticsView(roleKey: 'teacher');
  }
}