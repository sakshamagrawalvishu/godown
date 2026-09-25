import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Entry screen while [AuthProvider.bootstrap] checks the stored token.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) => const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warehouse, size: 64),
              SizedBox(height: 16),
              Text('Godown Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
