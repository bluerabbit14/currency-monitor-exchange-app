import 'package:flutter/material.dart';

class FavouritePage extends StatelessWidget {
  const FavouritePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favourites')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Favourites', style: TextStyle(fontSize: 24)),
              SizedBox(height: 8),
              Text('Saved currencies will appear here.'),
            ],
          ),
        ),
      ),
    );
  }
}
