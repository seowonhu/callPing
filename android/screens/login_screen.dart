import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'home_screen.dart';
import 'find_id_screen.dart';
import 'find_pw_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 백엔드 명세서에 맞춘 로그인 함수
  Future<void> _handleLogin() async {
    String inputId = _idController.text.trim();
    String inputPassword = _passwordController.text.trim();

    if (inputId.isEmpty || inputPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아이디와 비밀번호를 입력해주세요!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ⭐️ ApiService를 통한 깔끔한 통신
      final response = await ApiService.login(
        inputId,
        inputPassword,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));

        // 명세서에 따른 데이터 접근
        final data = responseData['data'];
        if (data != null && data['refresh_token'] != null) {
          String token = data['refresh_token']; // 임시로 리프레시 토큰을 액세스 토큰으로 사용

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', token);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        }
      } else if (response.statusCode == 401) {
        _showErrorPopup('비밀번호가 일치하지 않습니다.');
      } else if (response.statusCode == 403) {
        _showErrorPopup('계정이 잠겼습니다. 이메일 인증으로 해제해주세요.');
      } else if (response.statusCode == 404) {
        _showErrorPopup('가입되지 않은 회원 정보입니다.');
      } else {
        _showErrorPopup('로그인에 실패했습니다.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('서버와 연결할 수 없습니다. 다시 시도해주세요.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorPopup(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('로그인 실패'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 47.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'CallPing',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 50,
                    fontFamily: 'Ysabeau SC',
                  ),
                ),
                const SizedBox(height: 60),
                TextField(
                  controller: _idController,
                  decoration: InputDecoration(
                    hintText: '아이디',
                    hintStyle: const TextStyle(color: Colors.black54),
                    filled: true,
                    fillColor: const Color(0xFFD9D9D9).withOpacity(0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: '비밀번호',
                    hintStyle: const TextStyle(color: Colors.black54),
                    filled: true,
                    fillColor: const Color(0xFFD9D9D9).withOpacity(0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Log in',
                            style: TextStyle(color: Colors.white, fontSize: 20),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FindIdScreen(),
                        ),
                      ),
                      child: const Text(
                        '아이디 찾기',
                        style: TextStyle(
                          color: Color(0xFFABABAB),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Text(
                      '  /  ',
                      style: TextStyle(color: Color(0xFFABABAB), fontSize: 12),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FindPwScreen(),
                        ),
                      ),
                      child: const Text(
                        '비밀번호 찾기',
                        style: TextStyle(
                          color: Color(0xFFABABAB),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Text(
                      '  /  ',
                      style: TextStyle(color: Color(0xFFABABAB), fontSize: 12),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpScreen(),
                        ),
                      ),
                      child: const Text(
                        '회원가입',
                        style: TextStyle(
                          color: Color(0xFFABABAB),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
