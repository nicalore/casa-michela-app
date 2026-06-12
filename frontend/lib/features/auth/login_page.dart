import 'package:flutter/material.dart';

import '../../shared/widgets/app_page_container.dart';
import 'widgets/login_layout.dart';

class LoginPage extends StatelessWidget
{
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: AppPageContainer(
        minWidth: 1440,
        minHeight: 990,
        builder: (context, width, height)
        {
          return LoginLayout(
            width: width,
            height: height,
          );
        },
      ),
    );
  }
}