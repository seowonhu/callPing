package com.callPing.callPing_API.dto.response.user;

import java.time.OffsetDateTime;

/**
 * 회원가입 성공 응답.
 * - POST /users
 */
public record SignUpResponseDTO(
        Long userId,
        String loginId,
        OffsetDateTime createdAt
) {}
