import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// 서버 기본 주소
const String BASE_URL = 'http://54.116.93.220:8080';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  // 화면에 띄울 메시지 리스트
  final List<Map<String, dynamic>> _messages = [];
  bool _isWaiting = false;

  // 현재 활성화된 방 번호 (서버가 줌)
  int? _currentRoomId;

  @override
  void initState() {
    super.initState();
    // 앱 켜면 빈 채팅방 생성
    _startNewRoom();
  }

  // 임시 토큰 발급 함수 (나중에 로그인 연동 시 수정)
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    // 실제로는 prefs.getString('access_token') 등을 가져옴
    // 지금은 테스트용 가짜 토큰을 넣거나 비워둠
    return prefs.getString('access_token') ?? "임시_토큰_값";
  }

  // [API] 1. 새 채팅방 생성 (POST /chats/rooms)
  Future<void> _startNewRoom() async {
    setState(() {
      _messages.clear();
      _isWaiting = true;
    });

    try {
      String token = await _getToken();
      final response = await http
          .post(
            Uri.parse('$BASE_URL/chats/rooms'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _currentRoomId = data['roomId']; // 서버가 준 방 번호 저장
        });
      }
    } catch (e) {
      print("채팅방 생성 에러: $e");
    } finally {
      setState(() {
        _isWaiting = false;
      });
    }
  }

  // [API] 2. 질문하기 (POST /chats)
  Future<void> _sendMessage() async {
    // 빈칸이거나 로딩 중이면 무시
    if (_messageController.text.trim().isEmpty || _isWaiting) return;

    // 방 번호가 없으면 사용자에게 에러 팝업
    if (_currentRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('서버 연결 실패: 가짜 토큰이거나 서버가 닫혀있어 방을 만들지 못했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String text = _messageController.text;
    int requestedRoomId = _currentRoomId!; // 답변 꼬임 방지를 위한 꼬리표

    setState(() {
      _messages.add({'text': text, 'isUser': true});
      _messageController.clear();
      _isWaiting = true;
    });

    String aiAnswer = "";

    try {
      String token = await _getToken();

      // 서버로 DTO 양식(roomId, question)에 맞춰 전송
      final response = await http
          .post(
            Uri.parse('$BASE_URL/chats'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'roomId': requestedRoomId, 'question': text}),
          )
          .timeout(const Duration(seconds: 60)); // 60초 타임아웃

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        aiAnswer = data['answer']; // DTO 명세서에 따른 'answer'
      } else {
        aiAnswer = '서버 응답 오류 (코드: ${response.statusCode})';
      }
    } catch (e) {
      aiAnswer = '60초가 초과되었거나 네트워크 오류가 발생했습니다.';
    }

    if (mounted) {
      // 답변이 왔을 때, 사용자가 방을 안 옮기고 기다렸다면 화면에 띄움
      // 방을 옮겼다면, 백엔드 DB에 이미 저장됐으니 화면에 띄울 필요 없음
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
    // TODO: (선택) API 3번 - 서버에 중단 요청(ChatStopRequestDTO)을 보내는 로직을 추가할 수 있음
  }

  // [API] 특정 방의 과거 대화 불러오기 (GET /chats/rooms/{roomId})
  Future<void> _loadRoomDetail(int roomId) async {
    setState(() {
      _messages.clear();
      _isWaiting = true;
      _currentRoomId = roomId; // 현재 방 번호 변경
    });

    try {
      String token = await _getToken();
      final response = await http
          .get(
            Uri.parse('$BASE_URL/chats/rooms/$roomId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          // 서버가 준 질문/답변 목록을 말풍선 리스트에 넣음
          for (var item in data) {
            _messages.add({'text': item['question'], 'isUser': true});
            _messages.add({'text': item['answer'], 'isUser': false});
          }
        });
      }
    } catch (e) {
      print("채팅방 조회 에러: $e");
    } finally {
      setState(() {
        _isWaiting = false;
      });
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
                  _startNewRoom(); // 새 채팅방을 서버에 요청
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

                  // 라이브러리 화면으로 이동
                  final selectedRoomId = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatLibraryScreen(),
                    ),
                  );

                  // 사용자가 방을 선택해서 돌아왔다면
                  if (selectedRoomId != null && selectedRoomId is int) {
                    _loadRoomDetail(selectedRoomId); // 서버에서 과거 대화 내역 받아옴
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
// 라이브러리(채팅 내역) 화면 - 서버에서 불러옴
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

  // 임시 토큰
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ?? "임시_토큰_값";
  }

  // [API] 과거 방 목록 불러오기 (GET /chats/rooms)
  Future<void> _fetchRooms() async {
    try {
      String token = await _getToken();
      final response = await http.get(
        Uri.parse('$BASE_URL/chats/rooms'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _roomList = jsonDecode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // [API] 방 삭제 (DELETE /chats/rooms/{roomId})
  Future<void> _deleteRoom(int roomId, int index) async {
    setState(() {
      _roomList.removeAt(index); // 화면에서 즉시 지움
    });

    try {
      String token = await _getToken();
      await http.delete(
        Uri.parse('$BASE_URL/chats/rooms/$roomId'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      print("삭제 에러");
    }
  }

  String _formatDate(String isoString) {
    DateTime date = DateTime.parse(isoString).toLocal();
    return '${date.month}월 ${date.day}일';
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
                            // 방을 클릭하면, 서버의 roomId를 들고 돌아감
                            Navigator.pop(context, room['roomId']);
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDate(room['createdAt']),
                                style: const TextStyle(
                                  color: Color(0xFFA3A0A0),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                room['title'],
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
                        onPressed: () => _deleteRoom(room['roomId'], index),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
