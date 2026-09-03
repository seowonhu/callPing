package com.callPing.callPing_API.dto.response.guide;

import java.time.OffsetDateTime;

/**
 * 같은 가이드 세션에 이어지는 질문에 대한 응답 (재요청 응답).
 * - POST /guides/{guide_id}/messages
 */
public record GuideMessageResponseDTO(
        Long guideId,
        Long messageId,
        String question,
        String answer,
        String tips,
        OffsetDateTime createdAt
) {}
