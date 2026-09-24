package com.callPing.callPing_API.service.call;

import com.callPing.callPing_API.dto.request.call.TranscriptUpdateRequestDTO;
import com.callPing.callPing_API.dto.response.call.*;
import org.springframework.web.multipart.MultipartFile;
import java.util.List;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

public interface CallService {
    // 1. 녹음 파일 목록 조회
     Page<CallRecordListResponseDTO> getCallRecords(Long userId, Pageable pageable);

    // 2. 녹음 파일 업로드 및 분석 (STT -> AI 연동)
    CallRecordResponseDTO processCallRecord(Long userId, String callerName, MultipartFile file);

    // 3. 통화 분석/피드백 결과 조회
    CallAnalysisResponseDTO getCallAnalysis(Long recordId);

    // 4. STT 변환 문장 수정
    TranscriptSegmentDTO updateTranscript(Long recordId, Long transcriptId, TranscriptUpdateRequestDTO request);

    // 5. STT 문장 삭제
    TranscriptDeleteResponseDTO deleteTranscript(Long recordId, Long transcriptId);

    CallDetailsResponseDTO getCallDetails(Long recordId);

    CallTodoResponseDTO getCallTodos(Long recordId);

    String getCallStatus(Long recordId);

}
