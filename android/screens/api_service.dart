import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // 백엔드 명세서 기준 공통 주소
  static const String baseUrl = 'http://54.116.93.220:8080/api/v1';

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
    return await http.delete(
      Uri.parse('$baseUrl/sessions'),
      headers: await getHeaders(),
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
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/call-records'),
    );
    request.headers.addAll(await getHeaders());
    final fileExtension = filePath.split('.').last;
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: MediaType('audio', fileExtension),
      ),
    );
    return await request.send();
  }
}
