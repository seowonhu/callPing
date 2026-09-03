package com.callPing.callPing_API.dto.response.user;

/**
 * 파일 업로드 / 푸시 알림 권한 조회 응답.
 * - GET /users/me/permissions
 */
public record PermissionsResponseDTO(
        boolean fileUploadPermission,
        boolean pushNotificationPermission
) {}
