package com.callPing.callPing_API.dto.common;

import java.time.OffsetDateTime;

public record ApiResponse<T>(
        boolean success,
        int status,
        String code,      // 예: USER_SIGNUP_SUCCESS, USER_ERR_NOT_FOUND
        String message,
        String path,
        OffsetDateTime timestamp,
        T data
) {

    public static <T> ApiResponse<T> success(int status, String code, String message, String path, T data) {
        return new ApiResponse<>(true, status, code, message, path, OffsetDateTime.now(), data);
    }

    public static <T> ApiResponse<T> fail(int status, String code, String message, String path) {
        return fail(status, code, message, path, null);
    }

    public static <T> ApiResponse<T> fail(int status, String code, String message, String path, T data) {
        return new ApiResponse<>(false, status, code, message, path, OffsetDateTime.now(), data);
    }

}
