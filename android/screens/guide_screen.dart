import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

// ==========================================
// 대본 데이터 모델
// ==========================================
class ScriptItem {
  final String id;
  final String title;
  final String target;
  final String tone;
  final String detail;
  final String scriptContent;
  final String helpContent;
  final String date;

  ScriptItem({
    required this.id,
    required this.title,
    required this.target,
    required this.tone,
    required this.detail,
    required this.scriptContent,
    required this.helpContent,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'target': target,
    'tone': tone,
    'detail': detail,
    'scriptContent': scriptContent,
    'helpContent': helpContent,
    'date': date,
  };

  factory ScriptItem.fromJson(Map<String, dynamic> json) => ScriptItem(
    id: json['id'] ?? '',
    title: json['title'] ?? '통화 가이드',
    target: json['target'] ?? '',
    tone: json['tone'] ?? '',
    detail: json['detail'] ?? '',
    scriptContent: json['scriptContent'] ?? '',
    helpContent: json['helpContent'] ?? '도움말 정보가 없습니다.',
    date: json['date'] ?? '',
  );
}

// ==========================================
// 통화 가이드 입력 화면
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
  late final TextEditingController _otherTargetController;

  bool _isInputNotEmpty = false;
  bool _isLoading = false;

  final List<String> _targets = ['병원', '쇼핑몰', '은행', '기타'];
  final List<String> _tones = ['정중하게', '단호하게', '다급하게', '사무적으로'];

  @override
  void initState() {
    super.initState();
    if (_targets.contains(widget.initialTarget)) {
      _selectedTarget = widget.initialTarget;
      _otherTargetController = TextEditingController();
    } else {
      _selectedTarget = '기타';
      _otherTargetController = TextEditingController(
        text: widget.initialTarget == '기타' ? '' : widget.initialTarget,
      );
    }

    if (_tones.contains(widget.initialTone)) {
      _selectedTone = widget.initialTone;
    } else {
      _selectedTone = '정중하게';
    }

    _detailController = TextEditingController(text: widget.initialDetail);
    _isInputNotEmpty = _detailController.text.trim().isNotEmpty;

    void updateUI() {
      setState(() {
        _isInputNotEmpty = _detailController.text.trim().isNotEmpty;
      });
    }

    _detailController.addListener(updateUI);
    _otherTargetController.addListener(updateUI);
  }

  @override
  void dispose() {
    _detailController.dispose();
    _otherTargetController.dispose();
    super.dispose();
  }

  Future<void> _createGuide() async {
    setState(() => _isLoading = true);

    try {
      String finalTarget = _selectedTarget == '기타'
          ? (_otherTargetController.text.trim().isEmpty
                ? '기타'
                : _otherTargetController.text.trim())
          : _selectedTarget;

      String description =
          "[$finalTarget][$_selectedTone] ${_detailController.text}";

      print("서버로 대본 생성 요청 보냄: 대상=$finalTarget, 내용=$description");

      final response = await ApiService.createGuide(
        finalTarget,
        description,
      ).timeout(const Duration(seconds: 90));

      print("서버 응답 코드: ${response.statusCode}");

      if (response.statusCode == 201) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final data = responseData['data'];

        String formattedTips = '';
        if (data['tips'] is List) {
          formattedTips = (data['tips'] as List).join('\n\n');
        } else if (data['tips'] is String) {
          formattedTips = data['tips'];
        }

        ScriptItem newItem = ScriptItem(
          id:
              data['guide_id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          title: data['title'] ?? '통화 가이드',
          target: finalTarget,
          tone: _selectedTone,
          detail: _detailController.text,
          scriptContent:
              data['script'] ??
              data['answer'] ??
              data['description'] ??
              '대본 내용 없음',
          helpContent: formattedTips.isEmpty ? '도움말 정보가 없습니다.' : formattedTips,
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
    bool isOtherTargetFilled =
        _selectedTarget != '기타' ||
        _otherTargetController.text.trim().isNotEmpty;
    bool canSubmit = _isInputNotEmpty && isOtherTargetFilled && !_isLoading;

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
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                value: _selectedTarget,
                items: _targets
                    .map(
                      (target) =>
                          DropdownMenuItem(value: target, child: Text(target)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedTarget = value);
                },
              ),
              Visibility(
                visible: _selectedTarget == '기타',
                child: Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: TextField(
                    controller: _otherTargetController,
                    decoration: const InputDecoration(
                      hintText: '예) 동네 세탁소, 미용실 등',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                '말투',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                value: _selectedTone,
                items: _tones
                    .map(
                      (tone) =>
                          DropdownMenuItem(value: tone, child: Text(tone)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedTone = value);
                },
              ),
              const SizedBox(height: 32),
              const Text(
                '더 자세한 상황을 알려주세요 (필수)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _detailController,
                maxLines: 3,
                textInputAction: TextInputAction.done,
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
              const SizedBox(height: 90),
              Center(
                child: ElevatedButton(
                  onPressed: canSubmit ? _createGuide : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canSubmit
                        ? const Color(0xFFA5C5F4)
                        : const Color(0xFFE0E0E0),
                    foregroundColor: canSubmit ? Colors.black : Colors.grey,
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
}

// ==========================================
// 3. 통화 가이드 결과
// ==========================================
class GuideResultScreen extends StatelessWidget {
  final ScriptItem scriptItem;
  final bool isFromLibrary;

  const GuideResultScreen({
    super.key,
    required this.scriptItem,
    this.isFromLibrary = false,
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
        title: const Text(
          '통화 가이드',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
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
                  Container(
                    constraints: const BoxConstraints(minHeight: 100),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      scriptItem.scriptContent,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
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
                  Container(
                    constraints: const BoxConstraints(minHeight: 100),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      scriptItem.helpContent,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 75),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScriptLibraryScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Colors.black),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '보관함 가기',
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
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 30),
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
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 대본 보관함 목록 화면
// ==========================================
class ScriptLibraryScreen extends StatefulWidget {
  const ScriptLibraryScreen({super.key});

  @override
  State<ScriptLibraryScreen> createState() => _ScriptLibraryScreenState();
}

class _ScriptLibraryScreenState extends State<ScriptLibraryScreen> {
  List<dynamic> _guides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGuides();
  }

  Future<void> _fetchGuides() async {
    try {
      final response = await ApiService.getGuides();
      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        print("보관함 리스트 응답 데이터: $responseData");
        if (mounted) {
          setState(() {
            _guides = responseData['data'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '날짜 없음';
    try {
      DateTime date = DateTime.parse(isoString).toLocal();
      return '${date.month}월 ${date.day}일';
    } catch (e) {
      return '날짜 오류';
    }
  }

  // 대괄호 없애고 15글자로 자르기
  String _makeCleanTitle(String rawText) {
    if (rawText.isEmpty) return '통화 가이드';
    String cleanText = rawText.replaceAll(RegExp(r'\[.*?\]'), '').trim();

    if (cleanText.isEmpty) cleanText = rawText;

    if (cleanText.length > 18) {
      return '${cleanText.substring(0, 15)}...';
    }
    return cleanText;
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _guides.isEmpty
          ? const Center(
              child: Text(
                '저장된 대본이 없습니다.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 10.0,
              ),
              itemCount: _guides.length,
              itemBuilder: (context, index) {
                final item = _guides[index];
                final int guideId = item['guide_id'];

                String rawTitle = item['title'] ?? '통화 가이드';

                // 상대(target) 뽑아내기

                String target = item['target'] ?? '';
                if (target.trim().isEmpty) {
                  if (rawTitle.startsWith('[')) {
                    int firstClose = rawTitle.indexOf(']');
                    if (firstClose != -1) {
                      target = rawTitle.substring(1, firstClose);
                    }
                  }
                  if (target.trim().isEmpty) target = '기타';
                }

                // 제목 요액

                String displayTitle = _makeCleanTitle(rawTitle);

                /* // 대괄호 안전 파싱 로직
                if (rawTitle.startsWith('[')) {
                  int firstClose = rawTitle.indexOf(']');
                  if (firstClose != -1) {
                    int secondOpen = rawTitle.indexOf('[', firstClose);
                    if (secondOpen != -1 && secondOpen == firstClose + 1) {
                      int secondClose = rawTitle.indexOf(']', secondOpen);
                      if (secondClose != -1) {
                        target = rawTitle.substring(1, firstClose);
                        displayTitle = rawTitle
                            .substring(secondClose + 1)
                            .trim();
                      } else {
                        displayTitle = rawTitle
                            .substring(firstClose + 1)
                            .trim();
                      }
                    } else {
                      displayTitle = rawTitle.substring(firstClose + 1).trim();
                    }
                  }
                }

                if (displayTitle.isEmpty) displayTitle = '통화 가이드';
                */
                final String date = _formatDate(item['created_at']);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: ScriptExpansionTile(
                    guideId: guideId,
                    title: displayTitle,
                    target: target,
                    date: date,
                  ),
                );
              },
            ),
    );
  }
}

// -----------------------------------------------------
// 개별 대본 타일 위젯(키워드 태그)
// -----------------------------------------------------
class ScriptExpansionTile extends StatefulWidget {
  final int guideId;
  final String title;
  final String target;
  final String date;

  const ScriptExpansionTile({
    super.key,
    required this.guideId,
    required this.title,
    required this.target,
    required this.date,
  });

  @override
  State<ScriptExpansionTile> createState() => _ScriptExpansionTileState();
}

class _ScriptExpansionTileState extends State<ScriptExpansionTile> {
  bool _isExpanded = false;
  bool _isDetailLoading = false;

  String? _scriptContent;
  String? _helpContent;
  String? _tone;
  String? _detail;

  Future<void> _fetchDetailIfNeeded() async {
    if (_scriptContent != null) return;

    setState(() => _isDetailLoading = true);

    try {
      final response = await ApiService.getGuideMessages(widget.guideId);
      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        print("대본 상세 응답데이터 (ID: ${widget.guideId}): $responseData");
        final List<dynamic> messages = responseData['data'] ?? [];

        if (messages.isNotEmpty) {
          final lastMsg = messages.last;
          String rawQuestion = lastMsg['question'] ?? '';
          String parsedTone = '정중하게';
          String parsedDetail = rawQuestion;

          // 대괄호 안전 파싱 로직
          if (rawQuestion.startsWith('[')) {
            int firstClose = rawQuestion.indexOf(']');
            if (firstClose != -1) {
              int secondOpen = rawQuestion.indexOf('[', firstClose);
              if (secondOpen != -1 && secondOpen == firstClose + 1) {
                int secondClose = rawQuestion.indexOf(']', secondOpen);
                if (secondClose != -1) {
                  parsedTone = rawQuestion.substring(
                    secondOpen + 1,
                    secondClose,
                  );
                  parsedDetail = rawQuestion.substring(secondClose + 1).trim();
                } else {
                  parsedTone = rawQuestion.substring(1, firstClose);
                  parsedDetail = rawQuestion.substring(firstClose + 1).trim();
                }
              } else {
                parsedTone = rawQuestion.substring(1, firstClose);
                parsedDetail = rawQuestion.substring(firstClose + 1).trim();
              }
            }
          }

          if (mounted) {
            setState(() {
              _scriptContent = lastMsg['answer'] ?? '내용 없음';
              _helpContent = lastMsg['tips'] ?? '도움말이 없습니다.';
              _tone = parsedTone;
              _detail = parsedDetail;
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('대본 상세 내용을 불러올 수 없습니다.')),
            );
            setState(() {
              _scriptContent = '대본 내용이 없습니다.';
            });
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('서버 에러 발생: HTTP ${response.statusCode}')),
          );
          setState(() {
            _scriptContent = '서버 에러가 발생했습니다.';
          });
        }
      }
    } catch (e) {
      debugPrint("상세 내역 조회 실패: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('통신 중 오류가 발생했습니다.')));
        setState(() {
          _scriptContent = '통신 중 오류가 발생했습니다.';
          _helpContent = '';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isDetailLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isExpanded ? Colors.blue.shade200 : Colors.grey.shade300,
          width: _isExpanded ? 1.5 : 1.0,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (expanded) {
            setState(() => _isExpanded = expanded);
            if (expanded) {
              _fetchDetailIfNeeded();
            }
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.date,
                style: const TextStyle(
                  color: Color(0xFFA3A0A0),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: _isDetailLoading
                  ? const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue,
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_tone != null && _detail != null) ...[
                          Text(
                            '상대: ${widget.target}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '말투: $_tone',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '상황: $_detail',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3EBF8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _scriptContent ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_helpContent != null && _helpContent!.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD5D5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _helpContent!,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: Colors.black87,
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
