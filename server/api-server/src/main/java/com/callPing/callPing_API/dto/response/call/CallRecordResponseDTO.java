package com.callPing.callPing_API.dto.response.call;

import java.time.OffsetDateTime;

/**
 * 통화 녹음 파일 업로드 성공 응답.
 * - POST /call-records
 */
public record CallRecordResponseDTO(
        Long recordId,
        String callerName,
        String fileName,
        OffsetDateTime uploadTime,
        String analysisStatus
) {}
