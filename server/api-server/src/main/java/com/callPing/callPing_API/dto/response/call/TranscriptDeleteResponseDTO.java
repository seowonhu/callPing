package com.callPing.callPing_API.dto.response.call;

/**
 * STT 문장 삭제 응답. call_transcripts.is_deleted를 true로 갱신하는
 * 소프트 삭제 방식이므로 실제로 레코드가 사라지지는 않는다.
 * - DELETE /call-records/{record_id}/transcripts/{transcript_id}
 */
public record TranscriptDeleteResponseDTO(
        Long transcriptId,
        boolean isDeleted
) {}
