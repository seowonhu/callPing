package com.callPing.callPing_API.dto.request.session;

import jakarta.validation.constraints.NotBlank;

/**
 * 로그아웃 요청 (refresh token 만료 처리).
 * - DELETE /sessions
 */
public record LogoutRequestDTO(

        @NotBlank(message = "리프레시 토큰은 필수입니다.")
        String refreshToken
) {}
