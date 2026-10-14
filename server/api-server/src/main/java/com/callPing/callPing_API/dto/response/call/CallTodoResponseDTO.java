package com.callPing.callPing_API.dto.response.call;

import java.util.List;

public record CallTodoResponseDTO(
        Long recordId,
        String recordTitle,
        String todoSummary,
        List<TodoDTO> todos
) {}