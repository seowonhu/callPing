package com.callPing.callPing_API.dto.request.user;

import com.callPing.callPing_API.dto.common.constant.ValidationRule;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * [이메일 변경 2 → 3] 인증 코드 검증 및 이메일 변경 확정.
 * - PATCH /users/me/account/email/verification/check
 */
public record EmailChangeVerificationCheckRequestDTO(

        @NotBlank(message = ValidationRule.VERIFICATION_CODE_BLANK_MESSAGE)
        @Pattern(
                regexp = ValidationRule.VERIFICATION_CODE_REGEXP,
                message = ValidationRule.VERIFICATION_CODE_FORMAT_MESSAGE
        )
        String verificationCode
) {}