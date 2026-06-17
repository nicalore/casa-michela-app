import 'package:flutter/material.dart';

class SplashPage extends StatelessWidget 
{
  const SplashPage({super.key});

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