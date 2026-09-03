import 'package:flutter/material.dart';

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
  bool _codeVerified = false;

  // 실제로는 서버에서 받아온 값이 들어감
  final String _currentEmail = 'user@email.com';

  @override
  void dispose() {
    _newEmailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onSendCode() {
    if (_newEmailController.text.isEmpty ||
        !_newEmailController.text.contains('@')) {
      setState(() => _errorText = '올바른 이메일 주소를 입력해주세요.');
      return;
    }
    // TODO: 실제 인증 코드 발송 API 연결
    setState(() {
      _errorText = null;
      _step = _EmailStep.verify;
    });
  }

  void _onVerifyCode() {
    // TODO: 실제 인증 코드 검증 API 연결 (임시로 '123456'만 성공 처리)
    if (_codeController.text == '123456') {
      setState(() => _codeVerified = true);
    } else {
      setState(() => _codeVerified = false);
    }
  }

  void _onNextAfterVerify() {
    if (!_codeVerified) {
      setState(() {}); // 에러 문구 표시 트리거
      return;
    }
    setState(() => _step = _EmailStep.complete);
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
                _currentEmail,
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
                onPressed: _onSendCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
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
  // 2단계: 인증 코드 입력 (입력/성공/실패 문구는 상태로 전환)
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
              onChanged: (_) => _onVerifyCode(),
            ),
            const SizedBox(height: 12),
            if (_codeController.text.length == 6)
              Text(
                _codeVerified ? '인증되었습니다' : '인증 코드가 일치하지 않습니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _codeVerified ? Colors.black : Colors.red,
                  fontSize: 15,
                ),
              ),
            const Spacer(),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: _onNextAfterVerify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
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
                  // 계정관리 화면으로 복귀
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
