import 'dart:developer';
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'feedback_result_screen.dart';
import 'transcript_screen.dart';
import 'home_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const AnalyticsScreen({
    super.key,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _uploadedFiles = [];
  final Map<int, dynamic> _globalAnalysisCache = {};
  final Set<int> _processingRecords = {}; // 강제로 AI 분석중 띄울 파일 ID 목록
  Timer? _pollingTimer; // 새로고침 타이머

  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  int _totalPages = 1;
  bool _isLoadingMore = false;
  bool _hasMorePages = true;

  @override
  void initState() {
    super.initState();
    _fetchCallList();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      if (_hasMorePages && !_isLoadingMore) {
        _fetchCallList(loadMore: true);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pollingTimer?.cancel(); // 화면 닫힐 때 타이머 끄기
    super.dispose();
  }

  // 완료나 실패 뜰 때까지 3초마다 새로고침
  void _startPolling() {
    _pollingTimer?.cancel(); // 타이머 초기화
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_processingRecords.isEmpty) {
        timer.cancel();
      } else {
        // 분석 중이면 목록 새로고침
        if (mounted) _fetchCallList();
      }
    });
  }

  Future<void> _fetchCallList({bool loadMore = false}) async {
    if (_isLoadingMore) return;
    if (loadMore && !_hasMorePages) return;

    final int page = loadMore ? _currentPage + 1 : 0;

    if (mounted) {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final response = await ApiService.getCallList(page: page, size: 10);

      final decodedResponse = utf8.decode(response.bodyBytes);
      debugPrint('\n=== [디버그] 전체 통화 목록(GET /calls) 서버 응답 ===');
      debugPrint(decodedResponse);
      debugPrint('=======================================================\n');

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(utf8.decode(response.bodyBytes));
        final Map<String, dynamic> data = decodedData.containsKey('data')
            ? decodedData['data']
            : decodedData;

        final List<dynamic> calls = data['content'] ?? data['calls'] ?? [];

        final int currentPage =
            int.tryParse(
              data['currentPage']?.toString() ??
                  data['current_page']?.toString() ??
                  data['current_Page']?.toString() ??
                  data['number']?.toString() ??
                  '',
            ) ??
            page;
        final int totalPages =
            int.tryParse(
              data['totalPages']?.toString() ??
                  data['total_pages']?.toString() ??
                  data['total_Pages']?.toString() ??
                  '',
            ) ??
            1;

        if (mounted) {
          setState(() {
            _currentPage = currentPage;
            _totalPages = totalPages;
            _hasMorePages = _currentPage + 1 < _totalPages;

            final List<Map<String, dynamic>>
            newFiles = calls.map<Map<String, dynamic>>((call) {
              final rawRecordId = call['record_id'] ?? call['recordId'];
              final rawCallerName = call['caller_name'] ?? call['callerName'];
              final rawUploadTime = call['upload_time'] ?? call['uploadTime'];
              final rawAnalysisStatus =
                  call['analysis_status'] ?? call['analysisStatus'] ?? '';
              final rawFileName =
                  call['file_name'] ??
                  call['fileName'] ??
                  call['record_title'] ??
                  call['recordTitle'];
              final rawFileSize = call['file_size'] ?? call['fileSize'];

              String apiStatus = rawAnalysisStatus.toString();
              String appStatus = 'error';
              double? progress;

              // 서버 상태 덮어씌움
              final id = rawRecordId as int?;

              // 서버가 '완료', '실패'라고 답을 준 파일이면 명단에서 삭제
              if (id != null &&
                  (apiStatus == '완료' ||
                      apiStatus == 'COMPLETED' ||
                      apiStatus == 'AI 분석 실패')) {
                _processingRecords.remove(id);
              }
              // [분석 시작] 눌러서 명단에 있는 파일이면
              else if (id != null && _processingRecords.contains(id)) {
                // AI 분석중으로 덮어씌움
                apiStatus = 'AI 분석중';
              }

              if (apiStatus == 'STT 분석중') {
                appStatus = 'stt_analyzing';
                progress = 0.25;
              } else if (apiStatus == '대본 수정 대기') {
                appStatus = 'waiting_edit';
                progress = 0.5;
              } else if (apiStatus == 'AI 분석중') {
                appStatus = 'ai_analyzing';
                progress = 0.75;
              } else if (apiStatus == '완료' || apiStatus == 'COMPLETED') {
                appStatus = 'completed';
                progress = 1.0;
              }

              String rawRelation = (rawCallerName ?? '').toString().trim();

              return {
                'record_id': rawRecordId,
                'fileName': rawFileName ?? '통화녹음_$rawRecordId',
                'relation': rawRelation.isEmpty ? '알 수 없음' : rawRelation,
                'summary': '',
                'uploadDate': rawUploadTime,
                'fileSize': rawFileSize?.toString() ?? '',
                'status': appStatus,
                'progress': progress,
                'cached_analysis': null,
              };
            }).toList();

            if (loadMore) {
              _uploadedFiles.addAll(newFiles);
            } else {
              _uploadedFiles = newFiles;
            }
          });
        }
      } else {
        debugPrint('통화 목록 조회 실패: HTTP ${response.statusCode}');

        // 서버 500 에러 처리
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('서버 오류로 통화 목록을 갱신하지 못했습니다. 잠시 후 다시 시도해주세요.'),
            ),
          );
          setState(() {
            for (var file in _uploadedFiles) {
              if (file['status'] == 'ai_analyzing') {
                file['status'] = 'error';
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('목록 불러오기 실패: $e');
      // 서버 에러
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('네트워크 문제로 갱신에 실패했습니다.')));
        setState(() {
          for (var file in _uploadedFiles) {
            if (file['status'] == 'ai_analyzing') {
              file['status'] = 'error';
            }
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _pickAudioFile() async {
    bool hasUploadPermission = false;

    try {
      final response = await ApiService.getPermissions();
      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final data = responseData['data'] ?? responseData;
        hasUploadPermission = data['file_upload_permission'] ?? false;
      }
    } catch (e) {
      debugPrint('권한 설정 조회 실패: $e');
    }

    if (!hasUploadPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('설정에서 파일 업로드 권한을 허용해주세요.')),
        );
      }
      return;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav'],
    );

    if (result == null || result.files.first.path == null) {
      return;
    }

    final String filePath = result.files.first.path!;
    final String fileName = result.files.first.name;

    final Map<String, dynamic> newFile = {
      'record_id': null,
      'fileName': fileName,
      'relation': '알 수 없음',
      'summary': '',
      'uploadDate': DateTime.now().toIso8601String(),
      'fileSize': result.files.first.size.toString(),
      'status': 'uploading',
      'progress': null,
      'cached_analysis': null,
    };

    if (mounted) {
      setState(() {
        _uploadedFiles.insert(0, newFile);
      });
    }

    try {
      final response = await ApiService.uploadAudio(filePath);
      final responseString = await response.stream.bytesToString();

      debugPrint('파일 업로드(POST /calls) 서버 응답 코드: ${response.statusCode}');
      debugPrint('파일 업로드(POST /calls) 서버 응답 데이터: $responseString');

      if (response.statusCode == 201) {
        final responseData = jsonDecode(responseString);
        final data = responseData['data'] ?? responseData;
        final dynamic recordIdValue = data['recordId'] ?? data['record_id'];

        if (recordIdValue == null)
          throw Exception('업로드 성공 응답에 recordId가 없습니다.');

        final int realRecordId = int.parse(recordIdValue.toString());

        if (mounted) {
          setState(() {
            newFile['record_id'] = realRecordId;
            String receivedRelation =
                (responseData['caller_Name'] ?? responseData['callerName'])
                    ?.toString() ??
                '';
            newFile['relation'] = receivedRelation.trim().isEmpty
                ? '알 수 없음'
                : receivedRelation;
            newFile['status'] = 'stt_analyzing';
            newFile['progress'] = null;
            newFile['fileName'] =
                responseData['file_Name'] ??
                responseData['fileName'] ??
                fileName;
            newFile['uploadDate'] =
                responseData['upload_Time'] ??
                responseData['uploadTime'] ??
                DateTime.now().toIso8601String();
          });
        }

        debugPrint('파일 업로드 성공 - recordId: $realRecordId');
        _checkAnalysisStatus(realRecordId);
      } else {
        if (mounted) {
          setState(() {
            newFile['status'] = 'error';
          });
        }
      }
    } catch (e) {
      debugPrint("파일 업로드 실패: $e");
      if (mounted) {
        setState(() {
          newFile['status'] = 'error';
        });
      }
    }
  }

  Future<void> _checkAnalysisStatus(int recordId) async {
    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;

      try {
        final response = await ApiService.getCallStatus(recordId);
        if (response.statusCode == 200) {
          final responseData = jsonDecode(utf8.decode(response.bodyBytes));
          final data = responseData['data'] ?? responseData;

          final String status = data['status']?.toString() ?? '';
          final double progressPercentage = (data['progress_percentage'] ?? 0)
              .toDouble();
          final int index = _uploadedFiles.indexWhere(
            (file) => file['record_id']?.toString() == recordId.toString(),
          );

          if (index != -1 && mounted) {
            setState(() {
              _uploadedFiles[index]['progress'] = progressPercentage / 100;
              if (status == '완료' ||
                  status == 'COMPLETED' ||
                  progressPercentage >= 100) {
                _uploadedFiles[index]['status'] = 'completed';
                _uploadedFiles[index]['progress'] = 100.0;
              } else if (status == '대본 수정 대기') {
                _uploadedFiles[index]['status'] = 'waiting_edit';
              } else if (status == 'AI 분석중') {
                _uploadedFiles[index]['status'] = 'ai_analyzing';
              }
            });

            if (_uploadedFiles[index]['status'] == 'completed' ||
                _uploadedFiles[index]['status'] == 'waiting_edit')
              return;
          }
        }
      } catch (e) {
        debugPrint('분석 상태 확인 중 오류: $e');
      }
    }
  }

  String _formatFileSize(String? sizeString) {
    if (sizeString == null || sizeString.isEmpty) return '';
    int bytes = int.tryParse(sizeString) ?? 0;

    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _handleActionTap(
    int index,
    String status,
    int recordId,
    String displayFileName,
  ) async {
    // 상태는 '완료'인데 캐시 안의 요약이 비어있다면?
    if (_globalAnalysisCache.containsKey(recordId)) {
      final cachedData = _globalAnalysisCache[recordId];

      if (status == 'completed' && cachedData['isAnalysisFetched'] != true) {
        _globalAnalysisCache.remove(recordId);
      } else {
        _navigateToResultScreen(recordId, displayFileName, status);
        return;
      }
    }

    bool loadingDialogShown = false;
    if (mounted) {
      loadingDialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) =>
            const Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    try {
      final detailsResponse = await ApiService.getCallDetails(
        recordId,
      ).timeout(const Duration(seconds: 15));
      List<dynamic> transcripts = [];
      if (detailsResponse.statusCode == 200) {
        final detailsResponseData = jsonDecode(
          utf8.decode(detailsResponse.bodyBytes),
        );
        final Map<String, dynamic> detailsData =
            detailsResponseData['data'] is Map
            ? Map<String, dynamic>.from(detailsResponseData['data'])
            : Map<String, dynamic>.from(detailsResponseData);
        if (detailsData['transcripts'] is List) {
          transcripts = List<dynamic>.from(detailsData['transcripts']);
        } else if (detailsData['transcript'] is List) {
          transcripts = List<dynamic>.from(detailsData['transcript']);
        }
      }

      Map<String, dynamic> analysisData = {
        'summary': '',
        'expressionFeedback': '',
        'improvementFeedback': '',
      };

      List<dynamic> todos = [];
      String todoSummaryText = '';

      // 완료 상태일 때만 분석 결과, TODO 가져오기
      if (status == 'completed') {
        final analysisResponse = await ApiService.getCallAnalysis(
          recordId,
        ).timeout(const Duration(seconds: 15));

        if (analysisResponse.statusCode == 200) {
          final analysisStr = utf8.decode(analysisResponse.bodyBytes);

          // 요약, 표현, 피드백 데이터 출력
          // ==============================================================
          // [공식 로그 함수]
          // ==============================================================
          log(analysisStr, name: 'FULL_JSON_DATA');
          // ==============================================================

          final analysisResponseData = jsonDecode(analysisStr);
          analysisData = analysisResponseData['data'] is Map
              ? Map<String, dynamic>.from(analysisResponseData['data'])
              : Map<String, dynamic>.from(analysisResponseData);
        }

        // TODO 리스트 가져오기
        final todoResponse = await ApiService.getCallTodos(
          recordId,
        ).timeout(const Duration(seconds: 15));

        if (todoResponse.statusCode == 200) {
          final todoStr = utf8.decode(todoResponse.bodyBytes);

          // TODO 리스트 데이터 출력
          debugPrint('\n=== [응답] TODO 리스트 결과 ===');
          debugPrint(todoStr);
          debugPrint('==============================\n');

          final todoData = jsonDecode(todoStr);
          if (todoData['data'] != null) {
            todos = todoData['data']['todos'] ?? [];
            todoSummaryText = todoData['data']['todo_summary'] ?? '';
          }
        }
      }

      if (loadingDialogShown && mounted) {
        Navigator.pop(context);
        loadingDialogShown = false;
      }

      final Map<String, dynamic> cacheData = {
        'summary': analysisData['summary']?.toString() ?? '',
        'expression': analysisData['expression']?.toString() ?? '',
        'feedback': analysisData['feedback']?.toString() ?? '',
        'transcript': transcripts,
        'todos': todos,
        'todoSummary': todoSummaryText,
        'isAnalysisFetched': status == 'completed',
      };
      _globalAnalysisCache[recordId] = cacheData;

      if (mounted) {
        _navigateToResultScreen(recordId, displayFileName, status);
      }
    } catch (e) {
      if (loadingDialogShown && mounted) {
        Navigator.pop(context);
      }
      debugPrint('조회 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('데이터를 불러오지 못했습니다. 다시 시도해주세요.')),
        );
      }
    }
  }

  Future<void> _navigateToResultScreen(
    int recordId,
    String displayFileName,
    String status,
  ) async {
    final cachedData = _globalAnalysisCache[recordId];
    if (cachedData == null) return;

    // final prefs = await SharedPreferences.getInstance();
    // final bool isReviewed = prefs.getBool('reviewed_$recordId') ?? false;

    if (status == 'completed') {
      // 검토 완료된 통화는 피드백 결과 화면으로
      // 화면 넘어가기 직전 (Navigator.push 바로 위)에 이 3줄만 복붙하세요!
      debugPrint("==================================================");
      debugPrint("서버가 준 요약(summary): ${cachedData['summary']}");
      debugPrint(
        "서버가 준 투두(todoSummary): ${cachedData['todo_summary'] ?? cachedData['todoSummary']}",
      );
      debugPrint("==================================================");
      final updatedData = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FeedbackResultScreen(
            recordId: recordId,
            fileName: displayFileName,
            summary: cachedData['summary'] ?? '',
            expression: cachedData['expression'] ?? '',
            feedback: cachedData['feedback'] ?? '',
            transcript: cachedData['transcript'] ?? [],
            todos: cachedData['todos'] ?? [],
            todoSummary:
                cachedData['todoSummary'] ?? cachedData['todo_summary'] ?? '',
          ),
        ),
      );

      if (updatedData != null && mounted) {
        if (updatedData is bool && updatedData == true) {
          _fetchCallList(); // 분석 시작 후 돌아온 경우 목록 새로고침
        } else if (updatedData is List) {
          _globalAnalysisCache[recordId]['transcript'] =
              updatedData; // 수정된 원문 캐시 반영
        }
      }
    } else {
      // 대본 수정 대기 또는 단순 원문 확인 상태 -> 원문 화면으로
      final updatedData = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TranscriptScreen(
            recordId: recordId,
            fileName: displayFileName,
            transcripts: cachedData['transcript'] ?? [],
            isReadOnly: false,
          ),
        ),
      );

      if (updatedData != null && mounted) {
        if (updatedData is Map) {
          // 수정된 대본 띄움
          if (updatedData['transcripts'] != null) {
            _globalAnalysisCache[recordId]['transcript'] =
                updatedData['transcripts'];
          }
          if (updatedData['analyzeStarted'] == true) {
            setState(() {
              // 강제 로딩 명단
              _processingRecords.add(recordId);

              final index = _uploadedFiles.indexWhere(
                (file) => file['record_id'] == recordId,
              );
              if (index != -1) {
                _uploadedFiles[index]['analysis_status'] = 'AI 분석중';
                _uploadedFiles[index]['status'] = 'ai_analyzing';
                _uploadedFiles[index]['progress'] = 0.75;
              }
            });
            // 끝날 때까지 3초마다 계속 확인
            _startPolling();
          } // 분석 시작 버튼 눌러서 돌아왔을 때 api 재호출해서 AI 분석중 상태로 갱신
        } else if (updatedData is List) {
          _globalAnalysisCache[recordId]['transcript'] =
              updatedData; // 원문 수정 후 되돌아왔을 때만 캐시 갱신
        }
      }
    }
  }

  void _showEditDialog(int index) {
    String fullFileName = _uploadedFiles[index]['fileName']?.toString() ?? '';

    String baseName = fullFileName.replaceAll(
      RegExp(r'(\.[a-zA-Z0-9]+)+$'),
      '',
    );

    String extension = '';

    int lastdotIndex = fullFileName.lastIndexOf('.');
    if (lastdotIndex > 0) {
      // baseName = fullFileName.substring(0, dotIndex);
      extension = fullFileName.substring(lastdotIndex);
    }

    TextEditingController nameController = TextEditingController(
      text: baseName,
    );
    TextEditingController relationController = TextEditingController(
      text: _uploadedFiles[index]['relation']?.toString() ?? '',
    );
    TextEditingController summaryController = TextEditingController(
      text: _uploadedFiles[index]['summary']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: SingleChildScrollView(
            child: Container(
              width: 300,
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 30.0,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBE6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '1. 파일명',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.black38),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IntrinsicWidth(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 80,
                                  maxWidth: 180,
                                ),
                                child: TextField(
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    hintText: '파일 이름을 입력하세요',
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                            Text(
                              extension,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        '2. 관계',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: relationController,
                        decoration: const InputDecoration(
                          hintText: '예: 병원',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const Divider(color: Colors.black38),
                      const SizedBox(height: 30),
                      const Text(
                        '3. 내용 요약',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: summaryController,
                        maxLines: 4,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          hintText: '통화 내용을 간단히 적어주세요',
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final recordId = _uploadedFiles[index]['record_id'];

                          // 파일 iD 아직 없을 때
                          if (recordId == null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('파일이 아직 업로드 중이거나 오류가 있습니다.'),
                              ),
                            );
                            return;
                          }

                          final newName = nameController.text + extension;
                          final newRelation = relationController.text;
                          final newSummary = summaryController.text;

                          try {
                            final res = await ApiService.updateCallRecord(
                              recordId,
                              newName,
                              newRelation,
                              newSummary,
                            );

                            if (res.statusCode == 200 ||
                                res.statusCode == 204) {
                              if (mounted) {
                                setState(() {
                                  _uploadedFiles[index]['fileName'] = newName;
                                  _uploadedFiles[index]['relation'] =
                                      newRelation;
                                  _uploadedFiles[index]['summary'] = newSummary;

                                  globalChecklistKey.currentState?.fetchTodos();
                                });
                              }
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            } else {
                              // 백엔드에서 200이 아닌 에러를 뱉었을 때 화면에 띄움
                              debugPrint(
                                '저장 실패 서버 응답: ${res.statusCode} / ${res.body}',
                              );
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '서버 에러가 발생했습니다. (코드: ${res.statusCode})',
                                    ),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            // 통신 터졌을 때 (네트워크 문제 등)
                            debugPrint('수정 통신 실패: $e');
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('통신에 실패했습니다. 다시 시도해주세요.'),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '저장하기',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.black,
                  size: 28,
                ),
                onPressed:
                    widget.onBackPressed ?? () => Navigator.maybePop(context),
              )
            : null,
        title: const Text(
          '파일 업로드',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _uploadedFiles.isEmpty ? _buildEmptyDesign() : _buildListState(),
      ),
    );
  }

  Widget _buildEmptyDesign() {
    return Column(
      children: [
        const SizedBox(height: 30),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: CustomPaint(
              painter: DashedRectPainter(
                color: Colors.grey.shade400,
                strokeWidth: 1.5,
                gap: 6.0,
              ),
              child: const Center(
                child: Text(
                  '통화 녹음 파일을 업로드하고\n\n피드백을 받아보세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF979696),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: _pickAudioFile,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2),
              color: Colors.white,
            ),
            child: const Icon(Icons.add, color: Colors.black, size: 36),
          ),
        ),
        const SizedBox(height: 80), // 하단 여백 확보, 조절 가능
      ],
    );
  }

  Widget _buildListState() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 20.0,
            ),
            itemCount: _uploadedFiles.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _uploadedFiles.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              String originalFileName =
                  _uploadedFiles[index]['fileName']?.toString() ?? '';
              String relation =
                  _uploadedFiles[index]['relation']?.toString() ?? '';
              String dateString =
                  _uploadedFiles[index]['uploadDate']?.toString() ?? '';
              String sizeString =
                  _uploadedFiles[index]['fileSize']?.toString() ?? '';
              String status =
                  _uploadedFiles[index]['status']?.toString() ?? 'completed';

              String displayFileName = originalFileName.replaceAll(
                RegExp(r'(\.[a-zA-Z0-9]+)+$'),
                '',
              );

              String formattedDate = '';
              if (dateString.isNotEmpty) {
                DateTime uploadDate = DateTime.parse(dateString);
                DateTime now = DateTime.now();
                if (uploadDate.year == now.year) {
                  formattedDate = '${uploadDate.month}월 ${uploadDate.day}일';
                } else {
                  formattedDate =
                      '${uploadDate.year}년 ${uploadDate.month}월 ${uploadDate.day}일';
                }
              }

              String formattedSize = _formatFileSize(sizeString);
              String subtitleText = formattedDate;
              if (formattedSize.isNotEmpty) {
                subtitleText = '$formattedDate\n$formattedSize';
              }

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: index == 0
                        ? const BorderSide(color: Colors.black, width: 1.0)
                        : BorderSide.none,
                    bottom: const BorderSide(color: Colors.black, width: 1.0),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showEditDialog(index),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 18,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 70),
                            child: Text(
                              relation.trim().isEmpty ? '알 수 없음' : relation,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayFileName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: status == 'error'
                                  ? Colors.red
                                  : Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitleText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitleText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    if (status == 'uploading' ||
                        status == 'stt_analyzing' ||
                        status == 'ai_analyzing') ...[
                      Text(
                        status == 'ai_analyzing'
                            ? 'AI 분석 중...'
                            : (status == 'stt_analyzing'
                                  ? 'STT 추출 중...'
                                  : '업로드 중...'),
                        style: TextStyle(
                          color: status == 'ai_analyzing'
                              ? Colors.purple
                              : (status == 'stt_analyzing'
                                    ? Colors.orange
                                    : const Color(0xFF1A9000)),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: status == 'ai_analyzing'
                              ? Colors.purple
                              : (status == 'stt_analyzing'
                                    ? Colors.orange
                                    : const Color(0xFF1A9000)),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else if (status == 'waiting_edit' ||
                        status == 'completed') ...[
                      InkWell(
                        onTap: () async {
                          final int? recordId =
                              _uploadedFiles[index]['record_id'];
                          if (recordId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('서버 업로드에 실패한 파일입니다.'),
                              ),
                            );
                            return;
                          }
                          await _handleActionTap(
                            index,
                            status,
                            recordId,
                            displayFileName,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 6.0,
                          ),
                          decoration: BoxDecoration(
                            color: status == 'completed'
                                ? Colors.green.shade100
                                : const Color(0xFFD2E2FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status == 'completed' ? '피드백 보기' : '원문 검토',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    SizedBox(
                      width: 32,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.black,
                          size: 22,
                        ),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Colors.black, width: 1),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditDialog(index);
                          } else if (value == 'delete') {
                            final recordId = _uploadedFiles[index]['record_id'];
                            if (recordId != null) {
                              // 삭제 요청 보내고 결과 기다림
                              ApiService.deleteCallRecord(recordId)
                                  .then((res) {
                                    if (res.statusCode == 200 ||
                                        res.statusCode == 204) {
                                      if (mounted) {
                                        setState(
                                          () => _uploadedFiles.removeAt(index),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('삭제되었습니다.'),
                                          ),
                                        );
                                      }
                                    } else {
                                      // 에러 났을 때 화면에 띄워주기
                                      debugPrint('삭제 실패: ${res.statusCode}');
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '삭제 서버 에러 (코드: ${res.statusCode})',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  })
                                  .catchError((e) {
                                    // 통신 터졌을 때
                                    debugPrint('삭제 통신 에러: $e');
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('삭제 통신에 실패했습니다.'),
                                        ),
                                      );
                                    }
                                  });
                            }
                          }
                        },

                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20, color: Colors.black),
                                SizedBox(width: 8),
                                Text(
                                  '수정',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '삭제',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 40.0),
          child: GestureDetector(
            onTap: _pickAudioFile,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
                color: Colors.white,
              ),
              child: const Icon(Icons.add, color: Colors.black, size: 30),
            ),
          ),
        ),
      ],
    );
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedRectPainter({
    this.color = Colors.grey,
    this.strokeWidth = 1.0,
    this.gap = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    var path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    Path dashPath = Path();
    double distance = 0.0;

    for (PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + gap),
          Offset.zero,
        );
        distance += gap * 2;
      }
      distance = 0.0;
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
