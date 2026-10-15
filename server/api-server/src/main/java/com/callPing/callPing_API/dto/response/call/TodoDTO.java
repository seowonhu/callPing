package com.callPing.callPing_API.dto.response.call;

public record TodoDTO(
        Long todoId,
        Long recordId,
        String recordTitle,
        String taskType,
        String description,
        String priority,
        String status
) {}