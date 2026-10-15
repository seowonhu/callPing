import 'dart:convert';
import 'package:flutter/material.dart';

import 'api_service.dart';
import 'chat_screen.dart'; // 챗봇 화면
import 'analytics_screen.dart'; // 분석 화면
import 'settings_screen.dart'; // 설정 화면
import 'guide_screen.dart'; // 통화 가이드 화면

final GlobalKey<InlineChecklistBoxState> globalChecklistKey =
    GlobalKey<InlineChecklistBoxState>();

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex;
  bool _isFromHomeButton = false;

  // 1번 탭 안에서만 화면이 이동하도록 잡아주는 전용 네비게이터 키
  final GlobalKey<NavigatorState> _homeNavKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      // 1번 탭(콜핑)을 Navigator로 감싸서 하단 바가 가려지지 않게 보호
      Navigator(
        key: _homeNavKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            // 주의: navContext를 전달해야 하단 바 안에서만 화면이 바뀜
            builder: (navContext) => _buildMainTab(navContext),
          );
        },
      ),
      const ChatScreen(),
      AnalyticsScreen(
        showBackButton: _isFromHomeButton,
        onBackPressed: () {
          setState(() {
            _selectedIndex = 0; // 홈 탭으로 이동
            _isFromHomeButton = false;
          });
        },
      ),
      const SettingsScreen(),
    ];

    // 안드로이드 뒤로가기 버튼 눌렀을 때 앱이 바로 안 꺼지게 막아주는 기능
    return WillPopScope(
      onWillPop: () async {
        // 홈 탭 안에서 통화 가이드 등에 들어가 있다면, 그 화면만 뒤로가기
        if (_selectedIndex == 0 && _homeNavKey.currentState?.canPop() == true) {
          _homeNavKey.currentState?.pop();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            // 이미 보고 있는 홈 탭을 한 번 더 누르면 첫 화면으로 정리해주는 기능
            if (index == _selectedIndex && index == 0) {
              _homeNavKey.currentState?.popUntil((route) => route.isFirst);
            }
            // 홈 탭 누를 때마다 체크리스트 새로고침
            if (index == 0) {
              globalChecklistKey.currentState?.fetchTodos();
            }
            setState(() {
              _selectedIndex = index;
              _isFromHomeButton = false;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF1A9000),
          unselectedItemColor: Colors.black,
          items: [
            BottomNavigationBarItem(
              icon: Image.asset(
                'assets/home.png',
                width: 24,
                height: 24,
                color: _selectedIndex == 0
                    ? const Color(0xFF1A9000)
                    : Colors.black,
              ),
              label: '콜핑',
            ),
            BottomNavigationBarItem(
              icon: Image.asset(
                'assets/chat.png',
                width: 24,
                height: 24,
                color: _selectedIndex == 1
                    ? const Color(0xFF1A9000)
                    : Colors.black,
              ),
              label: '챗봇',
            ),
            BottomNavigationBarItem(
              icon: Image.asset(
                'assets/analytic.png',
                width: 24,
                height: 24,
                color: _selectedIndex == 2
                    ? const Color(0xFF1A9000)
                    : Colors.black,
              ),
              label: '분석',
            ),
            BottomNavigationBarItem(
              icon: Image.asset(
                'assets/setting.png',
                width: 24,
                height: 24,
                color: _selectedIndex == 3
                    ? const Color(0xFF1A9000)
                    : Colors.black,
              ),
              label: '설정',
            ),
          ],
        ),
        body: IndexedStack(index: _selectedIndex, children: pages),
      ),
    );
  }

  // 0번 탭: 메인 화면 구성 (navContext를 받아옵니다)
  Widget _buildMainTab(BuildContext navContext) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 20.0,
        ), // vertical 원래 16
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 70), // 숫자 늘리면 버튼이 더 밑으로
            // 핵심 기능 1 : 통화 가이드
            _buildPrimaryButton(
              title: '통화 가이드',
              subtitle: '상황에 맞는 통화 대본을 AI가 만들어줘요',
              color: const Color(0xFFE3EBF8), // 파스텔 블루
              onTap: () {
                Navigator.push(
                  navContext, // 전체 context가 아닌 내부 navContext 사용!
                  MaterialPageRoute(
                    builder: (context) => const GuideInputScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),

            // 핵심 기능 2: 파일 업로드
            _buildPrimaryButton(
              title: '파일 업로드',
              subtitle: '통화 녹음을 텍스트로 변환하고 분석해요',
              color: const Color(0xFFE8F5E9), // 파스텔 그린
              onTap: () {
                setState(() {
                  _selectedIndex = 2;
                  _isFromHomeButton = true;
                });
              },
            ),
            const SizedBox(height: 30),

            // 보조 기능 3: 대본 보관함
            _buildSecondaryButton(
              title: '대본 보관함',
              color: Colors.grey.shade100,
              onTap: () {
                Navigator.push(
                  navContext,
                  MaterialPageRoute(
                    builder: (context) => const ScriptLibraryScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),

            // 체크리스트 맨 아래, 원할 때만 열림
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false, // 접어둔 상태 기본값
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                collapsedBackgroundColor: Colors.grey.shade100,
                backgroundColor: Colors.white,
                iconColor: Colors.black54,
                collapsedIconColor: Colors.black54,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                title: const Text(
                  '체크리스트',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Center(
                      child: InlineChecklistBox(key: globalChecklistKey),
                    ), // 체크리스트 컴포넌트 유지
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // primary 기능 전용 디자인
  Widget _buildPrimaryButton({
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12), // 테두리
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 보조 기능 - 작고 깔끔하게
  Widget _buildSecondaryButton({
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ), // 기존 14, 20
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200), // 기존 colors.black12
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 피그마 디자인을 반영한 인라인 편집
// ============================================================================

class InlineChecklistBox extends StatefulWidget {
  const InlineChecklistBox({super.key});
  @override
  InlineChecklistBoxState createState() => InlineChecklistBoxState();
}

class InlineChecklistBoxState extends State<InlineChecklistBox> {
  int _step = 0;
  List<Map<String, dynamic>> _savedChecklists = [];
  int _currentIndex = -1;
  int _currentPage = 0;
  int _previousIndex = -1;
  bool _isLoading = false; // 통신 중 버튼 연타 방지

  final TextEditingController _targetController = TextEditingController();
  final List<TextEditingController> _titleControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<TextEditingController> _subControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  List<bool> _isDones = [false, false, false, false];

  @override
  void initState() {
    super.initState();
    fetchTodos(); // 앱 켜자마자 서버에서 TODO 목록 가져오기
  }

  // 서버에서 TODO 목록 가져와서 UI에 맞게 변환
  Future<void> fetchTodos() async {
    if (mounted) {
      setState(() {
        _savedChecklists.clear();
        _isLoading = true;
      });
    }

    try {
      final response = await ApiService.getTodos();
      if (response.statusCode == 200) {
        final decodedStr = utf8.decode(response.bodyBytes);

        // =================================
        // 체크리스트 서버 응답
        // =================================

        debugPrint('\n=== [응답] 전체 체크리스트 조회 ===');
        debugPrint(decodedStr);
        debugPrint('=====================================\n');

        final data = jsonDecode(decodedStr);

        List<dynamic> todos = [];
        if (data is List) {
          todos = data;
        } else if (data is Map) {
          if (data.containsKey('data')) {
            final innerData = data['data'];
            if (innerData is List) {
              todos = innerData;
            } else if (innerData is Map && innerData.containsKey('todos')) {
              if (innerData['todos'] is List) {
                todos = innerData['todos'];
              }
            }
          } else if (data.containsKey('todos') && data['todos'] is List) {
            todos = data['todos'];
          }
        }

        // =========================================================
        // [디버그 코드] 홈 화면 API가 진짜 값을 주는지
        // =========================================================
        try {
          if (todos.isNotEmpty && todos[0] is Map) {
            debugPrint(
              "[디버그] 홈 화면 알맹이 recordId: ${todos[0]['recordId']} / ${todos[0]['record_id']}",
            );
            debugPrint(
              "[디버그] 홈 화면 알맹이 recordTitle: ${todos[0]['recordTitle']} / ${todos[0]['record_title']}",
            );
          } else {
            debugPrint("[디버그] todos 배열이 비어있거나 Map이 아닙니다.");
          }
        } catch (e) {
          debugPrint("[디버그 에러] $e");
        }
        // =========================================================
        // ID/Title 가져오기
        Map<String, dynamic> targetData = {};
        if (data is Map) {
          // data['data]가 Map이면 쓰고 아니면 최상단 data 씀
          if (data.containsKey('data') && data['data'] is Map) {
            targetData = Map<String, dynamic>.from(data['data']);
          } else {
            targetData = Map<String, dynamic>.from(data);
          }
        }

        int globalRecordId =
            targetData['recordId'] ?? targetData['record_id'] ?? 0;
        String globalRecordTitle =
            targetData['recordTitle'] ??
            targetData['record_title']?.toString() ??
            '';

        // 목표별로 묶어줄 임시 박스
        Map<String, List<Map<String, dynamic>>> grouped = {};

        for (var t in todos) {
          if (t is! Map) continue;

          int todoId = t['todoId'] ?? t['todo_id'] ?? 0;
          int recordId = t['recordId'] ?? t['record_id'] ?? globalRecordId;

          dynamic descObj = t['description'];
          String rawDesc = (descObj is List)
              ? descObj.join(' ')
              : descObj?.toString() ?? '';
          String status = t['status'] ?? 'PENDING';
          String taskType =
              t['taskType']?.toString() ??
              t['task_type']?.toString() ??
              'MANUAL';
          //  t[record_title]은 백엔드 에서 내려주는 값으로 수정
          dynamic titleObj = t['recordTitle'] ?? t['record_title'];

          String target = '';
          if (titleObj != null) {
            target = (titleObj is List)
                ? titleObj.join(' ')
                : titleObj.toString();
          } else if (globalRecordTitle.isNotEmpty) {
            target = globalRecordTitle;
          } else {
            target = '통화녹음_$recordId';
          }

          String title = rawDesc;

          String sub = '';

          // 백엔드에서 온 한 줄짜리 문자열을 UI 칸에 맞게 3등분으로 쪼개는 로직 (ex. 병원|#|약 먹기|#|식후 30분)
          if (rawDesc.contains('|#|')) {
            List<String> parts = rawDesc.split('|#|');
            if (parts.isNotEmpty) {
              target = parts[0];
              if (parts.length > 1) title = parts[1];
              if (parts.length > 2) sub = parts[2];
            }
          }

          if (!grouped.containsKey(target)) grouped[target] = [];
          grouped[target]!.add({
            'todoId': todoId,
            'title': title,
            'sub': sub,
            'taskType': taskType,
            'isDone': status == 'COMPLETED',
          });
        }

        // 4개씩 잘라서 페이지 완성
        List<Map<String, dynamic>> newChecklists = [];
        grouped.forEach((tgt, tasks) {
          for (int i = 0; i < tasks.length; i += 4) {
            newChecklists.add({
              'target': tgt,
              'tasks': tasks.sublist(
                i,
                i + 4 > tasks.length ? tasks.length : i + 4,
              ),
            });
          }
        });
        // 새로 생성된 항목이 맨 위에 오도록
        newChecklists = newChecklists.reversed.toList();

        setState(() {
          _savedChecklists = newChecklists;
          if (_savedChecklists.isEmpty) {
            _step = 0;
          } else {
            _step = 2;
            if (_currentIndex == -1 ||
                _currentIndex >= _savedChecklists.length) {
              _loadChecklist(0);
            } else {
              _loadChecklist(_currentIndex);
            }
          }
        });
      } else {
        throw Exception('통신 에러');
      }
    } catch (e) {
      debugPrint("TODO 불러오기 실패: $e");
      if (mounted) {
        setState(() => _step = 0); // 실패 시 빈 화면
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('서버와 연결할 수 없습니다. 네트워크 상태를 확인해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearFields() {
    _targetController.clear();
    for (int i = 0; i < 4; i++) {
      _titleControllers[i].clear();
      _subControllers[i].clear();
      _isDones[i] = false;
    }
  }

  void _loadChecklist(int index) {
    _currentIndex = index;
    _targetController.text = _savedChecklists[index]['target'];
    var tasks = _savedChecklists[index]['tasks'];

    for (int i = 0; i < 4; i++) {
      if (i < tasks.length) {
        _titleControllers[i].text = tasks[i]['title'];
        _subControllers[i].text = tasks[i]['sub'];
        _isDones[i] = tasks[i]['isDone'];
      } else {
        _titleControllers[i].clear();
        _subControllers[i].clear();
        _isDones[i] = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 342,
      height: 275,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 2, color: Colors.black),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Stack(
        children: [
          _step == 0
              ? _buildStep0Empty()
              : _step == 1
              ? _buildStep1Editing()
              : _step == 2
              ? _buildStep2Saved()
              : _buildStep3ListView(),

          // 통신 중일 때 로딩 오버레이
          if (_isLoading)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep0Empty() {
    return GestureDetector(
      onTap: () => setState(() {
        _currentIndex = -1;
        _clearFields();
        _step = 1;
      }),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/make_checklist.png',
              width: 80,
              height: 80,
              errorBuilder: (c, e, s) =>
                  const Icon(Icons.playlist_add, size: 80, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            const Text(
              '체크리스트를 만들어보세요',
              style: TextStyle(
                color: Color(0xFF6A6767),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Editing() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Column(
              children: [
                const SizedBox(height: 30),
                Expanded(
                  child: Center(
                    child: TextField(
                      controller: _targetController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      decoration: const InputDecoration(
                        hintText: '제목',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() {
                          if (_currentIndex != -1) {
                            _loadChecklist(_currentIndex);
                            _step = 2;
                          } else {
                            if (_previousIndex != -1) {
                              _loadChecklist(_previousIndex);
                              _step = 2;
                              _previousIndex = -1;
                            } else {
                              _step = _savedChecklists.isEmpty ? 0 : 2;
                            }
                          }
                        }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 30),
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(color: Colors.black, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // 저장 버튼 누를 때 서버로 전송 로직
                          // 유효성 검사 (입력된 항목 있는지)
                          bool hasItem = false;
                          for (int i = 0; i < 4; i++) {
                            if (_titleControllers[i].text.trim().isNotEmpty) {
                              hasItem = true;
                            }
                          }

                          if (_targetController.text.trim().isEmpty ||
                              !hasItem) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('제목과 할 일을 1개 이상 적어주세요!'),
                              ),
                            );
                            return;
                          }

                          setState(() => _isLoading = true);

                          try {
                            bool hasError = false; // 에러 발생 여부를 기억

                            for (int i = 0; i < 4; i++) {
                              // 현재 칸이 기존에 서버에 있던 칸인지 확인 (ID가 0이면 새로 적은 칸)
                              int existingTodoId = 0;
                              // 목록이 비어있지 않을 때만 안전하게 기존 ID 찾음
                              if (_currentIndex != -1 &&
                                  _savedChecklists.isNotEmpty &&
                                  _currentIndex < _savedChecklists.length &&
                                  i <
                                      _savedChecklists[_currentIndex]['tasks']
                                          .length) {
                                existingTodoId =
                                    _savedChecklists[_currentIndex]['tasks'][i]['todoId'] ??
                                    0;
                              }

                              if (_titleControllers[i].text.isNotEmpty) {
                                String combinedDesc =
                                    '${_targetController.text}|#|${_titleControllers[i].text}|#|${_subControllers[i].text}';

                                if (existingTodoId != 0) {
                                  // 기존 데이터 수정 시 PATCH(update) 호출
                                  final response = await ApiService.updateTodo(
                                    existingTodoId,
                                    description: combinedDesc,
                                  );
                                  if (response.statusCode != 200 &&
                                      response.statusCode != 201) {
                                    hasError = true;
                                    debugPrint(
                                      "TODO 수정 서버 에러: ${response.statusCode} / ${response.body}",
                                    );
                                  }
                                } else {
                                  // 새 데이터 추가 시 POST(add) 호출
                                  final response = await ApiService.addTodo(
                                    taskType: 'MANUAL',
                                    description: combinedDesc,
                                  );

                                  if (response.statusCode != 200 &&
                                      response.statusCode != 201) {
                                    hasError = true;
                                    debugPrint(
                                      "TODO 저장 서버 에러: ${response.statusCode} / ${response.body}",
                                    );
                                  }
                                }
                              } else {
                                // 원래 있던 글자를 다 지운 경우 DELETE 호출
                                if (existingTodoId != 0) {
                                  await ApiService.deleteTodo(existingTodoId);
                                }
                              }
                            }

                            // 저장 끝나면 목록 다시 불러옴
                            await fetchTodos();

                            if (mounted) {
                              // 에러 나거나 목록이 비었으면 화면 억지로 넘기지 X
                              if (_savedChecklists.isEmpty || hasError) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('서버 통신 문제로 정상 저장되지 않았습니다.'),
                                  ),
                                );
                              } else {
                                // 서버에 정상적으로 저장됐을 때만 보기 화면(step=2)으로 이동
                                setState(() {
                                  _currentIndex = 0;
                                  _step = 2;
                                });
                              }
                            }
                          } catch (e) {
                            debugPrint("TODO 저장 실패: $e");
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('네트워크 연결이 끊어졌습니다. 다시 시도해주세요.'),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 30),
                        ),
                        child: const Text(
                          '저장',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        SizedBox(
          width: 150,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (index) => _buildEditTaskSlot(index)),
          ),
        ),
        const SizedBox(width: 29),
      ],
    );
  }

  Widget _buildStep2Saved() {
    if (_currentIndex == -1 || _savedChecklists.isEmpty)
      return const SizedBox();

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12.0, left: 13.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        const int itemsPerPage = 3;
                        _currentPage = (_currentIndex / itemsPerPage).floor();
                        _step = 3;
                      }),
                      child: Image.asset(
                        'assets/list_checklist.png',
                        width: 24,
                        height: 24,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.list,
                          size: 24,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => setState(() => _step = 1),
                      child: Image.asset(
                        'assets/update_checklist.png',
                        width: 24,
                        height: 24,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.edit,
                          size: 24,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _previousIndex = _currentIndex;
                          _currentIndex = -1;
                          _clearFields();
                          _step = 1;
                        });
                      },
                      child: Image.asset(
                        'assets/more_checklist.png',
                        width: 24,
                        height: 24,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.add_box_outlined,
                          size: 24,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _targetController.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 150,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              if (_titleControllers[index].text.isEmpty)
                return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: _buildViewTaskSlot(index),
              );
            }),
          ),
        ),
        const SizedBox(width: 29),
      ],
    );
  }

  Widget _buildEditTaskSlot(int index) {
    return Container(
      width: 150,
      height: 50,
      padding: const EdgeInsets.all(8),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 16,
                  child: TextField(
                    controller: _titleControllers[index],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    decoration: const InputDecoration(
                      hintText: '할 일 (필수)',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                SizedBox(
                  height: 14,
                  child: TextField(
                    controller: _subControllers[index],
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFACACAC),
                    ),
                    decoration: const InputDecoration(
                      hintText: '상세 내용 (선택)',
                      hintStyle: TextStyle(fontSize: 10, color: Colors.grey),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewTaskSlot(int index) {
    if (_titleControllers[index].text.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () async {
        // 체크박스 누를 때 서버로 상태 전송
        bool newDone = !_isDones[index];
        // 화면에 먼저 표시
        setState(() {
          _isDones[index] = newDone;
          _savedChecklists[_currentIndex]['tasks'][index]['isDone'] = newDone;
        });

        int todoId = _savedChecklists[_currentIndex]['tasks'][index]['todoId'];
        if (todoId != 0) {
          try {
            // 서버 통신 시도
            final response = await ApiService.updateTodo(
              todoId,
              status: newDone ? 'COMPLETED' : 'PENDING',
            );
            if (response.statusCode != 200 && response.statusCode != 201) {
              throw Exception('상태 코드 에러'); // 200번대 아니면 강제로 에러 발생
            }
          } catch (e) {
            // 서버 연결 실패 시 화면 체크 상태 원상 복구
            if (mounted) {
              setState(() {
                _isDones[index] = !newDone;
                _savedChecklists[_currentIndex]['tasks'][index]['isDone'] =
                    !newDone;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('네트워크 오류로 체크 상태를 변경하지 못했습니다')),
              );
            }
          }
        }
      },
      child: Container(
        width: 150,
        height: 50,
        padding: const EdgeInsets.all(8),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _isDones[index] ? const Color(0xFF00AA77) : Colors.white,
                border: Border.all(
                  color: _isDones[index]
                      ? const Color(0xFF00AA77)
                      : const Color(0xFFACACAC),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _isDones[index]
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _titleControllers[index].text,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      decoration: _isDones[index]
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_subControllers[index].text.isNotEmpty)
                    Text(
                      _subControllers[index].text,
                      style: const TextStyle(
                        color: Color(0xFFACACAC),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3ListView() {
    const int itemsPerPage = 3;
    int totalPages = _savedChecklists.isEmpty
        ? 1
        : (_savedChecklists.length / itemsPerPage).ceil();
    int startIndex = _currentPage * itemsPerPage;
    int endIndex = (startIndex + itemsPerPage > _savedChecklists.length)
        ? _savedChecklists.length
        : startIndex + itemsPerPage;
    List<Map<String, dynamic>> currentItems = _savedChecklists.sublist(
      startIndex,
      endIndex,
    );

    return Column(
      children: [
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => setState(() {
              if (_savedChecklists.isNotEmpty) {
                if (_currentIndex == -1 ||
                    _currentIndex >= _savedChecklists.length) {
                  _loadChecklist(0);
                }
                _step = 2;
              } else {
                _currentIndex = -1;
                _step = 0;
              }
            }),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: currentItems.length,
            itemBuilder: (context, i) {
              int realIndex = startIndex + i;
              return Column(
                children: [
                  SizedBox(
                    height: 50,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() {
                              _loadChecklist(realIndex);
                              _step = 2;
                            }),
                          ),
                        ),
                        Center(
                          child: IgnorePointer(
                            child: Text(
                              currentItems[i]['target'],
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 32,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    title: const Text(
                                      '삭제 확인',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    content: const Text(
                                      '이 체크리스트를 정말 삭제하시겠습니까?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(),
                                        child: const Text(
                                          '취소',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.of(ctx).pop();

                                          // 삭제 시 서버에서 해당 묶음의 TODO 전부 삭제(DELETE)
                                          setState(() => _isLoading = true);
                                          try {
                                            var tasksToDelete =
                                                _savedChecklists[realIndex]['tasks'];
                                            for (var task in tasksToDelete) {
                                              if (task['todoId'] != 0) {
                                                await ApiService.deleteTodo(
                                                  task['todoId'],
                                                );
                                              }
                                            }

                                            await fetchTodos();
                                          } catch (e) {
                                            debugPrint("TODO 삭제 실패: $e");
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    '네트워크 연결 문제로 삭제하지 못했습니다.',
                                                  ),
                                                ),
                                              );
                                            }
                                          } finally {
                                            if (mounted)
                                              setState(
                                                () => _isLoading = false,
                                              );
                                          }
                                        },
                                        child: const Text(
                                          '삭제',
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Image.asset(
                                'assets/delete_checklist.png',
                                width: 25,
                                height: 25,
                                errorBuilder: (c, e, s) => const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 287,
                    height: 1,
                    color: const Color(0xFFBDBABA),
                  ),
                ],
              );
            },
          ),
        ),
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (index) {
                bool isSelected = (_currentPage == index);
                return GestureDetector(
                  onTap: () => setState(() => _currentPage = index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? Colors.black
                            : const Color(0xFFBDBABA),
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
