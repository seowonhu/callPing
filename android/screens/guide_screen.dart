import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

// ==========================================
// 1. 대본 데이터 모델
// ==========================================
class ScriptItem {
  final String id;
  final String title;
  final String target;
  final String tone;
  final String detail;
  final String scriptContent;
  final String date;

  ScriptItem({
    required this.id,
    required this.title,
    required this.target,
    required this.tone,
    required this.detail,
    required this.scriptContent,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'target': target,
    'tone': tone,
    'detail': detail,
    'scriptContent': scriptContent,
    'date': date,
  };

  factory ScriptItem.fromJson(Map<String, dynamic> json) => ScriptItem(
    id: json['id'] ?? '',
    title: json['title'] ?? '통화 가이드',
    target: json['target'] ?? '',
    tone: json['tone'] ?? '',
    detail: json['detail'] ?? '',
    scriptContent: json['scriptContent'] ?? '',
    date: json['date'] ?? '',
  );
}

List<ScriptItem> globalScriptLibrary = [];

Future<void> saveScriptLibrary() async {
  final prefs = await SharedPreferences.getInstance();
  final encoded = jsonEncode(
    globalScriptLibrary.map((e) => e.toJson()).toList(),
  );
  await prefs.setString('script_library', encoded);
}

Future<void> loadScriptLibrary() async {
  final prefs = await SharedPreferences.getInstance();
  final encoded = prefs.getString('script_library');
  if (encoded != null) {
    globalScriptLibrary = (jsonDecode(encoded) as List)
        .map((e) => ScriptItem.fromJson(e))
        .toList();
  }
}

// ==========================================
// 공통 하단 네비게이션 바 생성 함수
// ==========================================
Widget _buildCommonBottomNavBar(BuildContext context) {
  return BottomNavigationBar(
    currentIndex: 0,
    type: BottomNavigationBarType.fixed,
    selectedItemColor: const Color(0xFF1A9000),
    unselectedItemColor: Colors.black,
    onTap: (index) {
      if (index == 0) {
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('원하시는 탭을 다시 선택해주세요.')));
      }
    },
    items: [
      BottomNavigationBarItem(
        icon: Image.asset(
          'assets/home.png',
          width: 24,
          height: 24,
          color: const Color(0xFF1A9000),
        ),
        label: '콜핑',
      ),
      BottomNavigationBarItem(
        icon: Image.asset(
          'assets/chat.png',
          width: 24,
          height: 24,
          color: Colors.black,
        ),
        label: '챗봇',
      ),
      BottomNavigationBarItem(
        icon: Image.asset(
          'assets/analytic.png',
          width: 24,
          height: 24,
          color: Colors.black,
        ),
        label: '분석',
      ),
      BottomNavigationBarItem(
        icon: Image.asset(
          'assets/setting.png',
          width: 24,
          height: 24,
          color: Colors.black,
        ),
        label: '설정',
      ),
    ],
  );
}

// ==========================================
// 2. 통화 가이드 입력 화면
// ==========================================
class GuideInputScreen extends StatefulWidget {
  final String initialTarget;
  final String initialTone;
  final String initialDetail;

  const GuideInputScreen({
    super.key,
    this.initialTarget = '병원',
    this.initialTone = '정중하게',
    this.initialDetail = '',
  });

  @override
  State<GuideInputScreen> createState() => _GuideInputScreenState();
}

class _GuideInputScreenState extends State<GuideInputScreen> {
  late String _selectedTarget;
  late String _selectedTone;
  late final TextEditingController _detailController;

  bool _isInputNotEmpty = false;
  bool _isLoading = false;

  final List<String> _targets = ['병원', '쇼핑몰', '은행', '기타'];
  final List<String> _tones = ['정중하게', '단호하게', '다급하게', '사무적으로'];

  @override
  void initState() {
    super.initState();
    _selectedTarget = widget.initialTarget;
    _selectedTone = widget.initialTone;
    _detailController = TextEditingController(text: widget.initialDetail);
    _isInputNotEmpty = _detailController.text.trim().isNotEmpty;

    loadScriptLibrary();
    _detailController.addListener(() {
      setState(() {
        _isInputNotEmpty = _detailController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _createGuide() async {
    setState(() => _isLoading = true);

    try {
      String description = "[$_selectedTone] ${_detailController.text}";
      final response = await ApiService.createGuide(
        _selectedTarget,
        description,
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final data = responseData['data'];

        ScriptItem newItem = ScriptItem(
          id: data['guide_id'].toString(),
          title: data['title'] ?? '통화 가이드',
          target: _selectedTarget,
          tone: _selectedTone,
          detail: _detailController.text,
          scriptContent: data['answer'],
          date: '${DateTime.now().month}월 ${DateTime.now().day}일',
        );

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GuideResultScreen(scriptItem: newItem),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('대본 생성에 실패했습니다. 다시 시도해주세요.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('서버 통신 에러가 발생했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
        title: const Text(
          '통화 가이드',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: _buildCommonBottomNavBar(context),
      // 버튼 하단 고정을 위해 구조 변경 (Padding 안에 Column과 Expanded 사용)
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '상대',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 12,
              children: _targets
                  .map(
                    (target) => _buildChoiceChip(
                      label: target,
                      isSelected: _selectedTarget == target,
                      onTap: () => setState(() => _selectedTarget = target),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 32),
            const Text(
              '말투',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 12,
              children: _tones
                  .map(
                    (tone) => _buildChoiceChip(
                      label: tone,
                      isSelected: _selectedTone == tone,
                      onTap: () => setState(() => _selectedTone = tone),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 32),
            const Text(
              '더 자세한 상황을 알려주세요',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '예) 오늘 오후 2시 예약인데 30분 정도 늦을 것 같아서 미루고 싶어',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 60),

            // 대본 생성하기 버튼
            Center(
              child: ElevatedButton(
                onPressed: (_isInputNotEmpty && !_isLoading)
                    ? _createGuide
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isInputNotEmpty
                      ? const Color(0xFFA5C5F4)
                      : const Color(0xFFE0E0E0),
                  foregroundColor: _isInputNotEmpty
                      ? Colors.black
                      : Colors.grey,
                  minimumSize: const Size(200, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        '대본 생성하기',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFA5C5F4) : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. 통화 가이드 결과
// ==========================================
class GuideResultScreen extends StatelessWidget {
  final ScriptItem scriptItem;
  const GuideResultScreen({super.key, required this.scriptItem});

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
        title: const Text(
          '통화 가이드',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: _buildCommonBottomNavBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE3EBF8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black87),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB5B9DF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.black87),
                    ),
                    child: const Text(
                      '나',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    scriptItem.scriptContent,
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD5D5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black87),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB284),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.black87),
                    ),
                    child: const Text(
                      '도움말',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '• 거절 시 대안 묻기 : "혹시 오늘 남는 다른 시간대가 있을까요?" 라고 차분히 물어보세요.\n\n• 메모 준비하기 : 상대방이 변경된 예약이나 안내 사항을 말해줄 수 있으니 메모를 준비하세요.',
                    style: TextStyle(fontSize: 14, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (!globalScriptLibrary.any(
                        (e) => e.id == scriptItem.id,
                      )) {
                        globalScriptLibrary.insert(0, scriptItem);
                        saveScriptLibrary();
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('대본 보관함에 저장되었습니다!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Colors.black),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '저장하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GuideInputScreen(
                            initialTarget: scriptItem.target,
                            initialTone: scriptItem.tone,
                            initialDetail: scriptItem.detail,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Colors.black),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '다시 입력하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. 대본 보관함 목록 화면
// ==========================================
class ScriptLibraryScreen extends StatefulWidget {
  const ScriptLibraryScreen({super.key});

  @override
  State<ScriptLibraryScreen> createState() => _ScriptLibraryScreenState();
}

class _ScriptLibraryScreenState extends State<ScriptLibraryScreen> {
  @override
  void initState() {
    super.initState();
    loadScriptLibrary();
  }

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
        title: const Text(
          '대본 보관함',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: _buildCommonBottomNavBar(context),
      body: globalScriptLibrary.isEmpty
          ? const Center(
              child: Text(
                '저장된 대본이 없습니다.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24.0),
              itemCount: globalScriptLibrary.length,
              itemBuilder: (context, index) {
                final item = globalScriptLibrary[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    GuideResultScreen(scriptItem: item),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.date,
                                style: const TextStyle(
                                  color: Color(0xFFA3A0A0),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.title,
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
                        onPressed: () {
                          setState(() {
                            globalScriptLibrary.removeAt(index);
                            saveScriptLibrary();
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
