import 'package:flutter/material.dart';

import '../../core/constants/app_dimensions.dart';
import '../../shared/widgets/app_page_container.dart';
import 'widgets/onboarding_layout.dart';

class OnboardingPage extends StatelessWidget
{
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        // The page is the window: the step scrolls, its buttons stay in sight.
        minHeight: 0,
        builder: (context, width, height) => OnboardingLayout(width: width, height: height),
      ),
    );
  }
}
