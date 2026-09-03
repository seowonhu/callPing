import 'package:flutter/material.dart';

class PermissionSettingScreen extends StatefulWidget {
  // 추가: Stateless → Stateful
  const PermissionSettingScreen({super.key});

  @override
  State<PermissionSettingScreen> createState() =>
      _PermissionSettingScreenState(); // ⬅️ 추가
}

class _PermissionSettingScreenState extends State<PermissionSettingScreen> {
  // 추가: 토글 상태를 저장할 변수 두 개
  bool _fileUploadEnabled = false;
  bool _pushNotificationEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '권한 설정',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                _buildSettingItem(
                  title: '파일 업로드 권한',
                  value: _fileUploadEnabled, // ⬅️ 추가
                  onChanged: (value) {
                    // ⬅️ 추가
                    setState(() {
                      _fileUploadEnabled = value;
                    });
                    // TODO: 실제 파일 업로드 권한 요청/해제 로직
                  },
                ),
                _buildSettingItem(
                  title: '푸시 알림 권한',
                  value: _pushNotificationEnabled, // ⬅️ 추가
                  onChanged: (value) {
                    // ⬅️ 추가
                    setState(() {
                      _pushNotificationEnabled = value;
                    });
                    // TODO: 실제 푸시 알림 권한 요청/해제 로직
                  },
                ),
              ],
            ),
          ),
          _buildBottomNavigationBar(),
        ],
      ),
    );
  }

  // ⬅️ 변경: onTap(VoidCallback) 대신 value + onChanged로 교체
  Widget _buildSettingItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween, // ⬅️ 추가: 제목-토글 양끝 정렬
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Switch(
                // ⬅️ 추가: 토글 스위치
                value: value,
                onChanged: onChanged,
                activeColor: const Color(0xFF1A9000), // 콜핑 포인트 컬러(설정 탭 선택색)와 통일
              ),
            ],
          ),
        ),
        const Divider(color: Colors.black12, height: 1, thickness: 1),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.black12, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            iconPath: 'assets/home.png',
            label: '콜핑',
            isSelected: false,
          ),
          _buildNavItem(
            iconPath: 'assets/chat.png',
            label: '챗봇',
            isSelected: false,
          ),
          _buildNavItem(
            iconPath: 'assets/analytic.png',
            label: '분석',
            isSelected: false,
          ),
          _buildNavItem(
            iconPath: 'assets/setting.png',
            label: '설정',
            isSelected: true,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required String iconPath,
    required String label,
    required bool isSelected,
  }) {
    final color = isSelected ? const Color(0xFF1A9000) : Colors.black;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          iconPath,
          width: 24,
          height: 24,
          color: color,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.settings, color: color, size: 24),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
