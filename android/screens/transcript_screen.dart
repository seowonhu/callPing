import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

// import 'feedback_result_screen.dart';

class TranscriptScreen extends StatefulWidget {
  final int recordId;
  final List<dynamic> transcripts;
  final String fileName;
  final bool isReadOnly;

  const TranscriptScreen({
    super.key,
    required this.recordId,
    required this.transcripts,
    this.fileName = '통화녹음',
    this.isReadOnly = false,
  });

  @override
  State<TranscriptScreen> createState() => _TranscriptScreenState();
}

class _TranscriptScreenState extends State<TranscriptScreen> {
  bool _isLoading = false;
  bool _isSavingEdit = false; // 중복 저장 방지

  late List<Map<String, dynamic>> _currentTranscripts;
  int? _editingIndex;
  final TextEditingController _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initData(widget.transcripts);
  }

  void _initData(List<dynamic> data) {
    // 순서(인덱스) 계산을 위해 asMap().entries 활용
    _currentTranscripts = data.asMap().entries.map((entry) {
      final index = entry.key;
      final map = Map<String, dynamic>.from(entry.value as Map);
      final rawId = map['transcriptId'] ?? map['transcript_id'];
      map['transcriptId'] = int.tryParse(rawId?.toString() ?? '0') ?? 0;
      map['speaker'] = map['speaker'] ?? '알 수 없음';
      map['orderIndex'] = map['orderIndex'] ?? map['order_index'] ?? '';
      return map;
    }).toList();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  // ========================================================
  // 원문 수정 (PATCH) - 화자 정보 포함
  // ========================================================
  Future<void> _saveCurrentEdit() async {
    // 이미 저장 중이면 return
    if (_isSavingEdit) return;

    if (_editingIndex == null || _editingIndex! >= _currentTranscripts.length)
      return;

    _isSavingEdit = true; // 저장 실행

    try {
      final index = _editingIndex!;

      final rawId =
          _currentTranscripts[index]['transcriptId'] ??
          _currentTranscripts[index]['transcript_id'];
      final int tId = _currentTranscripts[index]['transcriptId'];

      final String newText = _editController.text.trim();
      final String originalText =
          _currentTranscripts[index]['text']?.toString().trim() ?? '';
      final String currentSpeaker =
          _currentTranscripts[index]['speaker']?.toString() ?? '화자 1';
      final String currentTime =
          _currentTranscripts[index]['timestamp_offset'] ?? '00:00';

      // 바뀐 게 없으면 그냥 닫기
      if (newText == originalText) {
        setState(() => _editingIndex = null);
        return;
      }

      // 백엔드 연동
      final bool isNewBubble =
          _currentTranscripts[index]['isNew'] == true; // 임시 ID 기준으로 새 말풍선인지 판단
      var response; // http.Response

      debugPrint("[디버그] 확인된 말풍선 ID: $tId");

      if (isNewBubble) {
        debugPrint("[디버그] 가짜 ID 감지. 추가 POST API 쏨");
        // 새로 넣은 말풍선 -> 추가 API (PosT) 호출
        response = await ApiService.addTranscriptBubble(
          recordId: widget.recordId,
          speaker: currentSpeaker,
          text: newText,
          timestampOffset: currentTime,
          orderIndex: _currentTranscripts[index]['orderIndex'],
        );
      } else {
        debugPrint("[디버그] 기존 ID 감지. 수정 PATCH API 쏨");
        // 기존 말풍선 -> 수정 API (PATCH) 호출
        final rawId =
            _currentTranscripts[index]['transcriptId'] ??
            _currentTranscripts[index]['transcript_id'];
        final int tId = int.tryParse(rawId.toString()) ?? 0;
        response = await ApiService.updateTranscript(
          widget.recordId,
          tId,
          text: newText,
          speaker: currentSpeaker,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _currentTranscripts[index]['text'] = newText;

          if (isNewBubble) {
            final responseData = jsonDecode(utf8.decode(response.bodyBytes));
            final realId =
                responseData['data']?['id'] ??
                responseData['data']?['transcript_id'] ??
                responseData['data']?['transcriptId'] ??
                responseData['id'] ??
                responseData['transcript_id'];
            if (realId != null) {
              _currentTranscripts[index]['transcriptId'] = realId;
              _currentTranscripts[index]['isNew'] = false; // 새 말풍선 아님
              debugPrint("[디버그] 진짜 ID($realId)로 교체");
            }
          }
          _editingIndex = null;
        });
        debugPrint('자동 저장 성공');
      } else {
        throw Exception('서버 응답 오류: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('원문 수정 통신 실패: $e');
      setState(() => _editingIndex = null); // 실패해도 일단 수정창은 닫음
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('수정 내용 저장에 실패했습니다.')));
      }
    } finally {
      _isSavingEdit = false;
    }
  }

  // ========================================================
  // 원문 삭제 (DELETE)
  // ========================================================
  void _confirmDelete(int index) {
    // 서버에 없는 새 말풍선이면 지움
    if (_currentTranscripts[index]['isNew'] == true) {
      setState(() {
        _currentTranscripts.removeAt(index);
        if (_editingIndex == index)
          _editingIndex = null;
        else if (_editingIndex != null && _editingIndex! > index)
          _editingIndex = _editingIndex! - 1;
      });
      return;
    }

    final rawId =
        _currentTranscripts[index]['transcriptId'] ??
        _currentTranscripts[index]['transcript_id'];
    final int tId = int.tryParse(rawId.toString()) ?? 0;

    // 아직 서버에 저장 안 된(오류나서 가짜 ID로 남아있는) 말풍선이면?
    // 화면에서 바로 지움 (서버에 API 안 쏨)
    if (tId > 1000000000000) {
      setState(() {
        _currentTranscripts.removeAt(index);
        if (_editingIndex == index)
          _editingIndex = null;
        else if (_editingIndex != null && _editingIndex! > index)
          _editingIndex = _editingIndex! - 1;
      });
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '말풍선 삭제',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('이 대화 내용을 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // 팝업 먼저 닫기
              setState(() => _isLoading = true); // 삭제 중 로딩 띄우기

              if (widget.recordId == 999) {
                // 테스트 모드
                await Future.delayed(const Duration(milliseconds: 300));
                setState(() {
                  _currentTranscripts.removeAt(index);
                  if (_editingIndex == index)
                    _editingIndex = null;
                  else if (_editingIndex != null && _editingIndex! > index)
                    _editingIndex = _editingIndex! - 1;
                  _isLoading = false;
                });
                return;
              }

              // 백엔드 연동
              try {
                final response = await ApiService.deleteTranscript(
                  widget.recordId,
                  tId,
                );
                if (response.statusCode == 200) {
                  setState(() {
                    _currentTranscripts.removeAt(index);
                    if (_editingIndex == index)
                      _editingIndex = null;
                    else if (_editingIndex != null && _editingIndex! > index)
                      _editingIndex = _editingIndex! - 1;
                  });
                  if (mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));
                } else {
                  throw Exception('삭제 실패');
                }
              } catch (e) {
                debugPrint('원문 삭제 통신 실패: $e');
                if (mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('삭제에 실패했습니다.')));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 말풍선 추가
  // -------------------------------------------------------------

  void _insertBubbleAt(int index) async {
    if (_editingIndex != null) {
      await _saveCurrentEdit();
    }

    String newBubbleTime = '00:00';

    // 말풍선 추가 시 시간 계산

    if (_currentTranscripts.isEmpty) {
      // 대본 없을 때
      newBubbleTime = '00:00';
    } else if (index == 0) {
      // 첫 번째 말풍선 위에 추가할 때

      String currentTopTime =
          _currentTranscripts[0]['timestamp_offset'] ?? '00:00';
      int currentSec = 0;
      if (currentTopTime.contains(':')) {
        final parts = currentTopTime.split(':');
        currentSec = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }

      int targetSec = currentSec > 0 ? currentSec - 1 : 0; // 0초 밑으로 안 내려가게

      String mm = (targetSec ~/ 60).toString().padLeft(2, '0');
      String ss = (targetSec % 60).toString().padLeft(2, '0');

      newBubbleTime = '$mm:$ss';
    } else if (index >= _currentTranscripts.length) {
      // 마지막 말풍선 아래에 추가할 때
      newBubbleTime = _currentTranscripts.last['timestamp_offset'] ?? '00:00';
    } else {
      // 중간에 추가할 때
      String time1 =
          _currentTranscripts[index - 1]['timestamp_offset'] ?? '00:00';
      String time2 = _currentTranscripts[index]['timestamp_offset'] ?? '00:00';

      newBubbleTime = (time1 == time2)
          ? time1
          : _calculateMidTime(time1, time2);
    }

    // orderIndex 계산
    int prevOrder = 0;
    if (index > 0) {
      prevOrder = _currentTranscripts[index - 1]['orderIndex'] ?? 0;
    }

    int nextOrder = prevOrder + 2000;
    if (index < _currentTranscripts.length) {
      nextOrder =
          _currentTranscripts[index]['orderIndex'] ?? (prevOrder + 2000);
    }

    int newOrderIndex = (prevOrder + nextOrder) ~/ 2;

    setState(() {
      _currentTranscripts.insert(index, {
        'transcriptId': 0,
        'isNew': true,
        'speaker': '화자 1',
        'text': '',
        'timestamp_offset': newBubbleTime,
        'orderIndex': newOrderIndex, // 계산된 인덱스 저장
      });

      // 추가되자마자 해당 말풍선 수정 모드
      _editingIndex = index;
      _editController.text = '';
    });
  }

  // -------------------------------------------------------------
  // 분석 시작 POST & 화면 이동
  // -------------------------------------------------------------
  Future<void> _startAnalysis() async {
    // 글자 치던 중이었으면 서버에 저장
    setState(() => _isLoading = true);
    await _saveCurrentEdit();
    setState(() => _isLoading = false);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reviewed_${widget.recordId}', true);

    if (!mounted) return;

    // 서버에 분석 요청
    ApiService.startAiAnalysis(widget.recordId).then((_) {}).catchError((e) {
      debugPrint('AI 분석 통신 실패: $e');
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI 분석을 시작합니다. 분석이 완료되면 결과를 확인할 수 있습니다.')),
    );

    // 로딩창 없이 즉시 목록으로
    Navigator.pop(context, {
      'analyzeStarted': true,
      'transcripts': _currentTranscripts,
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        FocusScope.of(context).unfocus(); // 키보드 내리기
        Navigator.pop(context, _currentTranscripts);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        appBar: AppBar(
          title: const Text(
            '원문 검토',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.pop(context, _currentTranscripts);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.black54),
              tooltip: '이용 가이드',
              onPressed: () {
                _showHelpBottomSheet();
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            if (_currentTranscripts.isEmpty)
              const Center(
                child: Text(
                  '표시할 통화 원문이 없습니다.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              )
            else
              GestureDetector(
                onTap: () {
                  // 빈 공간 터치 시 키보드 내림
                  // Focus 위젯의 onFocusChange(false)가 트리거되면서 자동 저장
                  FocusScope.of(context).unfocus();
                  // 배경 터치하면 텍스트 저장 로직 실행
                  //_saveCurrentEdit();
                },
                // ListView.builder -> ReorderableListView.builder 로 바꾸면 말풍선 순서 변경 가능
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 120,
                  ),
                  itemCount: _currentTranscripts.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    if (oldIndex == newIndex) return;

                    setState(() {
                      final item = _currentTranscripts.removeAt(oldIndex);
                      _currentTranscripts.insert(newIndex, item);
                      _editingIndex = null; // 드래그하면 수정 모드 닫기
                    });

                    // 드래그해서 놓은 곳 위/아래 값을 기반으로 인덱스 계산
                    int prevOrder = 0;
                    if (newIndex > 0) {
                      prevOrder =
                          _currentTranscripts[newIndex - 1]['orderIndex'] ?? 0;
                    }
                    int nextOrder = prevOrder + 2000;
                    if (newIndex < _currentTranscripts.length - 1) {
                      nextOrder =
                          _currentTranscripts[newIndex + 1]['orderIndex'] ??
                          (prevOrder + 2000);
                    }

                    int targetOrderIndex = (prevOrder + nextOrder) ~/ 2;

                    setState(() {
                      _currentTranscripts[newIndex]['orderIndex'] =
                          targetOrderIndex;
                    });

                    // 새 위치를 서버에 저장(PATCH)
                    final rawId =
                        _currentTranscripts[newIndex]['transcriptId'] ??
                        _currentTranscripts[newIndex]['transcript_id'];
                    final int tId = int.tryParse(rawId.toString()) ?? 0;
                    final bool isNewBubble =
                        _currentTranscripts[newIndex]['isNew'] == true;

                    if (!isNewBubble && tId > 0) {
                      try {
                        await ApiService.updateTranscript(
                          widget.recordId,
                          tId,
                          orderIndex: targetOrderIndex,
                        );
                        debugPrint(
                          "드래그 순서 변경 서버 저장 완료 (index: $targetOrderIndex)",
                        );
                      } catch (e) {
                        debugPrint('순서 변경 통신 실패: $e');
                      }
                    }
                  },
                  itemBuilder: (context, index) {
                    final item = _currentTranscripts[index];
                    final String speaker =
                        item['speaker']?.toString().trim() ?? '';
                    final bool isMe = (speaker == '화자 1');
                    final bool isEditing = _editingIndex == index;

                    // ReorderableListView 고유 key
                    final uniqueKey =
                        item['transcriptId']?.toString() ?? 'item_$index';

                    return Padding(
                      key: ValueKey(uniqueKey),
                      padding: const EdgeInsets.only(
                        bottom: 16,
                      ), // 기존 bottom: 12
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          // 단순 글자(Text)를 누를 수 있는 버튼(GestureDetector)으로 교체!
                          GestureDetector(
                            onTap: widget.isReadOnly
                                ? null
                                : () async {
                                    // 키보드 내리고 쓰던 글자 저장
                                    FocusScope.of(context).unfocus();
                                    if (_editingIndex != null) {
                                      await _saveCurrentEdit();
                                    }

                                    // 화자 이름 스위칭 (화자 1 <-> 화자 2)
                                    final currentSpeaker =
                                        item['speaker']?.toString().trim() ??
                                        '';
                                    final newSpeaker =
                                        (currentSpeaker == '화자 1')
                                        ? '화자 2'
                                        : '화자 1';

                                    // 화면 즉시 변경
                                    setState(() {
                                      _currentTranscripts[index]['speaker'] =
                                          newSpeaker;
                                    });

                                    try {
                                      final rawId =
                                          item['transcriptId'] ??
                                          item['transcript_id'] ??
                                          item['id'] ??
                                          0;
                                      final int tId =
                                          int.tryParse(rawId.toString()) ?? 0;
                                      final bool isNewBubble =
                                          item['isNew'] == true;

                                      // 바뀐 화자 서버에 저장
                                      if (isNewBubble) {
                                        debugPrint('새 말풍선은 화자 변경 API 생략');
                                      } else {
                                        await ApiService.updateTranscript(
                                          widget.recordId,
                                          tId,
                                          speaker: newSpeaker,
                                        );
                                      }
                                    } catch (e) {
                                      debugPrint('화자 업데이트 에러: $e');
                                    }
                                  },

                            child: Padding(
                              padding: const EdgeInsets.only(
                                bottom: 4,
                                left: 4,
                                right: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 화면에 보여질 때만 '나' / '상대'로 표기
                                  Text(
                                    isMe ? '나' : '상대',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  // 수정 모드일 때만 이름 옆에 '변경' 아이콘 띄워주기
                                  if (!widget.isReadOnly) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.sync_alt,
                                      size: 14,
                                      color: Colors.blueAccent,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          Row(
                            mainAxisAlignment: isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            children: [
                              Flexible(
                                child: GestureDetector(
                                  onTap: widget.isReadOnly
                                      ? null
                                      : () async {
                                          //수정 중인 말풍선의 테두리를 눌렀을 때는 무시
                                          if (_editingIndex == index) return;

                                          // 다른 곳 수정 중이었으면 서버에 저장 완료될 때까지 기다림
                                          if (_editingIndex != null &&
                                              _editingIndex != index) {
                                            await _saveCurrentEdit();
                                          }
                                          setState(() {
                                            _editingIndex = index;
                                            _editController.text =
                                                item['text']?.toString() ?? '';
                                          });
                                        },
                                  // 길게 누르기(드래그)와 안 겹치게 삭제는 더블탭
                                  onDoubleTap: widget.isReadOnly
                                      ? null
                                      : () {
                                          FocusScope.of(context).unfocus();
                                          //_saveCurrentEdit(); // 딴 거 지우기 전에 쓰던 건 저장
                                          _confirmDelete(index);
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? const Color.fromARGB(
                                              255,
                                              185,
                                              172,
                                              246,
                                            )
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(15),
                                      border: isEditing
                                          ? Border.all(
                                              color: Colors.blueAccent,
                                              width: 2,
                                            )
                                          : (isMe
                                                ? null
                                                : Border.all(
                                                    color: Colors.grey.shade300,
                                                  )),
                                    ),
                                    child: isEditing
                                        ? IntrinsicWidth(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Focus(
                                                  onFocusChange: (hasFocus) {
                                                    // 바깥 클릭 시 자동 저장
                                                    if (!hasFocus &&
                                                        _editingIndex ==
                                                            index) {
                                                      _saveCurrentEdit();
                                                    }
                                                  },
                                                  child: TextField(
                                                    controller: _editController,
                                                    maxLines: null,
                                                    // 줄바꿈 대신 완료 버튼
                                                    textInputAction:
                                                        TextInputAction.done,
                                                    autofocus: true,
                                                    decoration:
                                                        const InputDecoration(
                                                          isDense: true,
                                                          border:
                                                              InputBorder.none,
                                                          contentPadding:
                                                              EdgeInsets.zero,
                                                        ),
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                    ),

                                                    onEditingComplete: () {
                                                      FocusScope.of(
                                                        context,
                                                      ).unfocus();
                                                    },
                                                  ),
                                                ),

                                                // 수정 모드일 때 '위에 추가' / '아래에 추가' 버튼
                                                const SizedBox(height: 12),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    InkWell(
                                                      onTap: () =>
                                                          _insertBubbleAt(
                                                            index,
                                                          ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white
                                                              .withOpacity(0.6),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: const Text(
                                                          '위에 추가',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors
                                                                .blueAccent,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    InkWell(
                                                      onTap: () =>
                                                          _insertBubbleAt(
                                                            index + 1,
                                                          ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white
                                                              .withOpacity(0.6),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: const Text(
                                                          '아래에 추가',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors
                                                                .blueAccent,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          )
                                        : Text(
                                            item['text']?.toString() ?? '',
                                            style: const TextStyle(
                                              fontSize: 15,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // 삭제 중이거나 분석 넘어갈 때 로딩
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),

        bottomNavigationBar: widget.isReadOnly
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _startAnalysis,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '분석 시작',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ========================================================
  // 이용 가이드 (바텀시트)
  // ========================================================
  void _showHelpBottomSheet() {
    // 혹시 키보드가 올라와 있다면 닫기
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // 모서리 둥글게
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min, // 내용물 크기만큼만 높이 차지
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '원문 검토 이용 가이드',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context), // 닫기 버튼
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 가이드 목록들
                _buildHelpItem(
                  icon: Icons.edit_outlined,
                  title: '말풍선 수정',
                  description:
                      '말풍선을 터치하면 글자를 수정할 수 있어요. 다 쓰고 배경을 터치하면 자동 저장됩니다.',
                ),
                _buildHelpItem(
                  icon: Icons.person_outline,
                  title: '화자 변경',
                  description:
                      '수정 모드일 때 말풍선 위의 [나/상대] 버튼을 터치하면 발화자를 변경할 수 있어요.',
                ),
                _buildHelpItem(
                  icon: Icons.add_circle_outline,
                  title: '말풍선 추가',
                  description:
                      '수정 모드 아래에 뜨는 [위에 추가] / [아래에 추가] 버튼을 눌러 대화를 추가해 보세요.',
                ),
                _buildHelpItem(
                  icon: Icons.delete_outline,
                  title: '말풍선 삭제',
                  description: '지우고 싶은 말풍선을 빠르게 두 번 터치(더블탭)하면 삭제할 수 있어요.',
                ),
                _buildHelpItem(
                  icon: Icons.drag_handle,
                  title: '말풍선 위치 변경',
                  description: '말풍선을 꾹 누른 상태로 위아래로 끌어다 놓으면(드래그) 순서가 바뀝니다.',
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // 가이드 항목을 예쁘게 그려주는 미니 위젯

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------
  // 시간 계산용
  // ---------------------------------------------

  String _calculateMidTime(String time1, String time2) {
    int toSeconds(String t) {
      if (!t.contains(':')) return 0;
      final parts = t.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }

    int sec1 = toSeconds(time1);
    int sec2 = toSeconds(time2);

    int midSec = (sec1 + sec2) ~/ 2;

    String mm = (midSec ~/ 60).toString().padLeft(2, '0');
    String ss = (midSec % 60).toString().padLeft(2, '0');

    return '$mm:$ss';
  }
}
