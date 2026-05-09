import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const DriverWatchApp());
}

class DriverWatchApp extends StatelessWidget {
  const DriverWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DriverWatch - TCC',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}