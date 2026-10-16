import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
// 백엔드 명세서 생기면 주석 처리 해제
import 'api_service.dart';
// 로그인 화면 파일 불러오는 코드
import 'login_screen.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("백그라운드에서 메시지 받음: ${message.messageId}");
}

void main() async {
  // 앱 화면 켜기 전에 엔진부터 켜기 위함
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 파이어베이스 초기화

  // 백그라운드 핸들러는 앱 시작할 때 미리 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 1. 멈춤 현상(흰 화면) 방지를 위해 앱 화면부터 켜기
  runApp(const MyApp());

  // 2. 화면 켜진 뒤에 백그라운드에서 알림 설정 진행하도록 별도로 실행
  _setupFCM();
}

// 앱 실행 속도를 늦추지 않도록 밖으로 빼낸 FCM 푸시 알림 권한 설정 함수
Future<void> _setupFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  // 사용자에게 푸시 알림 허용창 띄우기
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // 토큰 발급 및 서버 전송 (네트워크 지연 발생해도 흰 화면 X)
  final String? fcmToken = await messaging.getToken();

  if (fcmToken != null && fcmToken.isNotEmpty) {
    debugPrint('FCM 토큰 발급 완료');

    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');

    if (accessToken != null && accessToken.isNotEmpty) {
      try {
        await ApiService.updateFcmToken(fcmToken);
        debugPrint('FCM 토큰 서버 등록 완료');
      } catch (e) {
        debugPrint('FCM 토큰 서버 등록 실패: $e');
      }
    } else {
      debugPrint('로그인 전이므로 FCM 토큰 서버 등록을 건너뜁니다.');
    }
  }

  // 3. 앱을 켜놓고 사용 중일 때(Foreground) 알림이 오면 화면 상단에 팝업 띄움
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.notification!.title ?? '알림',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(message.notification!.body ?? ''),
            ],
          ),
          behavior: SnackBarBehavior.floating, // 화면 위에 뜨는 형태
          margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
          backgroundColor: Colors.black87,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  });
}

// 현관문 역할 및 앱 전체의 기본 설정
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // 폰 저장소에 토큰 남아있는지 확인
  Future<bool> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return token.isNotEmpty; // 토큰이 있으면 true(통과), 없으면 false(막음)
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey, // 어느 화면에서든 팝업 띄우는 마스터키
      debugShowCheckedModeBanner: false, // 'DEBUG' 빨간 띠 없애기
      title: 'CallPing',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white, // 앱 전체 기본 배경색은 하얀색
      ),
      // 앱 켜자마자 가장 먼저 띄울 화면 지정
      home: FutureBuilder<bool>(
        future: _checkLoginStatus(),
        builder: (context, snapshot) {
          // 검사하는 짧은 시간 동안은 하얀 빈 화면
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(backgroundColor: Colors.white);
          }

          // 토큰 있으면 홈화면
          if (snapshot.data == true) {
            return const HomeScreen();
          }
          //토큰 없거나 로그아웃 했으면 로그인 화면
          else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
