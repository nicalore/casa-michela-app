import 'package:flutter/material.dart';

import 'widgets/login_layout.dart';

class LoginPage extends StatelessWidget
{
  const LoginPage({super.key});

  // The page is the pill stack itself: it needs no container to give it a
  // minimum size, because the stack shrinks on its own and scrolls when the
  // window cannot hold it.
  @override
  Widget build(BuildContext context) => const LoginLayout();
}
