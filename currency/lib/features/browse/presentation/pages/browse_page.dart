import 'package:flutter/material.dart';

class BrowsePage extends StatelessWidget {
  const BrowsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browse')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Browse', style: TextStyle(fontSize: 24)),
              SizedBox(height: 8),
              Text('Currency list will appear here.'),
            ],
          ),
        ),
      ),
    );
  }
}
