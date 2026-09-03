package com.callPing.callPing_API.dto.request.user;

import com.callPing.callPing_API.dto.common.constant.ValidationRule;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

/**
 * 이메일 인증 코드 발송 요청.
 * - POST /users/email-verification
 * - POST /users/find-id/email-verification
 * - POST /users/password-reset/email-verification
 * - POST /users/account-unlock/email-verification
 */
public record EmailVerificationRequestDTO(

        @NotBlank(message = ValidationRule.EMAIL_BLANK_MESSAGE)
        @Email(message = ValidationRule.EMAIL_FORMAT_MESSAGE)
        String email
) {}
