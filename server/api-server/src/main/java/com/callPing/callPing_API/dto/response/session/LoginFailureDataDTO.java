package com.callPing.callPing_API.dto.response.session;

/**
 * 로그인 실패(PASSWORD_MISMATCH) 시 함께 내려주는 잠금 관련 데이터.
 * - POST /sessions 실패 응답의 data 필드
 */
public record LoginFailureDataDTO(
        int failedLoginCount,
        int maxLockCount
) {}
