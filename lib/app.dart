import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

class TeamFloApp extends StatelessWidget {
  const TeamFloApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeamFloApp',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}