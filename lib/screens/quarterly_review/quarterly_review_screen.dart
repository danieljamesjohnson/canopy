import 'package:flutter/material.dart';

class QuarterlyReviewScreen extends StatelessWidget {
  const QuarterlyReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quarterly Review')),
      body: const Center(child: Text('Quarterly Review — coming in Phase 5')),
    );
  }
}
