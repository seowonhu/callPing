package com.callPing.callPing_API.dto.response.chat;

/**
 * 채팅(질문/답변) 삭제 응답.
 * - DELETE /chats/{chat_id}
 * - roomDeleted: 삭제 후 해당 방에 남은 채팅이 없어 방까지 함께 삭제된 경우 true
 */
public record ChatDeleteResponseDTO(
        Long chatId,
        Long roomId,
        boolean roomDeleted
) {}