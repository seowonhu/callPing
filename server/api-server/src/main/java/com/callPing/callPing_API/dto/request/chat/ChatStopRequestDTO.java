package com.callPing.callPing_API.dto.request.chat;

import jakarta.validation.constraints.NotNull;

/**
 * AI 답변 생성 중단 요청.
 * - POST /chats/rooms/{room_id}/stop
 * - displayedAnswer: 중단 시점까지 화면에 표시된 텍스트.
 *   출력 시작 전 중단이면 null 또는 빈 값 (서버가 기본 안내 메시지로 대체 저장)
 */
public record ChatStopRequestDTO(

        @NotNull(message = "chat_id는 필수입니다.")
        Long chatId,

        String answer
) {}