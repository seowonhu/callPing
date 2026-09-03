import 'package:flutter/material.dart';

import 'chat_screen.dart'; // 챗봇 화면
import 'analytics_screen.dart'; // 분석 화면
import 'settings_screen.dart'; // 설정 화면
import 'guide_screen.dart'; // 통화 가이드 화면

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildMainTab(),
      const ChatScreen(), // (채팅 화면 위젯 이름에 맞춰 수정하세요)
      const AnalyticsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
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
      // IndexedStack 유지 (탭 이동 시 상태 보존)
      body: IndexedStack(index: _selectedIndex, children: pages),
    );
  }

  // 0번 탭: 메인 화면 구성
  Widget _buildMainTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(child: InlineChecklistBox()), // (기존에 만드신 체크리스트 박스)
            const SizedBox(height: 55),

            _buildMenuButton('통화 가이드', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GuideInputScreen(),
                ),
              );
            }),
            const SizedBox(height: 20),

            _buildMenuButton('대본 보관함', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScriptLibraryScreen(),
                ),
              );
            }),
            const SizedBox(height: 20),

            // 파일 업로드 버튼 누르면 2번 탭(분석)으로 이동
            _buildMenuButton('파일 업로드', () {
              setState(() {
                _selectedIndex = 2;
              });
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 메뉴 버튼 커스텀 위젯
  Widget _buildMenuButton(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 85,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ============================================================================
// 피그마 디자인을 반영한 인라인 편집
// ============================================================================

int _currentIndex = -1;
int _previousIndex = -1; // 내가 원래 보던 체크리스트 글의 번호를 임시로 기억해 둘 변수
int _currentPage = 0;

class InlineChecklistBox extends StatefulWidget {
  @override
  _InlineChecklistBoxState createState() => _InlineChecklistBoxState();
}

class _InlineChecklistBoxState extends State<InlineChecklistBox> {
  int _step = 0;
  List<Map<String, dynamic>> _savedChecklists = [];
  int _currentIndex = -1;
  int _currentPage = 0;

  // 각 4개의 칸을 직접 통제하기 위해 컨트롤러를 4개씩 둠
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

  // 모든 빈칸 초기화 (새로 만들 때)
  void _clearFields() {
    _targetController.clear();
    for (int i = 0; i < 4; i++) {
      _titleControllers[i].clear();
      _subControllers[i].clear();
      _isDones[i] = false;
    }
  }

  // 빈칸 채우기 (목록에서 눌렀을 때)
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
      child: _step == 0
          ? _buildStep0Empty()
          : _step == 1
          ? _buildStep1Editing()
          : _step == 2
          ? _buildStep2Saved()
          : _buildStep3ListView(),
    );
  }

  // [상태 0] 빈 화면
  Widget _buildStep0Empty() {
    return GestureDetector(
      onTap: () => setState(() {
        _currentIndex = -1;
        _clearFields();
        _step = 1;
      }),
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
    );
  }

  // --------------------------------------------------
  // [체크리스트 상태 1] 입력 화면
  // --------------------------------------------------
  Widget _buildStep1Editing() {
    return Row(
      children: [
        // 왼쪽 구역: 제목 입력칸 + 취소/저장 버튼
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Column(
              children: [
                const SizedBox(height: 30), // 위쪽 여백 (아이콘 자리 비워둠)
                // 중앙에 제목 입력칸
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
                // 하단 취소/저장 버튼
                Row(
                  children: [
                    // 취소 버튼
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() {
                          // 1. 기존 글 수정 중 -> 그 글 내용으로 되돌리고 뷰어(2)로 복귀
                          if (_currentIndex != -1) {
                            _loadChecklist(_currentIndex);
                            _step = 2; // 뷰어로 복귀
                          }
                          // 2. 새로 만드려다가 취소
                          else {
                            if (_previousIndex != -1) {
                              // 1. 기존에 보던 체크리스트가 있었다면 -> 그 체크리스트 내용으로 되돌리고 뷰어(2)로 복귀
                              _loadChecklist(_previousIndex);
                              _step = 2;
                              _previousIndex = -1;
                            } else {
                              // 3. 저장된 게 하나도 없는 최초 상태였다면? -> 빈 화면(0)으로
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
                        onPressed: () {
                          // 저장 로직!
                          List<Map<String, dynamic>> newTasks = [];
                          for (int i = 0; i < 4; i++) {
                            if (_titleControllers[i].text.isNotEmpty) {
                              newTasks.add({
                                'title': _titleControllers[i].text,
                                'sub': _subControllers[i].text,
                                'isDone': _isDones[i],
                              });
                            }
                          }
                          if (_targetController.text.isEmpty ||
                              newTasks.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('제목과 할 일을 1개 이상 적어주세요!'),
                              ),
                            );
                            return;
                          }
                          setState(() {
                            var newData = {
                              'target': _targetController.text,
                              'tasks': newTasks,
                            };
                            if (_currentIndex == -1) {
                              _savedChecklists.add(newData);
                              _currentIndex = _savedChecklists.length - 1;
                            } else {
                              _savedChecklists[_currentIndex] = newData;
                            }
                            _step = 2; // 뷰어로 이동
                          });
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

  // --------------------------------------------------
  // [체크리스트 상태 2] 뷰어 화면 (가운데 정렬 적용)
  // --------------------------------------------------
  Widget _buildStep2Saved() {
    return Row(
      children: [
        // 왼쪽 구역: 3개 아이콘 + 중앙 대상 이름 (기존 동일)
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12.0, left: 13.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        // 만약 현재 보고 있는 글(_currentIndxt)이 있다면, 그 글이 몇 번째인지 찾아서 페이지 계산
                        if (_currentIndex != -1) {
                          const int itemsPerPage = 3;
                          _currentPage = (_currentIndex / itemsPerPage)
                              .floor(); // 0번 ~ 2번은 0페이지, 3번 ~ 5번은 1페이지
                        } else {
                          _currentPage = 0; // 현재 보고 있는 글이 없으면 그냥 0페이지
                        }
                        _step = 3; // 목록 화면으로 이동
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
                        if (_savedChecklists.length >= 15) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('최대 15개까지만 만들 수 있어요!'),
                            ),
                          );
                          return;
                        }
                        setState(() {
                          _previousIndex =
                              _currentIndex; // 내가 원래 보던 체크리스트 글의 번호를 임시로 기억해 둠
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

        // 오른쪽 구역: 작성된 내용만 모아서 세로로 가운데 정렬
        SizedBox(
          width: 150,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // 개수에 상관없이 정중앙으로 모음
            children: List.generate(4, (index) {
              // 아무것도 안 적은 빈칸은 아예 공간조차 차지하지 않게
              if (_titleControllers[index].text.isEmpty)
                return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 4.0,
                ), // 블록들 사이의 위아래 틈새 간격
                child: _buildViewTaskSlot(index),
              );
            }),
          ),
        ),
        const SizedBox(width: 29),
      ],
    );
  }

  // 편집 화면용 빈칸 슬롯 (입력하는 곳)
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
          ), // 가짜 체크박스
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

  // 뷰어 화면용 결과물 슬롯 (빈칸 방지 처리)
  Widget _buildViewTaskSlot(int index) {
    if (_titleControllers[index].text.isEmpty)
      return const SizedBox.shrink(); // 안전장치 한 번 더

    return GestureDetector(
      onTap: () {
        setState(() {
          _isDones[index] = !_isDones[index];
          _savedChecklists[_currentIndex]['tasks'][index]['isDone'] =
              _isDones[index];
        });
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

  // --------------------------------------------------
  // [체크리스트 상태 3] 전체 목록 화면 (페이지네이션 + 삭제 확인 팝업)
  // --------------------------------------------------
  Widget _buildStep3ListView() {
    const int itemsPerPage = 3;
    int totalPages = (_savedChecklists.isEmpty)
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
              // 안전장치: X를 눌러서 닫을 때, 데이터는 있는데 _currentIndex가 꼬였다면 첫 번째 항목을 띄움
              if (_savedChecklists.isNotEmpty) {
                if (_currentIndex == -1 ||
                    _currentIndex >= _savedChecklists.length) {
                  _loadChecklist(0);
                }
                _step = 2; // 뷰어 화면으로 복귀
              } else {
                _currentIndex = -1;
                _step = 0; // 데이터 없을 때만 빈 화면으로
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
                        // 1. 배경 (상세 보기)
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() {
                              _loadChecklist(realIndex);
                              _step = 2;
                            }),
                          ),
                        ),

                        // 2. 글씨 (대상 이름)
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

                        // 3. 휴지통 아이콘 (삭제 확인 팝업 추가)
                        Positioned(
                          right: 32,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: () {
                                // 휴지통을 누르면 팝업창을 띄우고 인덱스 꼬임 방어
                                showDialog(
                                  context: context,
                                  builder: (BuildContext ctx) {
                                    return AlertDialog(
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
                                        // 취소 버튼
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
                                        // 삭제 버튼
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(ctx).pop(); // 팝업 닫기

                                            setState(() {
                                              // 1. 해당 체크리스트 삭제
                                              _savedChecklists.removeAt(
                                                realIndex,
                                              );

                                              // 2. 비어있을 경우
                                              if (_savedChecklists.isEmpty) {
                                                _currentIndex = -1;
                                                _step = 0;
                                              } else {
                                                // 3. 인덱스 꼬임 방지 및 페이지 유지 로직
                                                int newTotalPages =
                                                    (_savedChecklists.length /
                                                            itemsPerPage)
                                                        .ceil();
                                                if (_currentPage >=
                                                    newTotalPages) {
                                                  _currentPage =
                                                      newTotalPages - 1;
                                                }

                                                // 만약 내가 방금 지운 게 지금 화면에 띄워져 있던 거라면, _currentIndex 번호만 초기화(-1)
                                                if (_currentIndex ==
                                                    realIndex) {
                                                  _currentIndex = -1;
                                                } else if (_currentIndex >
                                                    realIndex) {
                                                  _currentIndex--;
                                                }
                                              }
                                            });
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
                                    );
                                  },
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
