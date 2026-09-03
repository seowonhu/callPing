package com.callPing.callPing_API.dto.request.user;

import com.callPing.callPing_API.dto.common.constant.ValidationRule;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * 아이디 중복 확인 요청.
 * - POST /users/check-id
 *
 * 아이디 형식: 5~20자의 영문 소문자, 숫자
 */
public record CheckIdRequestDTO(

        @NotBlank(message = ValidationRule.LOGIN_ID_BLANK_MESSAGE)
        @Pattern(
                regexp = ValidationRule.LOGIN_ID_REGEXP,
                message = ValidationRule.LOGIN_ID_FORMAT_MESSAGE
        )
        String loginId
) {}
