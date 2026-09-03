package com.callPing.callPing_API.dto.response.guide;

import java.time.OffsetDateTime;

/**
 * 특정 가이드 세션(guide_id)에 누적된 질문/답변 타임라인 항목.
 * - GET /guides/{guide_id}/messages (List&lt;GuideMessageHistoryResponseDTO&gt;로 반환)
 */
public record GuideMessageHistoryResponseDTO(
        Long messageId,
        String question,
        String answer,
        String tips,
        OffsetDateTime createdAt
) {}
