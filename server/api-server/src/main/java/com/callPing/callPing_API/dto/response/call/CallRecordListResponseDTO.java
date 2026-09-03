package com.callPing.callPing_API.dto.response.call;

import java.time.OffsetDateTime;

/**
 * 업로드한 녹음 파일 목록 항목 (메뉴바 '분석' 화면용).
 * analysisStatus가 "완료"인 항목만 프론트에서 탭 가능하게 처리한다.
 * - GET /call-records (List&lt;CallRecordListResponseDTO&gt;로 반환)
 */
public record CallRecordListResponseDTO(
        Long recordId,
        String callerName,
        OffsetDateTime uploadTime,
        String analysisStatus
) {}
