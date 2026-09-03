package com.callPing.callPing_API.dto.response.user;

/**
 * 내 정보(프로필) 조회 응답.
 * - GET /users/me
 */
public record UserProfileResponseDTO(
        Long userId,
        String loginId,
        String email
) {}
