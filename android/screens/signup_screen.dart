import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart'; 
import 'terms_screen.dart'; // 약관 화면 임포트 주의 (해당 파일 분리되어 있다면)

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController emailCodeController = TextEditingController();
  final TextEditingController idController = TextEditingController();
  final TextEditingController pwController = TextEditingController();
  final TextEditingController pwConfirmController = TextEditingController();

  bool emailCodeSent = false;
  bool emailVerified = false;
  bool idChecked = false;
  bool agreedToTerms = false;

  bool showPwFormatError = false;
  bool showPwMismatchError = false;

  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    emailCodeController.dispose();
    idController.dispose();
    pwController.dispose();
    pwConfirmController.dispose();
    super.dispose();
  }

  // 1. 이메일 인증 코드 발송 API 연동
  Future<void> sendEmailCode() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('이메일을 입력해주세요.', Colors.redAccent);
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.sendSignupEmailCode(email);
      if (response.statusCode == 200) {
        setState(() {
          emailCodeSent = true;
          emailVerified = false;
        });
        _showSnackBar('인증 코드가 발송되었습니다.', Colors.green);
      } else {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _showSnackBar(data['message'] ?? '이메일 발송 실패', Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar('통신 에러가 발생했습니다.', Colors.redAccent);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 2. 이메일 인증 코드 검증 API 연동
  Future<void> verifyEmailCode() async {
    if (!emailCodeSent) return;
    
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.verifySignupEmailCode(
        emailController.text.trim(),
        emailCodeController.text.trim(),
      );
      if (response.statusCode == 200) {
        setState(() => emailVerified = true);
        _showSnackBar('인증되었습니다.', Colors.green);
      } else {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _showSnackBar(data['message'] ?? '인증 코드가 일치하지 않습니다.', Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar('통신 에러가 발생했습니다.', Colors.redAccent);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isValidId(String id) {
    return RegExp(r'^[a-z0-9]{5,20}$').hasMatch(id);
  }

  // 3. 아이디 중복확인 API 연동
  Future<void> checkIdDuplicate() async {
    final String id = idController.text.trim();
    if (!_isValidId(id)) {
      setState(() => idChecked = false);
      _showSnackBar('아이디 형식에 맞게 입력해주세요.', Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.checkId(id);
      if (response.statusCode == 200) {
        setState(() => idChecked = true);
        _showSnackBar('사용 가능한 아이디입니다.', Colors.green);
      } else {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() => idChecked = false);
        _showSnackBar(data['message'] ?? '이미 사용 중인 아이디입니다.', Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar('통신 에러가 발생했습니다.', Colors.redAccent);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isValidPassword(String pw) {
    if (pw.length < 8 || pw.length > 16) return false;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(pw);
    final hasDigit = RegExp(r'[0-9]').hasMatch(pw);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(pw);
    return hasLetter && hasDigit && hasSpecial;
  }

  void onPasswordChanged(String _) {
    setState(() {
      showPwFormatError = pwController.text.isNotEmpty && !_isValidPassword(pwController.text);
      showPwMismatchError = pwConfirmController.text.isNotEmpty &&
          pwConfirmController.text != pwController.text;
    });
  }

  Future<void> openTermsScreen() async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const TermsScreen()), // 기존 TermsScreen 활용
    );
    if (result == true) {
      setState(() => agreedToTerms = true);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // 4. 최종 가입하기 API 연동
  Future<void> submitSignUp() async {
    if (!emailVerified) {
      _showSnackBar('이메일 인증을 완료해주세요.', Colors.redAccent);
      return;
    }
    if (!idChecked) {
      _showSnackBar('아이디 중복확인을 해주세요.', Colors.redAccent);
      return;
    }
    if (!_isValidPassword(pwController.text)) {
      setState(() => showPwFormatError = true);
      return;
    }
    if (pwController.text != pwConfirmController.text) {
      setState(() => showPwMismatchError = true);
      return;
    }
    if (!agreedToTerms) {
      _showSnackBar('약관에 동의해주세요.', Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.signup(
        idController.text.trim(),
        pwController.text,
        emailController.text.trim(),
      );

      if (response.statusCode == 201) { // 201 Created 성공[cite: 1]
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const _SignUpDoneScreen()),
          );
        }
      } else {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _showSnackBar(data['message'] ?? '회원가입에 실패했습니다.', Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar('서버 연결 실패', Colors.redAccent);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI 코드는 기존 구조를 100% 동일하게 유지합니다.
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 47),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text(
                  '회원가입',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: '이메일 계정',
                          hintStyle: const TextStyle(color: Colors.black54, fontSize: 15),
                          filled: true,
                          fillColor: const Color(0xFFD9D9D9).withOpacity(0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 54,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : sendEmailCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                        ),
                        child: const Text('인증', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                if (emailCodeSent) ...[
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('인증 코드를 발송했습니다', style: TextStyle(color: Colors.black, fontSize: 13)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: emailCodeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '인증 코드',
                            hintStyle: const TextStyle(color: Colors.black54, fontSize: 15),
                            filled: true,
                            fillColor: const Color(0xFFD9D9D9).withOpacity(0.4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 54,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : verifyEmailCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                          ),
                          child: const Text('확인', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                  if (emailVerified) ...[
                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('인증되었습니다', style: TextStyle(color: Colors.black, fontSize: 13)),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: idController,
                        onChanged: (_) => setState(() => idChecked = false),
                        decoration: InputDecoration(
                          hintText: '아이디',
                          hintStyle: const TextStyle(color: Colors.black54, fontSize: 15),
                          filled: true,
                          fillColor: const Color(0xFFD9D9D9).withOpacity(0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 54,
                      height: 29,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : checkIdDuplicate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                        ),
                        child: const Text('중복 확인', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    idChecked ? '사용 가능한 아이디입니다' : '아이디 형식 : 5~20자의 영문 소문자, 숫자',
                    style: TextStyle(
                      color: idChecked ? Colors.green : const Color(0xFF6B6868),
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: pwController,
                  obscureText: true,
                  onChanged: onPasswordChanged,
                  decoration: InputDecoration(
                    hintText: '비밀번호',
                    hintStyle: const TextStyle(color: Colors.black54, fontSize: 15),
                    filled: true,
                    fillColor: const Color(0xFFD9D9D9).withOpacity(0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '비밀번호 형식 : 8~16자의 영문 대소문자, 숫자, 특수문자',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B6868), fontSize: 11),
                ),
                if (showPwFormatError) ...[
                  const SizedBox(height: 6),
                  const Text('비밀번호 형식에 맞게 입력해주세요', style: TextStyle(color: Colors.red, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                TextField(
                  controller: pwConfirmController,
                  obscureText: true,
                  onChanged: onPasswordChanged,
                  decoration: InputDecoration(
                    hintText: '비밀번호 확인',
                    hintStyle: const TextStyle(color: Colors.black54, fontSize: 15),
                    filled: true,
                    fillColor: const Color(0xFFD9D9D9).withOpacity(0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (showPwMismatchError) ...[
                  const SizedBox(height: 6),
                  const Text('비밀번호가 일치하지 않습니다', style: TextStyle(color: Colors.red, fontSize: 13)),
                ],
                const SizedBox(height: 30),
                GestureDetector(
                  onTap: openTermsScreen,
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: ShapeDecoration(
                          color: agreedToTerms ? Colors.black : const Color(0xFFE4E2E2),
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(width: 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: agreedToTerms ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          '이용약관 및 개인정보 처리방침에 동의합니다',
                          style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.black),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : submitSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('가입하기', style: TextStyle(color: Colors.white, fontSize: 20)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignUpDoneScreen extends StatelessWidget {
  const _SignUpDoneScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 47),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: const ShapeDecoration(
                    color: Color(0xFF76FFD8),
                    shape: OvalBorder(),
                  ),
                  child: const Icon(Icons.check, size: 60, color: Colors.black),
                ),
                const SizedBox(height: 40),
                const Text(
                  '가입이 완료되었습니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 60),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('로그인 하러 가기', style: TextStyle(color: Colors.white, fontSize: 20)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}