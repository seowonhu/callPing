package com.callPing.callPing_API.dto.request.user;

import com.callPing.callPing_API.dto.common.constant.ValidationRule;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

/**
 * [이메일 변경 1] 현재 이메일 본인 확인 후, 새 이메일로 인증 코드 발송 요청.
 * - POST /users/me/account/email/verification
 */
public record EmailChangeVerificationRequestDTO(

        @NotBlank(message = ValidationRule.EMAIL_BLANK_MESSAGE)
        @Email(message = ValidationRule.EMAIL_FORMAT_MESSAGE)
        String currentEmail,

        @NotBlank(message = ValidationRule.EMAIL_BLANK_MESSAGE)
        @Email(message = ValidationRule.EMAIL_FORMAT_MESSAGE)
        String newEmail
) {}