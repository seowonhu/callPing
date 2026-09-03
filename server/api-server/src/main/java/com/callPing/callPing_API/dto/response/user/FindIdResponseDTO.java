package com.callPing.callPing_API.dto.response.user;

/**
 * 아이디 찾기 성공 응답.
 * - POST /users/find-id
 */
public record FindIdResponseDTO(
        String loginId
) {}
