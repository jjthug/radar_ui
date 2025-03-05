import 'package:flutter/material.dart';
import 'package:radar_ui/pages/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget { // Use StatelessWidget here if you do not need state.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp( // This is the crucial part
      title: 'My App',
      home: LoginScreen(), // Or whatever your initial screen is
    );
  }
}
