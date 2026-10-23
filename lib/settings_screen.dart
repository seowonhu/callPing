import 'dart:convert';
import 'package:flutter/material.dart';
import 'account_screen.dart';
import 'permission_screen.dart';
import 'terms_screen.dart';
import 'api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _greetingName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo(); 
  }

  // 추가: 내 정보 조회 + 아이디 마스킹
  // getMe 오류
  Future<void> _fetchUserInfo() async {
    try {
      final response = await ApiService.getMe();
      final body = jsonDecode(response.body);

      if (body['success'] == true) {
        final loginId = body['data']['login_id'] as String? ?? '';
        setState(() {
          _greetingName = _maskLoginId(loginId);
        });
      }
    } catch (e) {
      // 조회 실패해도 화면은 그대로 표시 (인사말만 비어있게)
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 추가: 앞 2글자만 보여주고 나머지는 **** 처리
  String _maskLoginId(String loginId) {
    if (loginId.length <= 2) return '$loginId****';
    return '${loginId.substring(0, 2)}****';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '설정',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          children: [
            // 사용자 인사말
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                _isLoading ? '불러오는 중...' : '$_greetingName님 , 안녕하세요!',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 계정 관리
            _buildSettingItem(
              title: '계정 관리',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AccountScreen(),
                  ),
                );
              },
            ),
            const Divider(color: Colors.black, thickness: 1),
            // 권한 설정
            _buildSettingItem(
              title: '권한 설정',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PermissionSettingScreen(),
                  ),
                );
              },
            ),
            const Divider(color: Colors.black, thickness: 1),

            // 약관 보기
            _buildSettingItem(
              title: '약관 보기',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TermsScreen()),
                );
              },
            ),
            const Divider(color: Colors.black, thickness: 1),
          ],
        ),
      ),
    );
  }

  // 설정 메뉴 아이템 위젯
  Widget _buildSettingItem({
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
