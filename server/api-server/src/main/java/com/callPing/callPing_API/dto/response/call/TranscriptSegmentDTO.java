package com.callPing.callPing_API.dto.response.call;

/**
 * STT 변환 결과의 문장 단위 세그먼트.
 * - GET /call-records/{record_id}/analysis 의 transcript 배열 항목
 * - PATCH /call-records/{record_id}/transcripts/{transcript_id} 성공 응답
 */
public record TranscriptSegmentDTO(
        Long transcriptId,
        String speaker,
        String timestampOffset,
        String text
) {}
