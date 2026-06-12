import 'package:flutter/material.dart';

import 'routing/app_router.dart';

void main() {
  runApp(const CasaMichelaApp());
}

class CasaMichelaApp extends StatelessWidget {
  const CasaMichelaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Casa Michela',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}