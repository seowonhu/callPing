import 'dart:convert';
import 'api_service.dart';
import 'package:flutter/material.dart';
import 'transcript_screen.dart';
import 'analytics_screen.dart';

class FeedbackResultScreen extends StatefulWidget {
  final int recordId;
  final String fileName;
  final String summary;
  final String expression;
  final String feedback;

  // GET /calls/{recordId}/details 의 transcripts 데이터
  final List<dynamic> transcript; // 서버에서 받을 통화 원문 배열
  final List<dynamic> todos; // 서버에서 받을 TODO 리스트 배열
  final String todoSummary;

  const FeedbackResultScreen({
    super.key,
    required this.recordId,
    required this.fileName,
    required this.summary,
    required this.expression,
    required this.feedback,
    required this.transcript,
    this.todos = const [],
    this.todoSummary = '',
  });

  @override
  State<FeedbackResultScreen> createState() => _FeedbackResultScreenState();
}

class _FeedbackResultScreenState extends State<FeedbackResultScreen> {
  late List<dynamic> _currentTranscript;

  @override
  void initState() {
    super.initState();
    _currentTranscript = List.from(widget.transcript);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _currentTranscript);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              Navigator.pop(context, _currentTranscript);
            },
          ),
          title: Text(
            widget.fileName,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              _buildTranscriptBox(context),
              const SizedBox(height: 24),
              _buildFeedbackBox(title: '요약', content: widget.summary),
              const SizedBox(height: 24),
              _buildTodoSection(),
              const SizedBox(height: 24),
              _buildFeedbackBox(title: '표현 분석', content: widget.expression),
              const SizedBox(height: 24),
              _buildFeedbackBox(
                title: '다음엔 이렇게 말해보세요!',
                content: widget.feedback,
                titleColor: const Color(0xFFFF6B6B),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // 통화 원문을 말풍선처럼 그려주는 전용 박스

  // --------------------------------
  // 통화 원문 미리보기
  // --------------------------------

  Widget _buildTranscriptBox(BuildContext context) {
    // 최대 3문장만 미리 표시
    final previewTranscript = _currentTranscript.take(3).toList();

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
          // 제목 + 전체보기 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '통화 원문',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),

              InkWell(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TranscriptScreen(
                        recordId: widget.recordId,
                        transcripts: _currentTranscript,
                        isReadOnly: true,
                      ),
                    ),
                  );

                  if (result != null && mounted) {
                    // 분석 시작해서 true (bool)가 돌아온 경우
                    if (result is List) {
                      setState(() {
                        _currentTranscript = List.from(result);
                      });
                    }
                  }
                },
                child: const Text(
                  '전체 보기 >',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1A9000),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 원문 없을 때
          if (previewTranscript.isEmpty)
            const Text(
              '통화 원문이 없습니다.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),

          // 원문 미리보기
          ...previewTranscript.map((item) {
            // API 응답을 Map 형태로 안전하게 변환
            final data = Map<String, dynamic>.from(item as Map);

            final String speaker = data['speaker']?.toString() ?? '';

            final String text = data['text']?.toString() ?? '';

            // 화자 1 = 사용자
            final bool isMe = speaker == '화자 1';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,

                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color.fromARGB(255, 185, 172, 246)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),

                  child: Text(text, style: const TextStyle(fontSize: 14)),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---------------------------------------
  // 분석 결과 박스
  // ---------------------------------------

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

  // ------------------------------
  // TODO 리스트 박스
  // ------------------------------

  Widget _buildTodoSection() {
    if (widget.todos.isEmpty && widget.todoSummary.isEmpty)
      return const SizedBox.shrink();

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
            'TO DO',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),

          if (widget.todoSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.todoSummary,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 투두 리스트 화면에 하나씩 그림
          ...widget.todos.map((todo) {
            final String rawDesc = todo['description']?.toString() ?? '내용 없음';

            // 서버에서 온 글자를 |#| 기준으로 예쁘게 쪼개는 파싱 로직
            String taskTitle = rawDesc;
            String taskSub = '';

            if (rawDesc.contains('|#|')) {
              var parts = rawDesc.split('|#|');
              if (parts.length >= 2) {
                taskTitle = parts[1]; // 메인 할 일
                if (parts.length >= 3) {
                  taskSub = parts[2]; // 상세 내용
                }
              }
            }

            final priority = todo['priority']?.toString() ?? 'MEDIUM';
            final status = todo['status']?.toString() ?? 'PENDING';

            // 중요도에 따른 색상
            Color priorityColor = Colors.orange;
            String priorityText = '보통';
            if (priority == 'HIGH') {
              priorityColor = Colors.red;
              priorityText = '높음';
            } else if (priority == 'LOW') {
              priorityColor = Colors.green;
              priorityText = '낮음';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 완료 여부에 따른 체크 아이콘
                  Icon(
                    status == 'COMPLETED'
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    color: status == 'COMPLETED' ? Colors.green : Colors.grey,
                    size: 22,
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 할 일 제목
                        Text(
                          taskTitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: status == 'COMPLETED'
                                ? Colors.grey
                                : Colors.black87,
                            fontWeight: FontWeight.bold,
                            decoration: status == 'COMPLETED'
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),

                        // 할 일 상세 내용 (있을 때만 띄움)
                        if (taskSub.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            taskSub,
                            style: TextStyle(
                              fontSize: 12,
                              color: status == 'COMPLETED'
                                  ? Colors.grey.shade400
                                  : Colors.black54,
                              decoration: status == 'COMPLETED'
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],

                        const SizedBox(height: 6),

                        // 중요도 뱃지
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '중요도: $priorityText',
                            style: TextStyle(
                              fontSize: 10,
                              color: priorityColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
