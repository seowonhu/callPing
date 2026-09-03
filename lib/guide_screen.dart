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
  final String helpContent; // 도움말 내용
  final String date;

  ScriptItem({
    required this.id,
    required this.title,
    required this.target,
    required this.tone,
    required this.detail,
    required this.scriptContent,
    required this.helpContent, // 도움말을 필수값으로 추가
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'target': target,
    'tone': tone,
    'detail': detail,
    'scriptContent': scriptContent,
    'helpContent': helpContent, // 도움말 저장 로직
  };

  factory ScriptItem.fromJson(Map<String, dynamic> json) => ScriptItem(
    id: json['id'] ?? '',
    title: json['title'] ?? '통화 가이드',
    target: json['target'] ?? '',
    tone: json['tone'] ?? '',
    detail: json['detail'] ?? '',
    scriptContent: json['scriptContent'] ?? '',
    helpContent: json['helpContent'] ?? '도움말 정보가 없습니다.', // 도움말 불러오기 로직
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

      print("서버로 대본 생성 요청 보냄: 대상=$_selectedTarget, 내용=$description");

      final response = await ApiService.createGuide(
        _selectedTarget,
        description,
      );

      print("서버 응답 코드: ${response.statusCode}");
      print("서버 응답 데이터: ${utf8.decode(response.bodyBytes)}");

      if (response.statusCode == 201) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final data = responseData['data'];

        // 서버가 tips를 배열([ ])로 주기 때문에, 줄바꿈(\n\n)으로 이어 붙여서 하나의 텍스트로 만듦
        // List<dynamic> rawTips = data['tips'] ?? [];
        // String formattedTips = rawTips.join('\n\n');

        // 서버가 배열(list)로 주든 텍스트(String)로 주든 모두 처리
        String formattedTips = '';
        if (data['tips'] is List) {
          formattedTips = (data['tips'] as List).join('\n\n');
        } else if (data['tips'] is String) {
          formattedTips = data['tips'];
        }

        ScriptItem newItem = ScriptItem(
          id:
              data['guide_id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch
                  .toString(), // guide_id가 없으면 현재 시간으로 대체
          title: data['title'] ?? '통화 가이드',
          target: _selectedTarget,
          tone: _selectedTone,
          detail: _detailController.text,
          // answer 대신 script
          scriptContent:
              data['script'] ??
              data['answer'] ??
              data['description'] ??
              '대본 내용 없음', // 서버에서 받아온 대본 내용
          // 백엔드에서 추가할 도움말 필드 (ex. tips / help)
          helpContent: formattedTips.isEmpty
              ? '도움말 정보가 없습니다.'
              : formattedTips, // 서버에서 받아온 도움말 내용
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
            SnackBar(
              content: Text('대본 생성에 실패했습니다. (코드: ${response.statusCode})'),
            ),
          );
        }
      }
    } catch (e) {
      print("대본 생성 통신 에러 발생: $e");
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

      // 버튼 하단 고정을 위해 구조 변경 (Padding 안에 Column과 Expanded 사용)
      body: SingleChildScrollView(
        child: Padding(
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

              const SizedBox(height: 120), // 숫자를 키울수록 버튼이 아래로 밀려남
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
              const SizedBox(height: 40),
            ],
          ),
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
  final bool isFromLibrary; // 대본 보관함에서 왔는지 확인하는 꼬리표

  const GuideResultScreen({
    super.key,
    required this.scriptItem,
    this.isFromLibrary = false, // 기본값은 false(홈에서 왔다고 가정)
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
          // pop 대신 popUntil 사용하여 첫 화면으로 돌아가도록 변경
          onPressed: () {
            if (isFromLibrary) {
              // 보관함에서 온 경우 : pop 한 번만
              Navigator.pop(context);
            } else {
              // 새로 만든 경우 : 홈 화면(isFirst)만 남기고 찌꺼기 화면들 지운 뒤 새 입력창 띄움
              Navigator.popUntil(context, (route) => route.isFirst);
            }
          },
        ),
        title: const Text(
          '통화 가이드',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // --------------------
            // 1. '나' (대본) 박스
            // --------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE3EBF8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black87),
              ),
              child: Column(
                // 라벨과 텍스트가 한 덩어리로 뭉치도록 설정
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 라벨(항상 위에 고정)
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

                  // 2. 텍스트 영역 *최소 높이 주고 내부에서 수직 중앙 정렬)
                  Container(
                    // 글자가 들어갈 공간의 최소 높이 100 (조절 가능)
                    constraints: const BoxConstraints(minHeight: 100),
                    alignment: Alignment.centerLeft, // 텍스트 수직 중앙, 수평 왼쪽 정렬
                    padding: const EdgeInsets.only(top: 16), // 라벨과의 관격
                    child: Text(
                      scriptItem.scriptContent,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // --------------------
            // 2. 도움말 박스
            // --------------------
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
                  // 1. 라벨 (위에 고정)
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

                  // 2. 텍스트 영역 (최소 높이 주고 내부에서 수직 중앙 정렬)
                  Container(
                    // 도움말 공간의 최소 높이 100 (조절 가능)
                    constraints: const BoxConstraints(minHeight: 100),
                    alignment: Alignment.centerLeft, // 수직 중앙 정렬
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      scriptItem.helpContent ??
                          '도움말 내용 없음', // 서버에서 받아온 도움말 내용, helpContent 부분은 백엔드 api 명세에 따라 수정
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 75), // 기존에 40이었음. 숫자 키울수록 버튼이 더 아래로 향함
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
                      padding: const EdgeInsets.symmetric(
                        vertical: 30,
                      ), // vertical 기존에 16. 버튼 높이 키우기
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
                      if (isFromLibrary) {
                        // 보관함에서 온 경우 : pop 한 번만
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GuideInputScreen(
                              initialTarget: scriptItem.target,
                              initialTone: scriptItem.tone,
                              initialDetail: scriptItem.detail,
                            ),
                          ),
                        );
                      } else {
                        // 새로 만든 경우 : 홈 화면(isFirst)만 남기고 찌꺼기 화면들 지운 뒤 새 입력창 띄움
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GuideInputScreen(
                              initialTarget: scriptItem.target,
                              initialTone: scriptItem.tone,
                              initialDetail: scriptItem.detail,
                            ),
                          ),
                          (route) => route.isFirst,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        vertical: 30,
                      ), // 위랑 동일하게 16에서 늘림(버튼 높이 키우기)
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

            const SizedBox(height: 40), // 네비게이션 바와 버튼이 붙지 않도록 화면 아래에 여백 추가
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
                                builder: (context) => GuideResultScreen(
                                  scriptItem: item,
                                  isFromLibrary: true, // 보관함에서 왔을 때
                                ),
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
