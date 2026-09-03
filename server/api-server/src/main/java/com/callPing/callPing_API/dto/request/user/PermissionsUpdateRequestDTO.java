package com.callPing.callPing_API.dto.request.user;

import jakarta.validation.constraints.NotNull;

/**
 * 파일 업로드 / 푸시 알림 권한 토글 요청.
 * - PATCH /users/me/permissions
 */
public record PermissionsUpdateRequestDTO(

        @NotNull(message = "파일 업로드 권한 값은 필수입니다.")
        Boolean fileUploadPermission,

        @NotNull(message = "푸시 알림 권한 값은 필수입니다.")
        Boolean pushNotificationPermission
) {}
