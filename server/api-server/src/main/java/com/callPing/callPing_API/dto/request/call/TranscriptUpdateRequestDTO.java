package com.callPing.callPing_API.dto.request.call;

import jakarta.validation.constraints.NotBlank;

/**
 * STT 변환 문장 수정 요청.
 * - PATCH /call-records/{record_id}/transcripts/{transcript_id}
 */
public record TranscriptUpdateRequestDTO(

        @NotBlank(message = "수정할 텍스트는 필수입니다.")
        String text
) {}
