package com.callPing.callPing_API.dto.response.call;

import java.time.OffsetDateTime;
import java.util.List;

/**
 * 통화 분석/피드백 결과 조회 응답 (피드백 화면용).
 * transcript는 is_deleted=true인 문장을 제외하고 반환한다.
 * - GET /call-records/{record_id}/analysis
 */
public record CallAnalysisResponseDTO(
        Long recordId,
        List<TranscriptSegmentDTO> transcript,
        String summary,
        String speakerResult,
        String expression,
        String feedback,
        OffsetDateTime createdAt
) {}
