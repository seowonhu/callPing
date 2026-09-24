import 'package:flutter/material.dart';

class FeedbackResultScreen extends StatelessWidget {
  final String fileName;
  final String summary;
  final String expression;
  final String feedback;
  final List<dynamic> transcript; // 서버에서 받을 통화 원문 배열

  const FeedbackResultScreen({
    super.key,
    required this.fileName,
    // 테스트용 임시 데이터
    this.summary = '• 목적 : ○○병원 건강검진 예약\n• 결과 : 7월 8일 예약 확정',
    this.expression = '• 습관어 반복(3회) : "아니 그게" 라는 말을 자주 사용했어요.',
    this.feedback = '• 추천 표현 : "이번 주 수요일에 방문하고 싶습니다."',
    this.transcript = const [
      {"speaker": "user123", "text": "잘 지내지?"},
      {"speaker": "friend", "text": "그냥 그렇지 뭐."},
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          fileName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // ⭐️ 화면 전체 스크롤 적용
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildTranscriptBox(),
            const SizedBox(height: 24),
            _buildFeedbackBox(title: '요약', content: summary),
            const SizedBox(height: 24),
            _buildFeedbackBox(title: '표현 분석', content: expression),
            const SizedBox(height: 24),
            _buildFeedbackBox(
              title: '다음엔 이렇게 말해보세요!',
              content: feedback,
              titleColor: const Color(0xFFFF6B6B),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 통화 원문을 말풍선처럼 그려주는 전용 박스
  Widget _buildTranscriptBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black87),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '통화 원문',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // 원문 배열을 돌면서 텍스트 생성
          ...transcript.map((item) {
            final isMe = item['speaker'] == 'user123'; // 본인 아이디 조건
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blue[100] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(item['text'] ?? ''),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // 요약, 표현 분석, 다음엔 이렇게 박스를 그리는 함수
  Widget _buildFeedbackBox({
    required String title,
    required String content,
    Color titleColor = Colors.black,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black87),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
