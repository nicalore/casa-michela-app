import 'package:flutter/material.dart';
import 'role_specific_statistics_view.dart';

class PsychologistsStatisticsTab extends StatelessWidget 
{
  const PsychologistsStatisticsTab({super.key});

  @override
  Widget build(BuildContext context) 
  {
    return const RoleSpecificStatisticsView(roleKey: 'psychologist');
  }
}