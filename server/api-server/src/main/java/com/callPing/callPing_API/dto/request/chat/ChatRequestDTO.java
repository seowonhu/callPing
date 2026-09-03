package com.callPing.callPing_API.dto.request.chat;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * RAG 챗봇 질문 요청.
 * - POST /chats
 */
public record ChatRequestDTO(

        @NotNull(message = "room_id는 필수입니다.")
        Long roomId,

        @NotBlank(message = "질문 내용은 필수입니다.")
        String question
) {}
