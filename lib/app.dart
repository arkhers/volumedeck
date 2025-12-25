import 'package:flutter/material.dart';
import 'ui/screens/home_screen.dart';

class DeejGuiApp extends StatelessWidget {
  const DeejGuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deej Config GUI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        visualDensity: VisualDensity.standard,
      ),
      home: const HomeScreen(),
    );
  }
}
