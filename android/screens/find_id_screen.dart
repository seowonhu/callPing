import 'package:flutter/material.dart';

class FindIdScreen extends StatefulWidget {
  const FindIdScreen({super.key});

  @override
  State<FindIdScreen> createState() => _FindIdScreenState();
}

class _FindIdScreenState extends State<FindIdScreen> {
  // 현재 단계
  // 0 = 이메일 입력
  // 1 = 인증번호 입력
  // 2 = 인증 성공
  // 3 = 인증 실패
  int currentStep = 0;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController codeController = TextEditingController();

  // 테스트용 인증번호 및 아이디
  final String correctCode = '123456';
  final String foundId = 'abcdefg1234';

  @override
  void dispose() {
    emailController.dispose();
    codeController.dispose();
    super.dispose();
  }

  // 인증번호 발송
  void sendCode() {
    if (emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이메일을 입력해주세요.'),
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

  // 인증번호 확인
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
      // 인증 성공
      setState(() {
        currentStep = 2;
      });
    } else {
      // 인증 실패
      setState(() {
        currentStep = 3;
      });
    }
  }

  // 뒤로가기 / 화면 닫기
  void _handleBack() {
    if (currentStep > 0) {
      // 인증 단계 중간이면 전 단계(이메일 입력)로 이동
      setState(() {
        currentStep = 0;
      });
    } else {
      // 첫 단계면 이전 화면으로 이동 (스택이 있을 때만 pop)
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  // 비밀번호 재설정
  void resetPassword() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('비밀번호 재설정 화면으로 이동합니다.')));
  }

  @override
  Widget build(BuildContext context) {
    // 물리적 뒤로가기 버튼 핸들링 (PopScope)
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
        return _buildEmailStep();
      case 1:
        return _buildCodeStep();
      case 2:
        return _buildSuccessStep();
      case 3:
      default:
        return _buildFailStep();
    }
  }

  // 1단계 : 이메일 입력
  Widget _buildEmailStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const Text(
          '아이디를 잊어버리셨나요?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 100),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: '이메일 계정',
            hintStyle: const TextStyle(color: Colors.black54, fontSize: 15),
            filled: true,
            fillColor: const Color(0xFFD9D9D9).withValues(alpha: 0.4),
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

  // 2단계 : 인증번호 입력
  Widget _buildCodeStep() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Text(
          '아이디를 잊어버리셨나요?',
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

  // 3단계 : 인증 성공
  Widget _buildSuccessStep() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Text(
          '아이디를 잊어버리셨나요?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 100),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: '회원님의 아이디는 ',
                style: TextStyle(color: Colors.black, fontSize: 15),
              ),
              TextSpan(
                text: foundId,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(
                text: ' 입니다',
                style: TextStyle(color: Colors.black, fontSize: 15),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 80),
        SizedBox(
          width: double.infinity,
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
              '로그인 하러 가기',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: resetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              '비밀번호 재설정',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ),
      ],
    );
  }

  // 4단계 : 인증 실패
  Widget _buildFailStep() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Text(
          '아이디를 잊어버리셨나요?',
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
}
