import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // 백엔드 요청에 따라 /api/v1 제거된 최종 주소
  static const String baseUrl = 'http://54.116.93.220:8080';

  // 공통 헤더 (토큰 자동 주입)
  static Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    print("현재 저장된 토큰 값 : $token"); // 토큰 값 확인용 로그

    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ----------------------------------------------------
  // 1. 회원가입 / 로그인 / 로그아웃
  // ----------------------------------------------------
  static Future<http.Response> checkId(String loginId) async {
    return await http.post(
      Uri.parse('$baseUrl/users/check-id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'login_id': loginId}),
    );
  }

  static Future<http.Response> sendSignupEmailCode(String email) async {
    return await http.post(
      Uri.parse('$baseUrl/users/email-verification'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
  }

  static Future<http.Response> verifySignupEmailCode(
    String email,
    String code,
  ) async {
    return await http.post(
      Uri.parse('$baseUrl/users/email-verification/check'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'verification_code': code}),
    );
  }

  static Future<http.Response> signup(
    String loginId,
    String password,
    String email,
  ) async {
    return await http.post(
      Uri.parse('$baseUrl/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'login_id': loginId,
        'password': password,
        'email': email,
        'terms_agreed': true,
      }),
    );
  }

  static Future<http.Response> login(String loginId, String password) async {
    return await http.post(
      Uri.parse('$baseUrl/sessions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'login_id': loginId, 'password': password}),
    );
  }

  static Future<http.Response> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token') ?? '';

    return await http.delete(
      Uri.parse('$baseUrl/sessions'),
      headers: await getHeaders(),
      body: jsonEncode({'refresh_token': refreshToken}),
    );
  }

  static Future<http.Response> withdraw() async {
    return await http.delete(
      Uri.parse('$baseUrl/users/me/account'),
      headers: await getHeaders(),
    );
  }

  // ----------------------------------------------------
  // 2. 아이디 / 비밀번호 찾기
  // ----------------------------------------------------
  static Future<http.Response> sendFindIdEmailCode(String email) async {
    return await http.post(
      Uri.parse('$baseUrl/users/find-id/email-verification'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
  }

  static Future<http.Response> verifyFindIdEmailCode(
    String email,
    String code,
  ) async {
    return await http.post(
      Uri.parse('$baseUrl/users/find-id/email-verification/check'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'verification_code': code}),
    );
  }

  static Future<http.Response> findId(String email) async {
    return await http.post(
      Uri.parse('$baseUrl/users/find-id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
  }

  static Future<http.Response> sendPwResetEmailCode(String email) async {
    return await http.post(
      Uri.parse('$baseUrl/users/password-reset/email-verification'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
  }

  static Future<http.Response> verifyPwResetEmailCode(
    String email,
    String code,
  ) async {
    return await http.post(
      Uri.parse('$baseUrl/users/password-reset/email-verification/check'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'verification_code': code}),
    );
  }

  static Future<http.Response> resetPassword(
    String loginId,
    String email,
    String newPassword,
  ) async {
    return await http.patch(
      Uri.parse('$baseUrl/users/password-reset'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'login_id': loginId,
        'email': email,
        'password': newPassword,
      }),
    );
  }

  // ----------------------------------------------------
  // 3. 계정 정보 변경 (로그인 상태)
  // ----------------------------------------------------
  static Future<http.Response> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    return await http.patch(
      Uri.parse('$baseUrl/users/me/account/password'),
      headers: await getHeaders(),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
  }

  static Future<http.Response> sendEmailChangeCode(
    String currentEmail,
    String newEmail,
  ) async {
    return await http.post(
      Uri.parse('$baseUrl/users/me/account/email/verification'),
      headers: await getHeaders(),
      body: jsonEncode({'current_email': currentEmail, 'new_email': newEmail}),
    );
  }

  static Future<http.Response> verifyEmailChangeCode(String code) async {
    return await http.patch(
      Uri.parse('$baseUrl/users/me/account/email/verification/check'),
      headers: await getHeaders(),
      body: jsonEncode({'verification_code': code}),
    );
  }

  // ----------------------------------------------------
  // 4. 챗봇
  // ----------------------------------------------------
  static Future<http.Response> createChatRoom() async {
    return await http.post(
      Uri.parse('$baseUrl/chats/rooms'),
      headers: await getHeaders(),
    );
  }

  static Future<http.Response> sendChat(int roomId, String question) async {
    return await http.post(
      Uri.parse('$baseUrl/chats'),
      headers: await getHeaders(),
      body: jsonEncode({'room_id': roomId, 'question': question}),
    );
  }

  static Future<http.Response> getChatRooms() async {
    return await http.get(
      Uri.parse('$baseUrl/chats/rooms'),
      headers: await getHeaders(),
    );
  }

  static Future<http.Response> getChatRoomDetail(int roomId) async {
    return await http.get(
      Uri.parse('$baseUrl/chats/rooms/$roomId'),
      headers: await getHeaders(),
    );
  }

  static Future<http.Response> deleteChatRoom(int roomId) async {
    return await http.delete(
      Uri.parse('$baseUrl/chats/rooms/$roomId'),
      headers: await getHeaders(),
    );
  }

  // ----------------------------------------------------
  // 5. 통화 가이드
  // ----------------------------------------------------
  static Future<http.Response> createGuide(
    String category,
    String description,
  ) async {
    return await http.post(
      Uri.parse('$baseUrl/guides'),
      headers: await getHeaders(),
      body: jsonEncode({'category': category, 'description': description}),
    );
  }

  // ----------------------------------------------------
  // 6. 파일 업로드
  // ----------------------------------------------------
  static Future<http.StreamedResponse> uploadAudio(String filePath) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/calls'));

    // content-type이 application/json으로 덮어씌워지는 것을 방지하고 토큰만 주입
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    if (token.isNotEmpty) {
      request.headers['Authorizaiton'] = 'Bearer $token';
    }

    final fileExtension = filePath.split('.').last;
    request.files.add(
      await http.MultipartFile.fromPath(
        'file', // 백엔드 명세서에 명시된 파라미터 이름(file, audio 등)과 정확히 일치해야 함
        filePath,
        contentType: MediaType('audio', fileExtension),
      ),
    );
    return await request.send();
  }

  // ----------------------------------------------------
  // 7. 통화 녹음 분석 결과 조회
  // ----------------------------------------------------
  static Future<http.Response> getCallAnalysis(int recordId) async {
    return await http.get(
      Uri.parse('$baseUrl/call-records/$recordId/analysis'),
      headers: await getHeaders(),
    );
  }

  // 권한 조회
  static Future<http.Response> getPermissions() async {
    return await http.get(
      Uri.parse('$baseUrl/users/me/permissions'),
      headers: await getHeaders(),
    );
  }

  // 권한 수정
  static Future<http.Response> updatePermissions(
    bool fileUpload,
    bool pushNoti,
  ) async {
    return await http.patch(
      Uri.parse('$baseUrl/users/me/permissions'),
      headers: await getHeaders(),
      body: jsonEncode({
        'file_upload_permission': fileUpload,
        'push_notification_permission': pushNoti,
      }),
    );
  }

  // FCM 토큰 등록
  static Future<http.Response> updateFcmToken(String token) async {
    return await http.patch(
      Uri.parse('$baseUrl/users/me/fcm-token'),
      headers: await getHeaders(),
      body: jsonEncode({'fcm_token': token}),
    );
  }
}
