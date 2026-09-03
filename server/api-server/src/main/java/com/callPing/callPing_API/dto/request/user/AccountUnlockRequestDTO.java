package com.callPing.callPing_API.dto.request.user;

import com.callPing.callPing_API.dto.common.constant.ValidationRule;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

/**
 * 계정 잠금 해제 요청 (인증 완료 후).
 * - PATCH /users/account-unlock
 */
public record AccountUnlockRequestDTO(

        @NotBlank(message = ValidationRule.LOGIN_ID_BLANK_MESSAGE)
        String loginId,

        @NotBlank(message = ValidationRule.EMAIL_BLANK_MESSAGE)
        @Email(message = ValidationRule.EMAIL_FORMAT_MESSAGE)
        String email
) {}
