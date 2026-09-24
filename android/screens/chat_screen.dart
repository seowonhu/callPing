import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
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
        setState(() {
          // 명세서 규칙 적용: 'data' 안의 'room_id' 꺼내기
          _currentRoomId = responseData['data']['room_id'];
          print("채팅방 생성 성공! 발급받은 방 번호: $_currentRoomId");
        });
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
      } else {
        aiAnswer = '서버 응답 오류 (코드: ${response.statusCode})';
      }
    } catch (e) {
      aiAnswer = '60초가 초과되었거나 네트워크 오류가 발생했습니다.';
    }

    if (mounted) {
      if (_currentRoomId == requestedRoomId) {
        setState(() {
          _messages.add({'text': aiAnswer, 'isUser': false});
          _isWaiting = false;
        });
      }
    }
  }

  void _stopGenerating() {
    setState(() {
      _isWaiting = false;
      if (_messages.isNotEmpty && _messages.last['isUser'] == true) {
        _messageController.text = _messages.last['text'];
        _messages.removeLast();
      }
    });
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
            _messages.add({'text': item['question'], 'isUser': true});
            _messages.add({'text': item['answer'], 'isUser': false});
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

  @override
  Widget build(BuildContext context) {
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
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 10.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, size: 30, color: Colors.black),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
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
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            decoration: isUser
                                ? const BoxDecoration(
                                    image: DecorationImage(
                                      image: AssetImage('assets/user_chat.png'),
                                      fit: BoxFit.fill,
                                    ),
                                  )
                                : const BoxDecoration(
                                    image: DecorationImage(
                                      image: AssetImage('assets/ai_chat.png'),
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                            child: Text(
                              _messages[index]['text'],
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        );
                      },
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
                            : (value) => _sendMessage(),
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
      ("날짜 변환 에러: $e");
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
