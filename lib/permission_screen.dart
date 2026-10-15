import 'dart:convert';
import 'package:flutter/material.dart';
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

  // ⬅️ 추가: 현재 권한 상태 조회
  Future<void> _fetchPermissions() async {
    try {
      final response = await ApiService.getPermissions();
      final body = jsonDecode(response.body);

      if (body['success'] == true) {
        setState(() {
          _fileUploadEnabled = body['data']['file_upload_permission'] ?? false;
          _pushNotificationEnabled =
              body['data']['push_notification_permission'] ?? false;
        });
      }
    } catch (e) {
      // 조회 실패해도 기본값(false)으로 화면은 그대로 표시
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ⬅️ 추가: 토글 시 서버에 반영
  Future<void> _updatePermissions() async {
    try {
      final response = await ApiService.updatePermissions(
        fileUploadPermission: _fileUploadEnabled,
        pushNotificationPermission: _pushNotificationEnabled,
      );
      final body = jsonDecode(response.body);

      if (body['success'] != true) {
        // 서버 반영 실패 시 토글을 원래 상태로 되돌림
        _showUpdateFailedSnackBar(body['message'] ?? '설정 변경에 실패했습니다.');
      }
    } catch (e) {
      _showUpdateFailedSnackBar('네트워크 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  void _showUpdateFailedSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    children: [
                      _buildSettingItem(
                        title: '파일 업로드 권한',
                        value: _fileUploadEnabled,
                        onChanged: (value) {
                          setState(() {
                            _fileUploadEnabled = value;
                          });
                          _updatePermissions();
                        },
                      ),
                      _buildSettingItem(
                        title: '푸시 알림 권한',
                        value: _pushNotificationEnabled,
                        onChanged: (value) {
                          setState(() {
                            _pushNotificationEnabled = value;
                          });
                          _updatePermissions();
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
