package com.callPing.callPing_API.dto.response.chat;

import java.time.OffsetDateTime;

/**
 * 특정 채팅방의 질문/답변 타임라인 항목.
 * - GET /chats/rooms/{room_id} (List<ChatRoomDetailResponseDTO>로 반환)
 */
public record ChatRoomDetailResponseDTO(
        Long chatId,
        String question,
        String answer,
        OffsetDateTime createdAt
) {}
