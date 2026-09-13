import 'package:flutter/material.dart';

import '../../core/constants/app_dimensions.dart';
import '../../shared/widgets/app_page_container.dart';
import 'widgets/role_home_layout.dart';

class RoleHomePage extends StatelessWidget
{
  final String role;

  const RoleHomePage({super.key, required this.role});

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        minHeight: AppDimensions.minDashboardHeight,
        builder: (context, width, height) => RoleHomeLayout(
          role: role,
          width: width,
          height: height,
        ),
      ),
    );
  }
}
