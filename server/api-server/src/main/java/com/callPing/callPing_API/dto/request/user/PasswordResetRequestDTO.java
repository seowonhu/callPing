package com.callPing.callPing_API.dto.request.user;

import com.callPing.callPing_API.dto.common.constant.ValidationRule;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * 비밀번호 찾기 완료 후 새 비밀번호로 변경.
 * - PATCH /users/password-reset
 */
public record PasswordResetRequestDTO(

        @NotBlank(message = ValidationRule.LOGIN_ID_BLANK_MESSAGE)
        String loginId,

        @NotBlank(message = ValidationRule.EMAIL_BLANK_MESSAGE)
        @Email(message = ValidationRule.EMAIL_FORMAT_MESSAGE)
        String email,

        @NotBlank(message = ValidationRule.PASSWORD_BLANK_MESSAGE)
        @Pattern(
                regexp = ValidationRule.PASSWORD_REGEXP,
                message = ValidationRule.PASSWORD_FORMAT_MESSAGE
        )
        String password
) {}
