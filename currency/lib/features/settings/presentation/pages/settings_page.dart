import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Settings', style: TextStyle(fontSize: 24)),
              SizedBox(height: 8),
              Text('App preferences will appear here.'),
            ],
          ),
        ),
      ),
    );
  }
}
