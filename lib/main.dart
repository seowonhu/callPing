import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
// 로그인 화면 파일 불러오는 코드
import 'login_screen.dart';

void main() async {
  // 앱 화면 켜기 전에 엔진부터 켜기 위함
  WidgetsFlutterBinding.ensureInitialized();

  // firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

// 현관문 역할 및 앱 전체의 기본 설정
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 화면 오른쪽 위 거슬리는 'DEBUG' 빨간 띠 없애기
      title: 'CallPing', // 앱 이름
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white, // 앱 전체 기본 배경색은 하얀색
      ),
      // 앱 켜자마자 가장 먼저 띄울 화면 지정
      home: const LoginScreen(),
    );
  }
}
