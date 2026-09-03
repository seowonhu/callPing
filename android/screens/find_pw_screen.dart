import 'package:flutter/material.dart';

class FindPwScreen extends StatefulWidget {
  const FindPwScreen({super.key});

  @override
  State<FindPwScreen> createState() => _FindPwScreenState();
}

class _FindPwScreenState extends State<FindPwScreen> {
  // 현재 단계
  // 0 = 아이디 + 이메일 입력
  // 1 = 인증번호 입력
  // 2 = 인증 성공
  // 3 = 인증 실패
  // 4 = 새 비밀번호 재설정
  // 5 = 완료
  int currentStep = 0;

  final TextEditingController idController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController newPwController = TextEditingController();
  final TextEditingController confirmPwController = TextEditingController();

  // 테스트용 인증번호
  final String correctCode = '123456';

  // 비밀번호 에러 메시지 표시 여부
  bool showFormatError = false;
  bool showMismatchError = false;

  @override
  void dispose() {
    idController.dispose();
    emailController.dispose();
    codeController.dispose();
    newPwController.dispose();
    confirmPwController.dispose();
    super.dispose();
  }

  // 1단계 -> 인증번호 발송
  void sendCode() {
    if (idController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아이디와 이메일을 모두 입력해주세요.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      currentStep = 1;
      codeController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('인증 코드가 발송되었습니다.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 2단계 -> 인증번호 확인
  void verifyCode() {
    if (codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('인증 코드를 입력해주세요.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (codeController.text.trim() == correctCode) {
      setState(() {
        currentStep = 2; // 인증 성공
      });
    } else {
      setState(() {
        currentStep = 3; // 인증 실패
      });
    }
  }

  // 비밀번호 형식 검사: 8~16자, 영문 + 숫자 + 특수문자 모두 포함
  bool _isValidPassword(String pw) {
    if (pw.length < 8 || pw.length > 16) return false;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(pw);
    final hasDigit = RegExp(r'[0-9]').hasMatch(pw);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(pw);
    return hasLetter && hasDigit && hasSpecial;
  }

  // 4단계 -> 새 비밀번호 형식/일치 검사 후 완료 화면으로
  void submitNewPassword() {
    final String newPw = newPwController.text;
    final String confirmPw = confirmPwController.text;

    final bool isFormatValid = _isValidPassword(newPw);
    final bool isMatch = newPw == confirmPw && confirmPw.isNotEmpty;

    setState(() {
      showFormatError = !isFormatValid;
      showMismatchError = isFormatValid && !isMatch;
    });

    if (isFormatValid && isMatch) {
      setState(() {
        currentStep = 5; // 완료
      });
    }
  }

  // 뒤로가기 처리
  void _handleBack() {
    if (currentStep > 0) {
      setState(() {
        currentStep = 0;
      });
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: currentStep == 0 && Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 47),
                child: _buildCurrentStep(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (currentStep) {
      case 0:
        return _buildInputStep();
      case 1:
        return _buildCodeStep();
      case 2:
        return _buildVerifiedStep();
      case 3:
        return _buildFailStep();
      case 4:
        return _buildResetPasswordStep();
      case 5:
      default:
        return _buildDoneStep();
    }
  }

  // 0단계 : 아이디 + 이메일 입력
  Widget _buildInputStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const Text(
          '비밀번호를 잊어버리셨나요?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 60),
        TextField(
          controller: idController,
          decoration: InputDecoration(
            hintText: '아이디',
            hintStyle: const TextStyle(color: Colors.black54),
            filled: true,
            fillColor: const Color(0xFFD9D9D9).withOpacity(0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: '이메일 계정',
            hintStyle: const TextStyle(color: Colors.black54),
            filled: true,
            fillColor: const Color(0xFFD9D9D9).withOpacity(0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 60),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: sendCode,
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
      ],
    );
  }

  // 1단계 : 인증코드 입력
  Widget _buildCodeStep() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Text(
          '비밀번호를 잊어버리셨나요?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          '인증 코드가 발송되었습니다\n인증 코드를 입력해주세요',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black, fontSize: 15, height: 1.67),
        ),
        const SizedBox(height: 60),
        TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, letterSpacing: 15),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            hintText: '------',
            hintStyle: TextStyle(color: Colors.black26, letterSpacing: 15),
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: verifyCode,
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
      ],
    );
  }

  // 2단계 : 인증 성공
  Widget _buildVerifiedStep() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Text(
          '비밀번호를 잊어버리셨나요?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          '인증 코드가 발송되었습니다\n인증 코드를 입력해주세요',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black, fontSize: 15, height: 1.67),
        ),
        const SizedBox(height: 30),
        const Text(
          '인증되었습니다',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black, fontSize: 15),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                currentStep = 4; // 비밀번호 재설정 화면으로
              });
            },
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
      ],
    );
  }

  // 3단계 : 인증 실패
  Widget _buildFailStep() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Text(
          '비밀번호를 잊어버리셨나요?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          '인증 코드가 발송되었습니다\n인증 코드를 입력해주세요',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black, fontSize: 15, height: 1.67),
        ),
        const SizedBox(height: 60),
        TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, letterSpacing: 15),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '인증 코드가 일치하지 않습니다',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.redAccent, fontSize: 14),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: verifyCode,
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
      ],
    );
  }

  // 4단계 : 새 비밀번호 재설정
  Widget _buildResetPasswordStep() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Text(
          '비밀번호 재설정',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 40),
        TextField(
          controller: newPwController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: '새로운 비밀번호',
            hintStyle: const TextStyle(color: Colors.black54),
            filled: true,
            fillColor: const Color(0xFFD9D9D9).withOpacity(0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '비밀번호 형식 : 8~16자의 영문 대소문자, 숫자, 특수문자',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B6868), fontSize: 11, height: 1.5),
        ),
        const SizedBox(height: 4),
        const Text(
          '사용 가능한 특수문자를 포함해 8~16자로 입력해주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B6868), fontSize: 9, height: 1.5),
        ),
        if (showFormatError) ...[
          const SizedBox(height: 6),
          const Text(
            '비밀번호 형식에 맞게 입력해주세요',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFFF0000), fontSize: 13),
          ),
        ],
        const SizedBox(height: 20),
        TextField(
          controller: confirmPwController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: '비밀번호 확인',
            hintStyle: const TextStyle(color: Colors.black54),
            filled: true,
            fillColor: const Color(0xFFD9D9D9).withOpacity(0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (showMismatchError) ...[
          const SizedBox(height: 6),
          const Text(
            '비밀번호가 일치하지 않습니다',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFFF0000), fontSize: 13),
          ),
        ],
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: submitNewPassword,
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
      ],
    );
  }

  // 5단계 : 완료
  Widget _buildDoneStep() {
    return Column(
      children: [
        const SizedBox(height: 60),
        const Text(
          '비밀번호 변경 완료',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 60),
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
          '비밀번호가 성공적으로 변경되었습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 60),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // 로그인 화면으로 돌아가기
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              '로그인 하러 가기',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ),
      ],
    );
  }
}
