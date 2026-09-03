
package com.callPing.callPing_API.dto.response.chat;

import java.time.OffsetDateTime;

/**
 * 채팅방 생성/목록 조회 응답.
 * - POST /chats/rooms (새 채팅방 생성)
 * - GET /chats/rooms (과거 채팅방 목록, List<ChatRoomResponseDTO>로 반환)
 */
public record ChatRoomResponseDTO(
        Long roomId,
        String title,
        OffsetDateTime createdAt
) {}
