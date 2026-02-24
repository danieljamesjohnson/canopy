import 'package:flutter/material.dart';

void main() {
  runApp(const CanopyApp());
}

class CanopyApp extends StatelessWidget {
  const CanopyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Canopy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrangeAccent),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Canopy'),
        ),
      ),
    );
  }
}
