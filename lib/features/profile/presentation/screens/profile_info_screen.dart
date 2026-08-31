import 'package:flutter/material.dart';

/// One reusable static-content screen for Help & Support, Terms &
/// Conditions, and Privacy Policy — a title and a body paragraph is all
/// this milestone establishes; no external legal/backend infrastructure.
class ProfileInfoScreen extends StatelessWidget {
  const ProfileInfoScreen({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(body, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
    );
  }
}
