import 'package:flutter/material.dart';
import 'account_screen.dart';
import 'permission_screen.dart';
import 'terms_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                'ab****님 , 안녕하세요!',
                style: TextStyle(
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
                // 계정 관리 클릭 시 계정 관리 화면으로 이동
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
