package com.callPing.callPing_API.controller.call;

import com.callPing.callPing_API.dto.request.call.TranscriptUpdateRequestDTO;
import com.callPing.callPing_API.dto.response.call.*;
import com.callPing.callPing_API.dto.common.ApiCode;
import com.callPing.callPing_API.security.UserPrincipal;
import com.callPing.callPing_API.service.call.CallService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/calls")
@RequiredArgsConstructor
public class CallController {

    private final CallService callService;

    // 1. 녹음 파일 목록 조회
    @ApiCode(code = "CALL_RECORD_LIST_FETCHED", message = "녹음 파일 목록 조회가 완료되었습니다.")
    @GetMapping
    public ResponseEntity<List<CallRecordListResponseDTO>> getCallRecords(
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        return ResponseEntity.ok(callService.getCallRecords(userDetails.getUserId()));
    }

    // 2. 녹음 파일 업로드 및 분석 요청
    @ApiCode(code = "CALL_RECORD_UPLOADED", message = "녹음 파일이 성공적으로 업로드되어 분석이 시작되었습니다.")
    @PostMapping
    public ResponseEntity<CallRecordResponseDTO> processCallRecord(
            @RequestParam("caller_name") String callerName,
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(callService.processCallRecord(userDetails.getUserId(), callerName, file));
    }

    // 3. 특정 통화 분석 및 피드백 결과 조회
    @ApiCode(code = "CALL_ANALYSIS_FETCHED", message = "통화 분석 결과 조회가 완료되었습니다.")
    @GetMapping("/{recordId}")
    public ResponseEntity<CallAnalysisResponseDTO> getCallAnalysis(
            @PathVariable Long recordId,
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        return ResponseEntity.ok(callService.getCallAnalysis(recordId));
    }

    // 4. STT 변환 문장 텍스트 수정 TODO: 로직아직!!
    @ApiCode(code = "TRANSCRIPT_UPDATED", message = "변환된 문장이 수정되었습니다.")
    @PatchMapping("/{recordId}/transcripts/{transcriptId}")
    public ResponseEntity<TranscriptSegmentDTO> updateTranscript(
            @PathVariable Long recordId,
            @PathVariable Long transcriptId,
            @Valid @RequestBody TranscriptUpdateRequestDTO request,
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        return ResponseEntity.ok(callService.updateTranscript(recordId, transcriptId, request));
    }

    //5. STT 변환 문장 삭제 TODO: 로직아직!!!
    @ApiCode(code = "TRANSCRIPT_DELETED", message = "변환된 문장이 삭제되었습니다.")
    @DeleteMapping("/{recordId}/transcripts/{transcriptId}")
    public ResponseEntity<TranscriptDeleteResponseDTO> deleteTranscript(
            @PathVariable Long recordId,
            @PathVariable Long transcriptId,
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        return ResponseEntity.ok(callService.deleteTranscript(recordId, transcriptId));
    }
}