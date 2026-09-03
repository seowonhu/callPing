package com.callPing.callPing_API.dto.response.user;

/**
 * 이메일 변경 성공 응답.
 * - PATCH /users/me/account/email
 */
public record EmailChangeResponseDTO(
        String email
) {}