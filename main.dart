import 'features/auth/presentation/auth_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'School Violation Detector',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff0b3b7a)),
      inputDecorationTheme: const InputDecorationTheme(isDense: true),
    ),
    home: const AuthScreen(),
    routes: {
      '/auth': (_) => const AuthScreen(),
      '/student/home': (_) => const DashboardScreen(),
      '/teacher/dashboard': (_) => const DashboardScreen(),
    },
  );
}
