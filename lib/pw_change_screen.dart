import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

class PwChangeScreen extends StatefulWidget {
  const PwChangeScreen({super.key});

  @override
  State<PwChangeScreen> createState() => _PwChangeScreenState();
}

class _PwChangeScreenState extends State<PwChangeScreen> {
  final _currentPwController = TextEditingController();
  final _newPwController = TextEditingController();
  final _confirmPwController = TextEditingController();

  bool _isComplete = false; // false: 입력 화면, true: 완료 화면
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _currentPwController.dispose();
    _newPwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_currentPwController.text.isEmpty ||
        _newPwController.text.isEmpty ||
        _confirmPwController.text.isEmpty) {
      setState(() => _errorText = '모든 항목을 입력해주세요.');
      return;
    }
    if (_newPwController.text != _confirmPwController.text) {
      setState(() => _errorText = '새 비밀번호가 일치하지 않습니다.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final response = await ApiService.changePassword(
        _currentPwController.text,
        _newPwController.text,
      );
      final body = jsonDecode(response.body);

      if (body['success'] == true) {
        setState(() {
          _isComplete = true;
        });
      } else {
        setState(() {
          _errorText = body['message'] ?? '비밀번호 변경에 실패했습니다.';
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _isComplete ? '비밀번호 변경 완료' : '비밀번호 재설정',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isComplete ? _buildCompleteView(context) : _buildInputView(),
    );
  }

  // -----------------------------------------------------------
  // 입력 화면
  // -----------------------------------------------------------
  Widget _buildInputView() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            _PwField(controller: _currentPwController, hintText: '현재 비밀번호 입력'),
            const SizedBox(height: 16),
            _PwField(controller: _newPwController, hintText: '새로운 비밀번호'),
            const SizedBox(height: 8),
            const Text(
              '비밀번호 형식 : 8~16자의 영문 대소문자, 숫자, 특수문자',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B6868), fontSize: 11),
            ),
            const SizedBox(height: 4),
            const Text(
              '사용 가능한 특수문자 : ! " # \$ % & \' ( ) * + , - . / : ; < = > ? @ [ ₩ ] ^ _ ` { | } ~',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B6868), fontSize: 9),
            ),
            const SizedBox(height: 16),
            _PwField(controller: _confirmPwController, hintText: '새 비밀번호 확인'),
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
                onPressed: _isLoading ? null : _onSubmit,
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
  // 완료 화면
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
              '비밀번호가 성공적으로 변경되었습니다.',
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

// -----------------------------------------------------------
// 비밀번호 입력창 공통 위젯
// -----------------------------------------------------------
class _PwField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const _PwField({required this.controller, required this.hintText});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 55,
      child: TextField(
        controller: controller,
        obscureText: true,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.black54, fontSize: 15),
          filled: true,
          fillColor: const Color(0xFFD9D9D9).withOpacity(0.4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
