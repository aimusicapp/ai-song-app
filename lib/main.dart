import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const AiSongApp());
}

class AiSongApp extends StatelessWidget {
  const AiSongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Song',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6C4CE0),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121016),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
