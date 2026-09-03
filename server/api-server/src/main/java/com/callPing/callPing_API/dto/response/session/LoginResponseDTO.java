package com.callPing.callPing_API.dto.response.session;

/**
 * 로그인 성공 응답.
 * - POST /sessions
 */
public record LoginResponseDTO(
        String accessToken,  // Long sessionId -> String accessToken 으로 변경
        Long userId,
        String refreshToken
) {}
