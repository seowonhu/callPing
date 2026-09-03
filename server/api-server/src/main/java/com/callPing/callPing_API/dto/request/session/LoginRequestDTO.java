package com.callPing.callPing_API.dto.request.session;

import jakarta.validation.constraints.NotBlank;

/**
 * 로그인 요청.
 * - POST /sessions
 */
public record LoginRequestDTO(

        @NotBlank(message = "아이디는 필수입니다.")
        String loginId,

        @NotBlank(message = "비밀번호는 필수입니다.")
        String password
) {}
