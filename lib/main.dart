import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/config/environment.dart';
import 'package:bee_reading/screens/welcome_screen.dart';
import 'package:bee_reading/theme/app_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bee Reading',
      debugShowCheckedModeBanner: Environment.isDevelopment,
      theme: AppTheme.lightTheme,
      home: const WelcomeScreen(),
    );
  }
}
