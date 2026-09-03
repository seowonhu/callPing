package com.callPing.callPing_API.dto.response.guide;

import java.time.OffsetDateTime;

/**
 * 과거 가이드 세션 목록 항목 (통화 가이드 화면 상단 드롭다운용).
 * - GET /guides (List&lt;GuideListResponseDTO&gt;로 반환)
 */
public record GuideListResponseDTO(
        Long guideId,
        String title,
        OffsetDateTime createdAt
) {}
