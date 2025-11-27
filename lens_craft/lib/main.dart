import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lens_craft/core/theme/app_theme.dart';
import 'package:lens_craft/features/home/screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: LensCraftApp()));
}

class LensCraftApp extends StatelessWidget {
  const LensCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LensCraft',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
