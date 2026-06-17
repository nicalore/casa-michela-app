import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'routing/app_router.dart';
import 'services/api_service.dart';

void main() async 
{
  // Obbligatorio per eseguire codice asincrono prima di runApp
  WidgetsFlutterBinding.ensureInitialized();
  
  // Rimuove il '#' dagli URL
  usePathUrlStrategy();

  // Ripristina la sessione PRIMA di avviare l'interfaccia grafica.
  // Durante questa frazione di secondo, il web mostrerà il loader nativo di index.html
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