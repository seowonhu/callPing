import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'api_service.dart';
import 'feedback_result_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with AutomaticKeepAliveClientMixin {
  // 탭 이동해도 캐시 유지되도록
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _uploadedFiles = [];

  // 화면이 리빌드되어도 캐시 지워지지 않도록
  final Map<int, dynamic> _globalAnalysisCache = {};

  Future<void> _pickAudioFile() async {
    // 서버나 로컬에 저장된 권한 상태 확인
    // 실제로는 GET/users/me/permissions의 file_upload_permission 응답값을 사용하거나 전역 변수 참조
    bool hasUploadPermission = true;

    if (!hasUploadPermission) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('설정에서 파일 업로드 권한을 허용해주세요.')));
      return; // 권한 꺼져있으면 함수 강제 종료 (파일 탐색기 차단)
    }

    // 권한 켜져 있을 때만 코드 실행
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['m4a', 'mp3', 'wav', 'aac', 'flac'],
    );

    if (result != null && result.files.first.path != null) {
      String filePath = result.files.first.path!;
      String fileName = result.files.first.name;

      // 화면에 '업로드 중' 상태로 파일 항목 먼저 추가
      Map<String, dynamic> newFile = {
        'record_id': null, // 실제 서버 연동 시 백엔드에서 받아온 ID 사용
        'fileName': fileName,
        'relation': '',
        'summary': '',
        'uploadDate': DateTime.now().toIso8601String(),
        'fileSize': result.files.first.size.toString(),
        'status': 'uploading',
        'progress': null, // 업로드 진행률 표시용
        'cached_analysis': null, // 캐시 저장소 명시적 초기화
      };

      setState(() {
        _uploadedFiles.add(newFile);
      });

      try {
        // 실제 백엔드 API 연동(파일 전송)
        final response = await ApiService.uploadAudio(filePath);

        // 서버 응답 확인을 위한 디버그 로그
        final responseString = await response.stream.bytesToString();
        print("파일 업로드 서버 응답 코드: ${response.statusCode}");
        print("파일 업로드 서버 응답 데이터: $responseString");

        if (response.statusCode == 201) {
          // 전송 성공 시 서버 응답 해독
          final responseString = await response.stream.bytesToString();
          final responseData = jsonDecode(responseString);

          // 서버가 파일 받고 발급해 준 record_id
          int realRecordId = responseData['data']['record_id'];

          if (mounted) {
            setState(() {
              newFile['record_id'] = realRecordId;
              newFile['status'] = 'completed'; // 분석 완료 상태로 즉시 갱신 (추후 폴링 필요)
              newFile['progress'] = 1.0;
            });
          }
        } else {
          // 400, 500 등 에러 발생
          if (mounted) {
            setState(() {
              newFile['status'] = 'error';
            });
          }
        }
      } catch (e) {
        // 네트워크 통신 실패
        if (mounted) {
          setState(() {
            newFile['status'] = 'error';
          });
        }
      }
    }
  }

  String _formatFileSize(String? sizeString) {
    if (sizeString == null || sizeString.isEmpty) return '';
    int bytes = int.tryParse(sizeString) ?? 0;

    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _showEditDialog(int index) {
    String fullFileName = _uploadedFiles[index]['fileName']?.toString() ?? '';
    String baseName = fullFileName;
    String extension = '';

    int dotIndex = fullFileName.lastIndexOf('.');
    if (dotIndex > 0) {
      baseName = fullFileName.substring(0, dotIndex);
      extension = fullFileName.substring(dotIndex);
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
              height: 460,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        decoration: const InputDecoration(
                          hintText: '통화 내용을 간단히 적어주세요',
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
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
                        onPressed: () {
                          setState(() {
                            _uploadedFiles[index]['fileName'] =
                                nameController.text + extension;
                            _uploadedFiles[index]['relation'] =
                                relationController.text;
                            _uploadedFiles[index]['summary'] =
                                summaryController.text;
                          });
                          Navigator.of(ctx).pop();
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
          onPressed: () => Navigator.maybePop(context),
        ),
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
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildListState() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 20.0,
            ),
            itemCount: _uploadedFiles.length,
            itemBuilder: (context, index) {
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
              double progress =
                  (_uploadedFiles[index]['progress'] ?? 0.0) as double;

              String displayFileName = originalFileName;
              int dotIndex = originalFileName.lastIndexOf('.');
              if (dotIndex > 0) {
                displayFileName = originalFileName.substring(0, dotIndex);
              }

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
                subtitleText = '$formattedDate • $formattedSize';
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
                    if (relation.isNotEmpty) ...[
                      const Icon(
                        Icons.person_outline,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 70),
                        child: Text(
                          relation,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else ...[
                      const SizedBox(width: 12),
                    ],
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
                    if (status == 'uploading') ...[
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Color(0xFF1A9000),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 2.5,
                          color: const Color(0xFF1A9000),
                          backgroundColor: Colors.grey.shade300,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else if (status == 'analyzing') ...[
                      const Text(
                        '분석 중...',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else ...[
                      InkWell(
                        onTap: () async {
                          // null 값 허용하는 int? 타입으로 수정
                          int? recordId = _uploadedFiles[index]['record_id'];

                          // ID 발급되지 않았다면(업로드 실패) 작동 중지 및 안내 띄우기
                          if (recordId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('서버 업로드에 실패한 파일입니다. 다시 업로드해주세요.'),
                              ),
                            );
                            return;
                          }

                          // 캐시 저장소에 데이터 있는지 확인
                          if (_globalAnalysisCache.containsKey(recordId)) {
                            print("캐시된 분석 데이터가 존재합니다. (recordId: $recordId)");
                            final data = _globalAnalysisCache[recordId]!;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FeedbackResultScreen(
                                  fileName: displayFileName,
                                  summary: data['summary'] ?? '요약 내용 없음',
                                  expression:
                                      data['expression'] ?? '표현 분석 내용 없음',
                                  feedback: data['feedback'] ?? '개선 피드백 없음',
                                  transcript: data['transcript'] ?? [],
                                ),
                              ),
                            );
                            return; // 캐시가 있으면 API 호출 없이 바로 화면 이동
                          }

                          // 저장된 데이터 없을 때(최초 1회) 분석 데이터 불러오는 동안 화면에 로딩 다이얼로그 띄우기
                          showDialog(
                            context: context,
                            barrierDismissible: false, // 로딩 중 다른 곳 터치 방지
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(
                                color: Colors.black,
                              ),
                            ),
                          );

                          try {
                            final response =
                                await ApiService.getCallAnalysis(
                                  recordId,
                                ).timeout(
                                  const Duration(seconds: 15),
                                ); // 15초 무응답 시 강제 종료

                            if (context.mounted)
                              Navigator.pop(context); // 로딩창 닫기

                            if (response.statusCode == 200) {
                              final responseData = jsonDecode(
                                utf8.decode(response.bodyBytes),
                              );
                              final data = responseData['data'];

                              // 2. 분석 데이터가 존재하면 캐시에 저장 후 결과 화면으로 이동
                              _globalAnalysisCache[recordId] = data; // 캐시에 저장

                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FeedbackResultScreen(
                                      fileName: displayFileName,
                                      summary: data['summary'] ?? '요약 내용 없음',
                                      expression:
                                          data['expression'] ?? '표현 분석 내용 없음',
                                      feedback: data['feedback'] ?? '개선 피드백 없음',
                                      transcript: data['transcript'] ?? [],
                                    ),
                                  ),
                                );
                              }
                            } else {
                              // 통신 실패(404) 시에도 빈 데이터를 캐시에 남김
                              _globalAnalysisCache[recordId] = {};

                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FeedbackResultScreen(
                                      fileName: displayFileName,
                                    ),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            // 3. 에러 나더라도 로딩창이 닫히지 않고 남아있는 현상 방지
                            if (context.mounted) Navigator.pop(context);

                            // 서버 꺼져서 에러 났을 때도 빈 데이터를 캐시에 남김
                            _globalAnalysisCache[recordId] = {};

                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FeedbackResultScreen(
                                    fileName: displayFileName,
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 6.0,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD2E2FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '피드백 보기',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
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
                            setState(() => _uploadedFiles.removeAt(index));
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
