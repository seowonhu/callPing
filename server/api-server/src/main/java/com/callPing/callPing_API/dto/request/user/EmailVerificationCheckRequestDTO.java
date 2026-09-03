package com.callPing.callPing_API.dto.request.user;

import com.callPing.callPing_API.dto.common.constant.ValidationRule;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * 이메일 인증 코드(6자리) 검증 요청.
 * - POST /users/email-verification/check
 * - POST /users/find-id/email-verification/check
 * - POST /users/password-reset/email-verification/check
 * - POST /users/account-unlock/email-verification/check
 */
public record EmailVerificationCheckRequestDTO(

        @NotBlank(message = ValidationRule.EMAIL_BLANK_MESSAGE)
        @Email(message = ValidationRule.EMAIL_FORMAT_MESSAGE)
        String email,

        @NotBlank(message = ValidationRule.VERIFICATION_CODE_BLANK_MESSAGE)
        @Pattern(
                regexp = ValidationRule.VERIFICATION_CODE_REGEXP,
                message = ValidationRule.VERIFICATION_CODE_FORMAT_MESSAGE
        )
        String verificationCode
) {}
