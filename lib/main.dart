import 'package:flutter/material.dart';
import 'screens/lab_workspace_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MalariaVisionApp());
}

/// Clinical-grade Flutter application entry point for Malaria Cell Image Segmentation
/// and Handcrafted Feature Classification.
class MalariaVisionApp extends StatelessWidget {
  const MalariaVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MalariaVision Lab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LabWorkspaceScreen(),
    );
  }
}
