package com.callPing.callPing_API.dto.response.guide;

import java.time.OffsetDateTime;

/**
 * 가이드 세션 생성 성공 응답 (첫 질문에 대한 답변 포함).
 * - POST /guides
 */
public record GuideResponseDTO(
        Long guideId,
        Long messageId,
        String title,
        String question,
        String answer,
        String tips,
        OffsetDateTime createdAt
) {}
