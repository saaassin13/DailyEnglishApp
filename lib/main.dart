import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/main_screen.dart';
import 'services/word_service.dart';
import 'services/settings_service.dart';
import 'services/study_record_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(create: (_) => StudyRecordService()),
        ChangeNotifierProvider(create: (_) => WordService()),
      ],
      child: MaterialApp(
        title: '每日英语',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const MainScreen(),
      ),
    );
  }
}

