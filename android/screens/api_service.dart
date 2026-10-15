import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'login_screen.dart';

class ApiService {
  static bool _isSessionExpired = false;

  // 백엔드 요청에 따라 /api/v1 제거된 최종 주소
  static const String baseUrl = 'http://54.116.93.220:8080';

  // 공통 헤더 (토큰 자동 주입)
  static Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ----------------------------------------------------
  // 회원가입 / 로그인 / 로그아웃
  // ----------------------------------------------------
  static Future<void> handleUnauthorized() async {
    // 만료된 토큰 비움
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final context = navigatorKey.currentContext;

    if (context != null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('로그인이 만료되었습니다. 다시 로그인 해주세요.'),
          backgroundColor: Colors.red,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  static Future<http.Response> checkId(String loginId) async {
    return _check401(
      await http.post(
        Uri.parse('$baseUrl/users/check-id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'login_id': loginId}),
      ),
    );
  }

  static Future<http.Response> sendSignupEmailCode(String email) async {
    return _check401(
      await http.post(
        Uri.parse('$baseUrl/users/email-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ),
    );
  }

  static Future<http.Response> verifySignupEmailCode(
    String email,
    String code,
  ) async {
    return _check401(
      await http.post(
        Uri.parse('$baseUrl/users/email-verification/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'verification_code': code}),
      ),
    );
  }

  static Future<http.Response> signup(
    String loginId,
    String password,
    String email,
  ) async {
    return _check401(
      await http.post(
        Uri.parse('$baseUrl/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'login_id': loginId,
          'password': password,
          'email': email,
          'terms_agreed': true,
        }),
      ),
    );
  }

  static Future<http.Response> login(String loginId, String password) async {
    _isSessionExpired = false;

    return await http.post(
      Uri.parse('$baseUrl/sessions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'login_id': loginId, 'password': password}),
    );
  }

  static Future<http.Response> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token') ?? '';

    return _check401(
      await http.delete(
        Uri.parse('$baseUrl/sessions'),
        headers: await getHeaders(),
        body: jsonEncode({'refresh_token': refreshToken}),
      ),
    );
  }

  static Future<http.Response> withdraw() async {
    return _check401(
      await http.delete(
        Uri.parse('$baseUrl/users/me/account'),
        headers: await getHeaders(),
      ),
    );
  }

  // ----------------------------------------------------
  // 아이디 / 비밀번호 찾기
  // ----------------------------------------------------
  // 이메일 코드 전송
  static Future<http.Response> sendFindIdEmailCode(String email) async {
    return _check401(
      await http.post(
        Uri.parse('$baseUrl/users/find-id/email-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ),
    );
  }

  // 이메일 코드 인증
  static Future<http.Response> verifyFindIdEmailCode(
    String email,
    String code,
  ) async {
    return _check401(
      await http.post(
        Uri.parse('$baseUrl/users/find-id/email-verification/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'verification_code': code}),
      ),
    );
  }

  // 아이디 찾기
  static Future<http.Response> findId(String email) async {
    return _check401(
      await http.post(
        Uri.parse('$baseUrl/users/find-id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ),
    );
  }

  // 비밀번호 재설정 시 이메일 코드 전송
  static Future<http.Response> sendPwResetEmailCode(String email) async {
    return _check401(
      await http.post(
        Uri.parse('$baseUrl/users/password-reset/email-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ),
    );
  }

  // 비밀번호 재설정 시 이메일 코드 인증
  static Future<http.Response> verifyPwResetEmailCode(
    String email,
    String code,
  ) async {
    return _check401(
      await http.post(
        Uri.parse('$baseUrl/users/password-reset/email-verification/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'verification_code': code}),
      ),
    );
  }

  // 비밀번호 재설정
  static Future<http.Response> resetPassword(
    String loginId,
    String email,
    String newPassword,
  ) async {
    return _check401(
      await http.patch(
        Uri.parse('$baseUrl/users/password-reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'login_id': loginId,
          'email': email,
          'password': newPassword,
        }),
      ),
    );
  }

  // 내 계정 정보 조회
  static Future<http.Response> getMe() async {
    return _check401(
      await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: await getHeaders(),
      ),
    );
  }

  // ----------------------------------------------------
  // 계정 정보 변경 (로그인 상태)
  // ----------------------------------------------------
  static Future<http.Response> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    return _check401(
      await http.patch(
        Uri.parse('$baseUrl/users/me/account/password'),
        headers: await getHeaders(),
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      ),
    );
  }

  static Future<http.Response> sendEmailChangeCode(
    String currentEmail,
    String newEmail,
  ) async {
    return _check401(
      await http.post(
        Uri.parse('$baseUrl/users/me/account/email/verification'),
        headers: await getHeaders(),
        body: jsonEncode({
          'current_email': currentEmail,
          'new_email': newEmail,
        }),
      ),
    );
  }

  static Future<http.Response> verifyEmailChangeCode(String code) async {
    return _check401(
      await http.patch(
        Uri.parse('$baseUrl/users/me/account/email/verification/check'),
        headers: await getHeaders(),
        body: jsonEncode({'verification_code': code}),
      ),
    );
  }

  //  권한 설정 조회
  static Future<http.Response> getPermissions() async {
    return _check401(
      await http.get(
        Uri.parse('$baseUrl/users/me/permissions'),
        headers: await getHeaders(),
      ),
    );
  }

  //  권한 설정 변경
  static Future<http.Response> updatePermissions({
    required bool fileUploadPermission,
    required bool pushNotificationPermission,
  }) async {
    return _check401(
      await http.patch(
        Uri.parse('$baseUrl/users/me/permissions'),
        headers: await getHeaders(),
        body: jsonEncode({
          'file_upload_permission': fileUploadPermission,
          'push_notification_permission': pushNotificationPermission,
        }),
      ),
    );
  }

  // ----------------------------------------------------
  // 챗봇
  // ----------------------------------------------------
  static Future<http.Response> createChatRoom() async {
    return _check401(
      await http.post(
        Uri.parse('$baseUrl/chats/rooms'),
        headers: await getHeaders(),
      ),
    );
  }

  static Future<http.Response> sendChat(int roomId, String question) async {
    return _check401(
      await http.post(
        Uri.parse('$baseUrl/chats'),
        headers: await getHeaders(),
        body: jsonEncode({'room_id': roomId, 'question': question}),
      ),
    );
  }

  static Future<http.Response> getChatRooms() async {
    return _check401(
      await http.get(
        Uri.parse('$baseUrl/chats/rooms'),
        headers: await getHeaders(),
      ),
    );
  }

  static Future<http.Response> getChatRoomDetail(int roomId) async {
    return _check401(
      await http.get(
        Uri.parse('$baseUrl/chats/rooms/$roomId'),
        headers: await getHeaders(),
      ),
    );
  }

  static Future<http.Response> deleteChatRoom(int roomId) async {
    return _check401(
      await http.delete(
        Uri.parse('$baseUrl/chats/rooms/$roomId'),
        headers: await getHeaders(),
      ),
    );
  }

  static Future<http.Response> deleteChatMessage(int chatId) async {
    return _check401(
      await http.delete(
        Uri.parse('$baseUrl/chats/$chatId'),
        headers: await getHeaders(),
      ),
    );
  }

  static Future<http.Response> stopChatGeneration(
    int roomId, {
    int? chatId,
    String? answer,
  }) async {
    return _check401(
      await http.post(
        Uri.parse('$baseUrl/chats/rooms/$roomId/stop'),
        headers: await getHeaders(),
        body: jsonEncode({
          if (chatId != null) 'chat_id': chatId,
          if (answer != null) 'answer': answer,
        }),
      ),
    );
  }

  // ----------------------------------------------------
  // 통화 가이드 / 보관함
  // ----------------------------------------------------
  static Future<http.Response> createGuide(
    String category,
    String description,
  ) async {
    final url = Uri.parse('$baseUrl/guides');
    final requestBody = jsonEncode({
      'category': category,
      'description': description,
    });

    // 생성 시 보내는 데이터 확인
    debugPrint('=========================================');
    debugPrint('[가이드 생성 POST 요청] $url');
    debugPrint(' [보내는 데이터] $requestBody');
    debugPrint('=========================================');

    final response = await http.post(
      url,
      headers: await getHeaders(),
      body: requestBody,
    );

    // 서버 응답 확인
    debugPrint('=========================================');
    debugPrint('[가이드 생성 POST 응답] 상태 코드: ${response.statusCode}');
    try {
      debugPrint('[응답 내용] ${utf8.decode(response.bodyBytes)}');
    } catch (e) {
      debugPrint('[응답 내용] ${response.body}');
    }
    debugPrint('=========================================');

    return _check401(response);
  }

  static Future<http.Response> getGuides() async {
    final url = Uri.parse('$baseUrl/guides');

    // 보관함 리스트 요청
    debugPrint('=========================================');
    debugPrint('[보관함 리스트 GET 요청] $url');
    debugPrint('=========================================');

    final response = await http.get(url, headers: await getHeaders());

    // 보관함 리스트 응답 확인 ('상대' 키워드가 어떻게 오는지 여기서 확인!!)
    debugPrint('=========================================');
    debugPrint('[보관함 리스트 GET 응답] 상태 코드: ${response.statusCode}');
    try {
      debugPrint('[응답 내용] ${utf8.decode(response.bodyBytes)}');
    } catch (e) {
      debugPrint('[응답 내용] ${response.body}');
    }
    debugPrint('=========================================');

    return _check401(response);
  }

  static Future<http.Response> getGuideMessages(int guideId) async {
    final url = Uri.parse('$baseUrl/guides/$guideId/messages');

    // 특정 대본 상세 요청
    debugPrint('=========================================');
    debugPrint('[대본 상세 GET 요청] $url');
    debugPrint('=========================================');

    final response = await http.get(url, headers: await getHeaders());

    // 대본 상세 응답 확인
    debugPrint('=========================================');
    debugPrint('[대본 상세 GET 응답] 상태 코드: ${response.statusCode}');
    try {
      debugPrint('[응답 내용] ${utf8.decode(response.bodyBytes)}');
    } catch (e) {
      debugPrint('[응답 내용] ${response.body}');
    }
    debugPrint('=========================================');

    return _check401(response);
  }

  // ----------------------------------------------------
  // 통화 목록 조회(GET /calls)
  // ----------------------------------------------------
  static Future<http.Response> getCallList({
    int page = 0,
    int size = 10,
  }) async {
    return _check401(
      await http.get(
        Uri.parse('$baseUrl/calls?page=$page&size=$size'),
        headers: await getHeaders(),
      ),
    );
  }

  // ----------------------------------------------------
  // 파일 업로드
  // ----------------------------------------------------
  static Future<http.StreamedResponse> uploadAudio(
    String filePath, {
    String? callerName,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/calls'));

    // content-type이 application/json으로 덮어씌워지는 것을 방지하고 토큰만 주입
    // JWT 인증
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    if (token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    // 백엔드 명세서대로 -> 발신자 이름(caller name) 같이 전송
    if (callerName != null && callerName.isNotEmpty) {
      request.fields['caller_name'] = callerName;
    }

    // 녹음 파일 추가
    final fileExtension = filePath.split('.').last.toLowerCase();
    final String mimeSubtype = (fileExtension == 'mp3')
        ? 'mpeg'
        : fileExtension;
    request.files.add(
      await http.MultipartFile.fromPath(
        'file', // 백엔드 명세서에 명시된 파라미터 이름(file, audio 등)과 정확히 일치해야 함
        filePath,
        contentType: MediaType('audio', mimeSubtype),
      ),
    );

    return await request.send();
  }

  // -----------------------------------------------------
  // 통화 파일 정보 수정
  // -----------------------------------------------------

  // 통화 정보 수정 (PATCH)
  static Future<http.Response> updateCallRecord(
    int recordId,
    String fileName,
    String callerName,
    String summary,
  ) async {
    final url = Uri.parse('$baseUrl/calls/$recordId');

    // 백엔드로 보낼 데이터 세팅
    final requestBody = jsonEncode({
      "recordTitle": fileName,
      "callerName": callerName,
      "summary": summary,
    });

    // 내가 백엔드로 뭘 쏘는지 터미널에 출력
    debugPrint('=========================================');
    debugPrint('[PATCH 요청] $url');
    debugPrint('[보내는 데이터] $requestBody');
    debugPrint('=========================================');

    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    // 백엔드가 뭐라고 대답했는지 터미널에 출력
    debugPrint('=========================================');
    debugPrint('[PATCH 응답] 상태 코드: ${response.statusCode}');
    try {
      debugPrint('[응답 내용] ${utf8.decode(response.bodyBytes)}');
    } catch (e) {
      debugPrint('[응답 내용] ${response.body}');
    }
    debugPrint('=========================================');

    return response;
  }

  // -----------------------------------------------------
  // 통화 파일 삭제
  // -----------------------------------------------------
  static Future<http.Response> deleteCallRecord(int recordId) async {
    final url = Uri.parse('$baseUrl/calls/$recordId');

    debugPrint('=========================================');
    debugPrint('[DELETE 요청] $url');
    debugPrint('=========================================');

    final response = await http.delete(url);

    debugPrint('=========================================');
    debugPrint('[DELETE 응답] 상태 코드: ${response.statusCode}');
    try {
      debugPrint('[응답 내용] ${utf8.decode(response.bodyBytes)}');
    } catch (e) {
      debugPrint('[응답 내용] ${response.body}');
    }
    debugPrint('=========================================');

    return response;
  }

  // -----------------------------------------------------
  // AI 분석 시작 트리거
  // -----------------------------------------------------
  static Future<http.Response> startAiAnalysis(int recordId) async {
    return _check401(
      await http.post(
        Uri.parse('$baseUrl/calls/$recordId/analyze'),
        headers: await getHeaders(),
      ),
    );
  }

  // -----------------------------------------------------
  // 통화 분석 진행률 조회
  // -----------------------------------------------------
  static Future<http.Response> getCallStatus(int recordId) async {
    return _check401(
      await http.get(
        Uri.parse('$baseUrl/calls/$recordId/status'),
        headers: await getHeaders(),
      ),
    );
  }

  // -----------------------------------------------------
  // 통화 녹음 분석 결과 조회 (GET /calls/{id}/analysis)
  // -----------------------------------------------------
  static Future<http.Response> getCallAnalysis(int recordId) async {
    return _check401(
      await http.get(
        Uri.parse('$baseUrl/calls/$recordId/analysis'),
        headers: await getHeaders(),
      ),
    );
  }

  // FCM 토큰 등록 (백엔드 API 명세서 나오면 사용할 임시 코드)
  static Future<http.Response> updateFcmToken(String token) async {
    return _check401(
      await http.patch(
        Uri.parse('$baseUrl/users/me/fcm-token'),
        headers: await getHeaders(),
        body: jsonEncode({'fcm_token': token}),
      ),
    );
  }

  // --------------------------------------
  // TODO 관리(체크리스트)
  // --------------------------------------

  // 0) 통화별 TODO 리스트 조회 (GET /calls/{recordId}/todos)
  static Future<http.Response> getCallTodos(int recordId) async {
    return _check401(
      await http.get(
        Uri.parse('$baseUrl/calls/$recordId/todos'),
        headers: await getHeaders(),
      ),
    );
  }

  // 1) 전체 TODO 목록 불러오기
  static Future<http.Response> getTodos({String? status}) async {
    String url = '$baseUrl/todos';
    if (status != null) url += '?status=$status';
    return _check401(
      await http.get(Uri.parse(url), headers: await getHeaders()),
    );
  }

  // 2) 수동 TODO 추가
  static Future<http.Response> addTodo({
    int? recordId,
    required String taskType,
    required String description,
    String priority = 'MEDIUM',
  }) async {
    final body = <String, dynamic>{
      'taskType': taskType,
      'description': description,
      'priority': priority,
    };
    if (recordId != null) body['recordId'] = recordId;

    return _check401(
      await http.post(
        Uri.parse('$baseUrl/todos'),
        headers: await getHeaders(),
        body: jsonEncode(body),
      ),
    );
  }

  // 3) TODO 상태/내용 수정 (체크박스 클릭 시)
  static Future<http.Response> updateTodo(
    int todoId, {
    String? status,
    String? description,
  }) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status;
    if (description != null) body['description'] = description;

    return _check401(
      await http.patch(
        Uri.parse('$baseUrl/todos/$todoId'),
        headers: await getHeaders(),
        body: jsonEncode(body),
      ),
    );
  }

  // 4) TODO 삭제하기
  static Future<http.Response> deleteTodo(int todoId) async {
    return _check401(
      await http.delete(
        Uri.parse('$baseUrl/todos/$todoId'),
        headers: await getHeaders(),
      ),
    );
  }

  // ------------------------------------------------
  // 통화 원문(STT) 수정 / 추가 / 삭제
  // ------------------------------------------------

  // 원문 텍스트 수정 (PATCH /calls/{recordId}/transcripts/{transcriptId})
  static Future<http.Response> updateTranscript(
    int recordId,
    int transcriptId, {
    String? text,
    String? speaker,
    int? orderIndex,
  }) async {
    final url = Uri.parse('$baseUrl/calls/$recordId/transcripts/$transcriptId');

    final Map<String, dynamic> bodyData = {};
    if (text != null) bodyData['text'] = text;
    if (speaker != null) bodyData['speaker'] = speaker;
    if (orderIndex != null) bodyData['order_index'] = orderIndex;

    final requestBody = jsonEncode(bodyData);

    // 서버로 보내는 데이터 (Request)
    debugPrint('\n=== [요청] 화자/텍스트 수정 (PATCH) ===');
    debugPrint('URL: $url');
    debugPrint('보내는 데이터: $requestBody');
    debugPrint('======================================\n');

    // 서버에 요청을 보냄
    final response = await http.patch(
      url,
      headers: await getHeaders(),
      body: requestBody,
    );

    // 서버가 돌려준 결과 (Response)
    debugPrint('\n=== [응답] 화자/텍스트 수정 결과 ===');
    debugPrint('상태 코드: ${response.statusCode}');
    // 한글이 깨지지 않게 utf8.decode 처리해서 출력
    try {
      debugPrint('서버 응답 데이터: ${utf8.decode(response.bodyBytes)}');
    } catch (e) {
      debugPrint('서버 응답 데이터: ${response.body}');
    }
    debugPrint('======================================\n');

    return _check401(response);
  }

  // 말풍선 추가
  static Future<http.Response> addTranscriptBubble({
    required int recordId,
    required String speaker,
    required String text,
    required String timestampOffset,
    int? orderIndex,
  }) async {
    final url = Uri.parse('$baseUrl/calls/$recordId/transcripts');
    final headers = await getHeaders();

    final Map<String, dynamic> bodyData = {
      "speaker": speaker,
      "text": text,
      "timestamp_offset": timestampOffset,
    };

    // orderIndex 전달됐을 때
    if (orderIndex != null) {
      bodyData["order_index"] = orderIndex;
    }
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(bodyData),
    );

    debugPrint("=== [디버그] 말풍선 추가(POST) 결과 ===");
    debugPrint("보낸 데이터: ${jsonEncode(bodyData)}");
    debugPrint("상태 코드: ${response.statusCode}");
    try {
      debugPrint("서버 응답 내용: ${utf8.decode(response.bodyBytes)}");
    } catch (e) {
      debugPrint("서버 응답 읽기 실패: $e");
    }

    return response;
  }

  // 원문 텍스트 삭제 (DELETE /calls/{recordId}/transcripts/{transcriptId})
  static Future<http.Response> deleteTranscript(
    int recordId,
    int transcriptId,
  ) async {
    return _check401(
      await http.delete(
        Uri.parse('$baseUrl/calls/$recordId/transcripts/$transcriptId'),
        headers: await getHeaders(),
      ),
    );
  }

  // --------------------------------------------
  // 통화 원문 상세 조회
  // GET /calls/{recordId}/details
  // --------------------------------------------

  static Future<http.Response> getCallDetails(int recordId) async {
    final response = await _check401(
      await http.get(
        Uri.parse('$baseUrl/calls/$recordId/details'),
        headers: await getHeaders(),
      ),
    );

    try {
      // 한글 안 깨지게 utf8로 변환해서 출력
      final decodedBody = utf8.decode(response.bodyBytes);
      print('==================================================');
      print('=== [디버그] getCallDetails (원문 검토) API 응답 ===');
      print('=== 요청 recordId: $recordId');
      print('=== 응답 상태코드: ${response.statusCode}');
      print('=== 응답 데이터: $decodedBody');
      print('==================================================');
    } catch (e) {
      print('=== [디버그] 로그 출력 중 에러 발생: $e');
    }
    // ====================================================

    return response;
  }

  // check401
  static Future<http.Response> _check401(http.Response response) async {
    if (response.statusCode == 401) {
      if (!_isSessionExpired) {
        _isSessionExpired = true;
        await handleUnauthorized();
      }
    }
    return response;
  }
}
