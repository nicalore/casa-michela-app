import 'package:flutter/material.dart';

import '../../core/constants/app_dimensions.dart';
import '../../shared/widgets/app_page_container.dart';
import 'widgets/dashboard_layout.dart';

class DashboardPage extends StatelessWidget
{
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        minHeight: AppDimensions.minDashboardHeight,
        builder: (context, width, height) => DashboardLayout(width: width, height: height),
      ),
    );
  }
}