import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _messageController = TextEditingController();

  final List<Map<String, dynamic>> _messages = [];
  bool _isWaiting = false;

  int? _currentRoomId;

  @override
  void initState() {
    super.initState();
    _startNewRoom();
  }

  // [API] 1. 새 채팅방 생성 (ApiService 연동)
  Future<void> _startNewRoom() async {
    setState(() {
      _messages.clear();
      _isWaiting = true;
      _currentRoomId = null; // 기존 방 번호 비워둠
    });

    try {
      print("서버로 새 채팅방 생성 요청 보냄");
      final response = await ApiService.createChatRoom().timeout(
        const Duration(seconds: 10),
      );

      print("채팅방 생성 응답 코드: ${response.statusCode}");
      print("채팅방 생성 응답 데이터: ${utf8.decode(response.bodyBytes)}");

      if (response.statusCode == 201) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));

        // 새 방 만들어지는 동안 사용자가 라이브러리에서 다른 방 열지 않았을 때만 방 번호 적용
        if (mounted && _currentRoomId == null) {
          setState(() {
            // 명세서 규칙 적용: 'data' 안의 'room_id' 꺼내기
            _currentRoomId = responseData['data']['room_id'];
            print("채팅방 생성 성공! 발급받은 방 번호: $_currentRoomId");
          });
        }
      } else {
        print("채팅방 생성 실패: 서버가 정상 코드(201)를 주지 않았습니다.");
      }
    } catch (e) {
      print("채팅방 생성 에러: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isWaiting = false;
        });
      }
    }
  }

  // [API] 2. 질문하기 (ApiService 연동)
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isWaiting) return;

    if (_currentRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('서버 연결 실패: 채팅방 번호를 받아오지 못했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String text = _messageController.text;
    int requestedRoomId = _currentRoomId!;

    setState(() {
      _messages.add({'text': text, 'isUser': true});
      _messageController.clear();
      _isWaiting = true;
    });

    String aiAnswer = "";

    try {
      print("서버로 메시지 전송 요청 보냄 (방 번호: $requestedRoomId, 질문: $text)");

      final response = await ApiService.sendChat(
        requestedRoomId,
        text,
      ).timeout(const Duration(seconds: 60));

      print("메시지 전송 응답 코드 : ${response.statusCode}");
      print("메시지 전송 응답 데이터: ${utf8.decode(response.bodyBytes)}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        // 명세서 규칙 적용: 'data' 포장지 안의 'answer' 꺼내기
        aiAnswer = responseData['data']['answer'];
        int newChatId = responseData['data']['chat_id']; // 서버가 준 chat_id 가져오기

        if (mounted && _currentRoomId == requestedRoomId) {
          setState(() {
            // 사용자가 보낸 질문 말풍선에 chatId 달아주기
            if (_messages.isNotEmpty && _messages.last['isUser'] == true) {
              _messages.last['chatId'] = newChatId;
            }
            // 챗봇 답변 말풍선에도 chatId 달아주기
            _messages.add({
              'text': aiAnswer,
              'isUser': false,
              'chatId': newChatId,
            });
            _isWaiting = false;
          });
        }
      } else {
        if (mounted && _currentRoomId == requestedRoomId) {
          setState(() {
            _messages.add({
              'text': '서버 응답 오류 (코드: ${response.statusCode})',
              'isUser': false,
            });
            _isWaiting = false;
          });
        }
      }
    } catch (e) {
      // 인터넷 끊기거나 60초 넘었을 때
      if (mounted && _currentRoomId == requestedRoomId) {
        setState(() {
          _messages.add({
            'text': '60초가 초과되었거나 네트워크 오류가 발생했습니다.',
            'isUser': false,
          });
          _isWaiting = false;
        });
      }
    }
  }

  void _stopGenerating() async {
    if (_currentRoomId == null) return;

    setState(() {
      _isWaiting = false;
      // 사용자가 질문한 직후 멈췄다면 화면에서 사용자 말풍선 지우고 텍스트창으로 되돌림
      if (_messages.isNotEmpty && _messages.last['isUser'] == true) {
        _messageController.text = _messages.last['text'];
        _messages.removeLast();
      }
    });

    try {
      final response = await ApiService.stopChatGeneration(_currentRoomId!);
      if (response.statusCode == 200) {
        debugPrint("서버 답변 생성 중단 완료");
      }
    } catch (e) {
      debugPrint("답변 중단 요청 실패: $e");
    }
  }

  void _showDeleteDialog(int index) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            '메시지 삭제',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('이 질문과 챗봇의 답변을 함께 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), // 취소시 팝업만 닫기
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // 팝업 닫고
                _deleteMessagePair(index); // 실제 삭제 로직 실행
              },
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 내 질문 + 챗봇 답변 지우는 함수
  Future<void> _deleteMessagePair(int index) async {
    // 삭제할 메시지의 고유번호 미리 빼둠
    int? chatId = _messages[index]['chatId'];

    // 화면에서 먼저 지우기
    setState(() {
      // 선택한 인덱스가 유저의 메시지인지 확인
      if (index < _messages.length && _messages[index]['isUser'] == true) {
        // 유저 메시지 먼저 삭제
        _messages.removeAt(index);

        // 유저 메시지 지워지면, 챗봇 답변이 한 칸 당겨짐(같은 index 됨)
        // 챗봇답변('isUser' == false) 라면 그것도 삭제
        if (index < _messages.length && _messages[index]['isUser'] == false) {
          _messages.removeAt(index);
        }
      }
    });

    // 3. 빼둔 번호로 서버에 삭제 API 요청 보냄
    if (chatId != null) {
      try {
        final response = await ApiService.deleteChatMessage(chatId);

        // 사용자가 화면 나가면 아래 코드 실행하지 않고 종료
        if (!mounted) return;

        if (response.statusCode == 200) {
          print("서버 DB에서도 삭제 성공!");
          // 방이 자동 폭하되었는지 확인하고 대처
          final responseData = jsonDecode(utf8.decode(response.bodyBytes));
          final data = responseData['data'] ?? responseData;
          if (data['room_deleted'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('마지막 대화가 삭제되어 채팅방이 종료되었습니다.')),
            );
            _startNewRoom(); // 새 채팅방으로 강제 이동 및 초기화
          }
        } else {
          print("서버 삭제 실패 (상태 코드: ${response.statusCode})");
        }
      } catch (e) {
        print("서버 삭제 통신 에러: $e");
      }
    }
  }

  // [API] 특정 방의 과거 대화 불러오기 (ApiService 연동)
  Future<void> _loadRoomDetail(int roomId) async {
    setState(() {
      _messages.clear();
      _isWaiting = true;
      _currentRoomId = roomId;
    });

    try {
      final response = await ApiService.getChatRoomDetail(
        roomId,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        // 명세서 규칙 적용: 'data' 포장지가 리스트
        final List<dynamic> data = responseData['data'];

        setState(() {
          for (var item in data) {
            int chatId = item['chat_id']; // 서버가 준 chat_id 가져오기
            // 각각 말풍선에 chatId 달아서 저장
            _messages.add({
              'text': item['question'],
              'isUser': true,
              'chatId': chatId,
            });
            _messages.add({
              'text': item['answer'],
              'isUser': false,
              'chatId': chatId,
            });
          }
        });
      }
    } catch (e) {
      print("채팅방 조회 에러: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isWaiting = false;
        });
      }
    }
  }

  // ===========================
  // 챗봇 가이드 바텀 시트
  // ===========================

  void _showGuideBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 스크롤 가능
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ), // 위쪽 모서리 둥글게
      ),
      builder: (BuildContext context) {
        // 1. container로 최대 높이를 화면이 85%로 제한
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min, // 내용물 크기만큼만 전체 높이 차지
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. 드래그 손잡이 영역
                Container(
                  width: double.infinity,
                  color: Colors.transparent,
                  padding: const EdgeInsets.only(top: 16, bottom: 20),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                // 3. 스크롤되는 가이드 내용
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 24.0,
                        right: 24.0,
                        bottom: 24.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 가이드 제목
                          const Text(
                            '답변이 마음에 들지 않으시나요?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 가이드 설명 내용
                          const Text(
                            '찾으시는 기업명이나 대상을 함께 넣으시면 훨씬 정확한 결과를 얻을 수 있습니다.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 예시 박스 (회색 배경으로 강조)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(
                                        text: '환불 절차에 대해 설명해 줘 (',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'X',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.red.shade600,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: ')',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 8),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(
                                        text: '쿠팡 환불 절차에 대해 설명해 줘 (',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'O',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: ')',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                          const Divider(color: Colors.black12, thickness: 1),
                          const SizedBox(height: 24),

                          // 정보 제공처 안내
                          const Text(
                            '서비스 정보 제공처 안내',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '본 서비스는 이용자분들께 정확하고 유용한 정보를 제공하기 위해 아래 기관 및 기업의 데이터를 활용/연계하고 있습니다.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 연계 기관 리스트
                          const Text(
                            '주요 연계 및 정보 제공처 : \n\n'
                            '[공공·행정]\n건강보험심사평가원, 고용노동부, 국민연금공단, 국세청 홈택스, 노원구 동주민센터, 한국장학재단, 한국전력공사\n\n'
                            '[금융·은행]\nKDB산업은행, 농협은행, 신한은행, 신한카드, 우리은행, 케이뱅크, 토스뱅크, 하나은행\n\n'
                            '[문화·예술]\n국립현대미술관, 서울시립미술관, 예술의전당\n\n'
                            '[쇼핑·유통]\n롯데백화점, 신세계백화점, 쿠팡\n\n'
                            '[의료·건강]\n국립중앙의료원, 서울대치과병원, 서울대학교병원\n\n'
                            '[취업·구인구직]\n급구플러스, 알바몬, 알바천국, 잡코리아\n\n'
                            '[통신]\nKT, LG유플러스, SKT',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: Drawer(
        backgroundColor: const Color(0xFFFCFCFC),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text(
                  '새 채팅',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _startNewRoom();
                },
              ),
              ListTile(
                leading: const Icon(Icons.library_books_outlined),
                title: const Text(
                  '라이브러리',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  Navigator.pop(context);

                  final selectedRoomId = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatLibraryScreen(),
                    ),
                  );

                  if (selectedRoomId != null && selectedRoomId is int) {
                    _loadRoomDetail(selectedRoomId);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // =======================================
            // 메뉴바 (햄버거 아이콘 & 가이드 아이콘)
            // =======================================
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(
                        Icons.menu,
                        size: 30,
                        color: Colors.black,
                      ),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showGuideBottomSheet(context), // 바텀시트 띄우기 호출
                    child: Image.asset(
                      'assets/chat_guide.png',
                      width: 28,
                      height: 28,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.help_outline,
                        size: 28,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _messages.isEmpty && !_isWaiting
                  ? const Center(
                      child: Text(
                        '무엇이든 물어보세요',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _messages.length + (_isWaiting ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isWaiting) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          );
                        }
                        bool isUser = _messages[index]['isUser'];
                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          // 1. GestureDetector 추가해서 말풍선 감싸기
                          child: GestureDetector(
                            onLongPress: () {
                              // 유저가 보낸 파란색 메시지일 때만 삭제 팝업 띄우기
                              if (isUser) {
                                _showDeleteDialog(index);
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? const Color(0xFF7C9CFF)
                                    : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                  bottomLeft: Radius.circular(isUser ? 16 : 0),
                                  bottomRight: Radius.circular(isUser ? 0 : 16),
                                ),
                                border: isUser
                                    ? null
                                    : Border.all(
                                        color: Colors.black87,
                                        width: 1.5,
                                      ),
                              ),
                              child: Text(
                                _messages[index]['text'],
                                softWrap: true,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isUser ? Colors.white : Colors.black,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      }, // itemBuilder
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: '입력해주세요',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: _isWaiting
                            ? null
                            : (_) {
                                _sendMessage();
                              },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _isWaiting ? _stopGenerating : _sendMessage,
                    child: Container(
                      width: 45,
                      height: 45,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isWaiting ? Icons.stop_rounded : Icons.arrow_upward,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// 라이브러리(채팅 내역) 화면
// =============================================================
class ChatLibraryScreen extends StatefulWidget {
  const ChatLibraryScreen({super.key});

  @override
  State<ChatLibraryScreen> createState() => _ChatLibraryScreenState();
}

class _ChatLibraryScreenState extends State<ChatLibraryScreen> {
  List<dynamic> _roomList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  // [API] 과거 방 목록 불러오기 (ApiService 연동)
  Future<void> _fetchRooms() async {
    try {
      final response = await ApiService.getChatRooms();

      if (response.statusCode == 200) {
        // 1. 정상적으로 목록을 불러왔을 때
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          // 명세서 규칙 적용
          _roomList = responseData['data'];
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        // 2. 대화 내역이 없을 때 (404 반환)
        setState(() {
          _roomList = []; // 빈 목록으로 초기화
          _isLoading = false; // 로딩 끄기
        });
      } else {
        // 3. 그 외 서버 에러(500 등) 발생
        if (mounted) {
          setState(() {
            _isLoading = false; // 로딩 끔
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('목록을 불러오는 중 오류 발생 (코드: ${response.statusCode})'),
            ),
          );
        }
      }
    } catch (e) {
      // 4. 네트워크 오류 등 예외 발생
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // [API] 방 삭제 (ApiService 연동)
  Future<void> _deleteRoom(int roomId, int index) async {
    setState(() {
      _roomList.removeAt(index);
    });

    try {
      await ApiService.deleteChatRoom(roomId);
    } catch (e) {
      print("삭제 에러");
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '날짜 없음';
    try {
      DateTime date = DateTime.parse(isoString).toLocal();
      return '${date.month}월 ${date.day}일';
    } catch (e) {
      debugPrint("날짜 변환 에러: $e");
      return '날짜 오류';
    }
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
          '라이브러리',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _roomList.isEmpty
          ? const Center(
              child: Text(
                '저장된 이전 대화가 없습니다.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24.0),
              itemCount: _roomList.length,
              itemBuilder: (context, index) {
                final room = _roomList[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            int? clickedId = room['room_id'] ?? room['roomId'];
                            print("선택된 방 번호: $clickedId"); // 확인용 로그

                            // 명세서 규칙 적용: 'room_id'
                            if (clickedId != null) {
                              Navigator.pop(context, clickedId);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('에러: 방 번호를 찾을 수 없습니다.'),
                                ),
                              );
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                // 명세서 규칙 적용: 'created_at'
                                _formatDate(room['created_at']),
                                style: const TextStyle(
                                  color: Color(0xFFA3A0A0),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                room['title'] ?? '새로운 대화',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.black54,
                        ),
                        // 명세서 규칙 적용: 'room_id'
                        onPressed: () => _deleteRoom(room['room_id'], index),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
