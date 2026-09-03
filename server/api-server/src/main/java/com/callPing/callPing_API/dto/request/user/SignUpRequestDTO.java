package com.callPing.callPing_API.dto.request.user;

import com.callPing.callPing_API.dto.common.constant.ValidationRule;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

/**
 * 최종 회원가입 요청.
 * - POST /users
 *
 * 아이디 형식: 5~20자의 영문 소문자, 숫자 (CheckIdRequestDTO와 동일 규칙 적용)
 */
public record SignUpRequestDTO(

        @NotBlank(message = ValidationRule.LOGIN_ID_BLANK_MESSAGE)
        @Pattern(
                regexp = ValidationRule.LOGIN_ID_REGEXP,
                message = ValidationRule.LOGIN_ID_FORMAT_MESSAGE
        )
        String loginId,

        @NotBlank(message = ValidationRule.PASSWORD_BLANK_MESSAGE)
        @Pattern(
                regexp = ValidationRule.PASSWORD_REGEXP,
                message = ValidationRule.PASSWORD_FORMAT_MESSAGE
        )
        String password,

        @NotBlank(message = ValidationRule.EMAIL_BLANK_MESSAGE)
        @Email(message = ValidationRule.EMAIL_FORMAT_MESSAGE)
        String email,

        @NotNull(message = ValidationRule.TERMS_AGREED_BLANK_MESSAGE)
        @AssertTrue(message = ValidationRule.TERMS_AGREED_FALSE_MESSAGE)
        Boolean termsAgreed
) {}