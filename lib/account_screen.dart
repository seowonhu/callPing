import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'pw_change_screen.dart';
import 'email_change_screen.dart';
// import 'constants.dart';
import 'api_service.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '계정 관리',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MenuItem(
              title: '비밀번호 변경',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PwChangeScreen(),
                  ),
                );
              },
            ),
            _MenuItem(
              title: '이메일 변경',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmailChangeScreen(),
                  ),
                );
              },
            ),
            _MenuItem(title: '로그아웃', onTap: () => _showLogoutDialog(context)),
            _MenuItem(
              title: '탈퇴하기',
              onTap: () => _showWithdrawalDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------
  // 로그아웃 팝업
  // -----------------------------------------------------------
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            width: 330,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFE4E2E2),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFF7A7373), width: 3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '로그아웃하시겠어요?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '언제든 다시 로그인하여\n서비스를 이용할 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          '취소',
                          style: TextStyle(color: Colors.black, fontSize: 14),
                        ),
                      ),
                    ),
                    Container(
                      width: 3,
                      height: 26,
                      color: const Color(0xFF7A7373),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          // 1. 서버에 로그아웃 요청 (API 연동)
                          try {
                            await ApiService.logout();

                            // 2. 폰에 저장해둔 토큰 삭제
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('access_token');
                          } catch (e) {
                            print("로그아웃 통신 에러: $e");
                          }

                          // 3. 팝업 포함 모든 스택 지우고 LoginScreen으로 이동
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                          }
                        },

                        child: const Text(
                          '로그아웃',
                          style: TextStyle(
                            color: Color(0xFFFF0000),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // -----------------------------------------------------------
  // 탈퇴하기 팝업 (체크박스)
  // -----------------------------------------------------------
  void _showWithdrawalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _WithdrawalDialog(),
    );
  }
}

// -----------------------------------------------------------
// 메뉴 아이템 한 줄 (제목 + 구분선)
// -----------------------------------------------------------
class _MenuItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _MenuItem({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: Colors.black12),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// 탈퇴하기 팝업 위젯
// -----------------------------------------------------------
class _WithdrawalDialog extends StatefulWidget {
  const _WithdrawalDialog();

  @override
  State<_WithdrawalDialog> createState() => _WithdrawalDialogState();
}

class _WithdrawalDialogState extends State<_WithdrawalDialog> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        width: 330,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFE4E2E2),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF7A7373), width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '탈퇴하시겠어요?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '탈퇴 시 계정과 모든 데이터가\n영구적으로 삭제되며 복구할 수 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Checkbox(
                  value: _agreed,
                  activeColor: const Color(0xFF00AA77),
                  onChanged: (value) {
                    setState(() {
                      _agreed = value ?? false;
                    });
                  },
                ),
                const Text(
                  '정말 탈퇴하시겠습니까?',
                  style: TextStyle(color: Colors.black, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '취소',
                      style: TextStyle(color: Colors.black, fontSize: 14),
                    ),
                  ),
                ),
                Container(width: 3, height: 26, color: const Color(0xFF7A7373)),
                Expanded(
                  child: TextButton(
                    // 체크 안 하면 비활성화
                    onPressed: _agreed
                        ? () async {
                            // 1. 서버에 회원 탈퇴 요청 보내기 (API 연동)
                            try {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              final token =
                                  prefs.getString('access_token') ?? '';

                              // 백엔드 회원 탈퇴 API 주소 (예: DELETE /users 등 명세서에 맞게 수정)
                              final response = await http.delete(
                                Uri.parse(
                                  'http://localhost:8080/api/v1/users/me/account',
                                ), // 백엔드 탈퇴 주소 확인 필요
                                headers: {
                                  'Content-Type': 'application/json',
                                  'Authorization': 'Bearer $token',
                                },
                              );

                              // 서버가 200 성공 응답을 줬을 때
                              if (response.statusCode == 200) {
                                // 폰에 저장된 토큰 삭제
                                await prefs.remove('access_token');

                                // 팝업 닫고 로그인 화면으로 이동
                                if (context.mounted) {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LoginScreen(),
                                    ),
                                    (route) => false,
                                  );
                                }
                              } else {
                                // 실패했을 때 처리
                                print("탈퇴 실패");
                              }
                            } catch (e) {
                              print("회원 탈퇴 통신 에러");
                            }
                          }
                        : null,

                    child: Text(
                      '탈퇴하기',
                      style: TextStyle(
                        color: _agreed
                            ? const Color(0xFFFF0000)
                            : const Color(0xFFFF0000).withOpacity(0.4),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
