package com.callPing.callPing_API.dto.response.chat;

/**
 * 채팅방 전체 삭제 응답.
 * - DELETE /chats/rooms/{room_id}
 */
public record ChatRoomDeleteResponseDTO(
        Long roomId
) {}