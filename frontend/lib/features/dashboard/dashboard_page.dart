import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ApiService _apiService = ApiService();

  String status = 'Loading...';

  @override
  void initState() {
    super.initState();
    loadHealth();
  }

  Future<void> loadHealth() async {
    try {
      final response = await _apiService.getHealth();

      setState(() {
        status = response.toString();
      });
    } catch (e) {
      setState(() {
        status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Casa Michela Dashboard'),
      ),
      body: Center(
        child: Text(
          status,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
