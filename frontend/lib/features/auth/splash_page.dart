import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';

class SplashPage extends StatefulWidget
{
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
{
  final ApiService _apiService = ApiService();

  @override
  void initState()
  {
    super.initState();
    
    //StartInitialization
    _bootstrap();
  }

  Future<void> _bootstrap() async
  {
    try
    {
      //RestoreSessionState
      final restored = await _apiService.restoreSession();
      
      if (!mounted)
      {
        return;
      }

      if (restored)
      {
        context.go('/dashboard');
      } 
      else
      {
        context.go('/login');
      }
    } 
    catch (_)
    {
      if (!mounted)
      {
        return;
      }

      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return const Scaffold(
      backgroundColor: Color(0xFFF4F7F9),
      body: Center(
        child: SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            color: Color(0xFF003C82),
          ),
        ),
      ),
    );
  }
}