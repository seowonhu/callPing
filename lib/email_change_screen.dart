import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

enum _EmailStep { input, verify, complete }

class EmailChangeScreen extends StatefulWidget {
  const EmailChangeScreen({super.key});

  @override
  State<EmailChangeScreen> createState() => _EmailChangeScreenState();
}

class _EmailChangeScreenState extends State<EmailChangeScreen> {
  final _newEmailController = TextEditingController();
  final _codeController = TextEditingController();

  _EmailStep _step = _EmailStep.input;
  String? _errorText;
  bool _isLoading = false;

  String _currentEmail = '';
  bool _isFetchingEmail = true;

  @override
  void initState() {
    super.initState();
    _fetchCurrentEmail();
  }

  @override
  void dispose() {
    _newEmailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  //  현재 이메일 조회
  // getMe 정의 오류
  Future<void> _fetchCurrentEmail() async {
    try {
      final response = await ApiService.getMe();
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        setState(() {
          _currentEmail = body['data']['email'] ?? '';
        });
      }
    } catch (e) {
      // 조회 실패해도 화면은 그대로 두고, 아래 입력 흐름은 계속 진행 가능
    } finally {
      setState(() {
        _isFetchingEmail = false;
      });
    }
  }

  Future<void> _onSendCode() async {
    if (_newEmailController.text.isEmpty ||
        !_newEmailController.text.contains('@')) {
      setState(() => _errorText = '올바른 이메일 주소를 입력해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final response = await ApiService.sendEmailChangeCode(
        _currentEmail,
        _newEmailController.text,
      );
      final body = jsonDecode(response.body);

      if (body['success'] == true) {
        setState(() {
          _step = _EmailStep.verify;
        });
      } else {
        setState(() {
          _errorText = body['message'] ?? '인증 코드 발송에 실패했습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _errorText = '네트워크 오류가 발생했습니다. 다시 시도해주세요.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ⬅️ 변경: 코드 6자리 입력마다 검증하지 않고, '다음' 버튼에서 한 번에 검증 + 이메일 변경까지 처리
  Future<void> _onVerifyCode() async {
    if (_codeController.text.length != 6) {
      setState(() => _errorText = '6자리 인증 코드를 입력해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final response = await ApiService.verifyEmailChangeCode(
        _codeController.text,
      );
      final body = jsonDecode(response.body);

      if (body['success'] == true) {
        setState(() {
          _step = _EmailStep.complete;
        });
      } else {
        setState(() {
          _errorText = body['message'] ?? '인증 코드가 일치하지 않거나 만료되었습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _errorText = '네트워크 오류가 발생했습니다. 다시 시도해주세요.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = {
      _EmailStep.input: '이메일 변경',
      _EmailStep.verify: '이메일 인증',
      _EmailStep.complete: '이메일 변경 완료',
    };

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          titles[_step]!,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: switch (_step) {
        _EmailStep.input => _buildInputView(),
        _EmailStep.verify => _buildVerifyView(),
        _EmailStep.complete => _buildCompleteView(context),
      },
    );
  }

  // -----------------------------------------------------------
  // 1단계: 새 이메일 입력
  // -----------------------------------------------------------
  Widget _buildInputView() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Text('현재 이메일', style: TextStyle(fontSize: 15)),
            const SizedBox(height: 8),
            Container(
              height: 55,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9D9).withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _isFetchingEmail ? '불러오는 중...' : _currentEmail,
                style: const TextStyle(color: Colors.black54, fontSize: 15),
              ),
            ),
            const SizedBox(height: 20),
            const Text('새 이메일 주소', style: TextStyle(fontSize: 15)),
            const SizedBox(height: 8),
            SizedBox(
              height: 55,
              child: TextField(
                controller: _newEmailController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: '새로운 이메일 주소를 입력하세요',
                  hintStyle: const TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFD9D9D9).withOpacity(0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '새 이메일 주소로 인증 코드가 발송됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF7A7373), fontSize: 15),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
            const Spacer(),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _onSendCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        '다음',
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------
  // 2단계: 인증 코드 입력
  // -----------------------------------------------------------
  Widget _buildVerifyView() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            const Text(
              '인증 코드가 발송되었습니다\n인증 코드를 입력해주세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(fontSize: 28, letterSpacing: 8),
              decoration: const InputDecoration(
                counterText: '',
                border: UnderlineInputBorder(),
              ),
              // ⬅ 삭제: onChanged: (_) => _onVerifyCode() — 매 입력마다 서버 호출하지 않도록 제거
            ),
            if (_errorText != null) ...[
              // ⬅ 변경: _codeVerified 대신 서버 에러 메시지 표시
              const SizedBox(height: 12),
              Text(
                _errorText!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 15),
              ),
            ],
            const Spacer(),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _onVerifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        '다음',
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------
  // 3단계: 완료 화면
  // -----------------------------------------------------------
  Widget _buildCompleteView(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(flex: 2),
            Center(
              child: Container(
                width: 130,
                height: 130,
                decoration: const BoxDecoration(
                  color: Color(0xFF76FFD8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 70, color: Colors.black),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '이메일이 성공적으로 변경되었습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(flex: 3),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
