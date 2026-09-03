import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 로그인 화면 파일 불러오는 코드
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('access_token', 'mock_test_token_123');

  runApp(const MyApp());
}

// 현관문 역할 및 앱 전체의 기본 설정
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CallPing', // 앱 이름
      theme: ThemeData(scaffoldBackgroundColor: Colors.white),
      // 앱 켜자마자 가장 먼저 띄울 화면
      home: const HomeScreen(),
    );
  }
}
