import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'workbench/workbench_page.dart';

void main() {
  runApp(const DeepSshApp());
}

class DeepSshApp extends StatelessWidget {
  const DeepSshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DeepSSH',
      theme: AppTheme.dark(),
      home: const WorkbenchPage(),
    );
  }
}
