package com.callPing.callPing_API.dto.request.user;

import com.callPing.callPing_API.dto.common.constant.ValidationRule;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * 로그인 상태에서 비밀번호 변경.
 * - PATCH /users/me/account/password
 */
public record PasswordChangeRequestDTO(

        @NotBlank(message = ValidationRule.PASSWORD_BLANK_MESSAGE)
        String currentPassword,

        @NotBlank(message = ValidationRule.PASSWORD_BLANK_MESSAGE)
        @Pattern(
                regexp = ValidationRule.PASSWORD_REGEXP,
                message = ValidationRule.PASSWORD_FORMAT_MESSAGE
        )
        String newPassword
) {}