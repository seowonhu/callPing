import 'package:flutter/material.dart';

import 'chat_screen.dart'; // 챗봇 화면
import 'analytics_screen.dart'; // 분석 화면
import 'settings_screen.dart'; // 설정 화면
import 'guide_screen.dart'; // 통화 가이드 화면

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex;

  // ⭐️ 1번 탭 안에서만 화면이 이동하도록 잡아주는 전용 네비게이터 키
  final GlobalKey<NavigatorState> _homeNavKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      // ⭐️ 1번 탭(콜핑)을 Navigator로 감싸서 하단 바가 가려지지 않게 보호합니다.
      Navigator(
        key: _homeNavKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            // ⭐️ 주의: navContext를 전달해야 하단 바 안에서만 화면이 바뀝니다!
            builder: (navContext) => _buildMainTab(navContext),
          );
        },
      ),
      const ChatScreen(),
      const AnalyticsScreen(),
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
            // 이미 보고 있는 홈 탭을 한 번 더 누르면 첫 화면으로 싹 정리해주는 기능
            if (index == _selectedIndex && index == 0) {
              _homeNavKey.currentState?.popUntil((route) => route.isFirst);
            }
            setState(() => _selectedIndex = index);
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
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(child: InlineChecklistBox()),
            const SizedBox(height: 55),

            _buildMenuButton('통화 가이드', () {
              Navigator.push(
                navContext, // ⭐️ 전체 context가 아닌 내부 navContext 사용!
                MaterialPageRoute(
                  builder: (context) => const GuideInputScreen(),
                ),
              );
            }),
            const SizedBox(height: 20),

            _buildMenuButton('대본 보관함', () {
              Navigator.push(
                navContext, // ⭐️ 전체 context가 아닌 내부 navContext 사용!
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
// 피그마 디자인을 반영한 인라인 편집 (기존 코드 그대로 유지)
// ============================================================================

int _currentIndex = -1;
int _previousIndex = -1;
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
      child: _step == 0
          ? _buildStep0Empty()
          : _step == 1
          ? _buildStep1Editing()
          : _step == 2
          ? _buildStep2Saved()
          : _buildStep3ListView(),
    );
  }

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
                        onPressed: () {
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
                            _step = 2;
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

  Widget _buildStep2Saved() {
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
                        if (_currentIndex != -1) {
                          const int itemsPerPage = 3;
                          _currentPage = (_currentIndex / itemsPerPage).floor();
                        } else {
                          _currentPage = 0;
                        }
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
                        if (_savedChecklists.length >= 15) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('최대 15개까지만 만들 수 있어요!'),
                            ),
                          );
                          return;
                        }
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
                                          onPressed: () {
                                            Navigator.of(ctx).pop();
                                            setState(() {
                                              _savedChecklists.removeAt(
                                                realIndex,
                                              );
                                              if (_savedChecklists.isEmpty) {
                                                _currentIndex = -1;
                                                _step = 0;
                                              } else {
                                                int newTotalPages =
                                                    (_savedChecklists.length /
                                                            itemsPerPage)
                                                        .ceil();
                                                if (_currentPage >=
                                                    newTotalPages) {
                                                  _currentPage =
                                                      newTotalPages - 1;
                                                }
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
