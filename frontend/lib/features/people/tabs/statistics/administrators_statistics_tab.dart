import 'package:flutter/material.dart';
import 'role_specific_statistics_view.dart';

class AdministratorsStatisticsTab extends StatelessWidget 
{
  const AdministratorsStatisticsTab({super.key});

  @override
  Widget build(BuildContext context) 
  {
    return const RoleSpecificStatisticsView(roleKey: 'administrator');
  }
}