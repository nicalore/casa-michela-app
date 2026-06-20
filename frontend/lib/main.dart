import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'routing/app_router.dart';
import 'services/api_service.dart';

void main() async 
{
  WidgetsFlutterBinding.ensureInitialized();
  
  usePathUrlStrategy();
  await ApiService().restoreSession();

  runApp(const CasaMichelaApp());
}

class CasaMichelaApp extends StatelessWidget 
{
  const CasaMichelaApp({super.key});

  @override
  Widget build(BuildContext context) 
  {
    return MaterialApp.router(
      title: 'Casa Michela',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}