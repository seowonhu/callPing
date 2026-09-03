import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

class PermissionSettingScreen extends StatefulWidget {
  const PermissionSettingScreen({super.key});

  @override
  State<PermissionSettingScreen> createState() =>
      _PermissionSettingScreenState();
}

class _PermissionSettingScreenState extends State<PermissionSettingScreen> {
  bool _fileUploadEnabled = false;
  bool _pushNotificationEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPermissions();
  }

  // 1. 초기 권한 상태 불러오기
  Future<void> _fetchPermissions() async {
    try {
      final response = await ApiService.getPermissions();
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes))['data'];
        setState(() {
          _fileUploadEnabled = data['file_upload_permission'] ?? false;
          _pushNotificationEnabled =
              data['push_notification_permission'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // 2. 권한 변경 사항을 서버에 저장
  Future<void> _updateServerPermissions(
    bool fileEnabled,
    bool pushEnabled,
  ) async {
    try {
      await ApiService.updatePermissions(fileEnabled, pushEnabled);
    } catch (e) {
      print("권한 업데이트 실패: $e");
    }
  }

  // 3. 푸시 알림 토글 시 OS 팝업 및 FCM 토큰 전송 로직
  Future<void> _togglePushNotification(bool value) async {
    if (value) {
      // 켜기: OS 네이티브 팝업 요청
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // 권한 허용됨 -> 서버에 권한 true 업데이트
        setState(() => _pushNotificationEnabled = true);
        _updateServerPermissions(_fileUploadEnabled, true);

        // FCM 토큰 추출 및 전송
        String? token = await messaging.getToken();
        if (token != null) {
          await ApiService.updateFcmToken(token);
        }
      } else {
        // 권한 거부됨 -> 스위치 원상복구
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('기기 설정에서 푸시 알림 권한을 허용해주세요.')),
          );
        }
      }
    } else {
      // 끄기: 서버에 권한 false 업데이트
      setState(() => _pushNotificationEnabled = false);
      _updateServerPermissions(_fileUploadEnabled, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                  value: _fileUploadEnabled,
                  onChanged: (value) {
                    setState(() => _fileUploadEnabled = value);
                    _updateServerPermissions(value, _pushNotificationEnabled);
                  },
                ),
                _buildSettingItem(
                  title: '푸시 알림 권한',
                  value: _pushNotificationEnabled,
                  onChanged: _togglePushNotification,
                ),
              ],
            ),
          ),
          _buildBottomNavigationBar(),
        ],
      ),
    );
  }

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                value: value,
                onChanged: onChanged,
                activeColor: const Color(0xFF1A9000),
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
