package com.callPing.callPing_API.dto.response.chat;

import java.time.OffsetDateTime;

/**
 * RAG 챗봇 답변 응답.
 * - POST /chats (질문 응답)
 */
public record ChatResponseDTO(
        Long chatId,
        Long roomId,
        String answer,
        OffsetDateTime createdAt
) {}
