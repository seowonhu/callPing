package com.callPing.callPing_API.controller.call;

import com.callPing.callPing_API.dto.common.ApiResponse;
import com.callPing.callPing_API.dto.request.call.CallRecordUpdateRequestDTO;
import com.callPing.callPing_API.dto.request.call.TranscriptCreateRequestDTO;
import com.callPing.callPing_API.dto.request.call.TranscriptUpdateRequestDTO;
import com.callPing.callPing_API.dto.response.call.*;
import com.callPing.callPing_API.dto.common.ApiCode;
import com.callPing.callPing_API.security.UserPrincipal;
import com.callPing.callPing_API.service.call.CallService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/calls")
@RequiredArgsConstructor
public class CallController {

    private final CallService callService;

    // 1. 통화 이력 목록 페이징 조회 (수정됨)
    @ApiCode(code = "CALL_RECORD_LIST_FETCHED", message = "녹음 파일 목록 조회가 완료되었습니다.")
    @GetMapping
    public ResponseEntity<Page<CallRecordListResponseDTO>> getCallRecords(
            @PageableDefault(size = 10, sort = "uploadTime", direction = Sort.Direction.DESC) Pageable pageable,
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        return ResponseEntity.ok(callService.getCallRecords(userDetails.getUserId(), pageable));
    }

    // 2. 녹음 파일 업로드 및 분석 요청 (수정됨: caller_name 필수 해제)
    @ApiCode(code = "CALL_RECORD_UPLOADED", message = "녹음 파일이 성공적으로 업로드되어 분석이 시작되었습니다.")
    @PostMapping
    public ResponseEntity<CallRecordResponseDTO> processCallRecord(
            @RequestParam(value = "caller_name", required = false, defaultValue = "알 수 없음") String callerName,
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(callService.processCallRecord(userDetails.getUserId(), callerName, file));
    }

    // 3. 개별 통화 상세 조회 (STT 대본) (신규)
    @ApiCode(code = "CALL_DETAILS_FETCHED", message = "통화 대본 조회가 완료되었습니다.")
    @GetMapping("/{recordId}/details")
    public ResponseEntity<CallDetailsResponseDTO> getCallDetails(
            @PathVariable Long recordId,
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        return ResponseEntity.ok(callService.getCallDetails(recordId));
    }

    // 4. 사후 분석 요약 결과 조회 (AI 피드백 및 요약) (신규)
    @ApiCode(code = "CALL_ANALYSIS_FETCHED", message = "통화 분석 결과 조회가 완료되었습니다.")
    @GetMapping("/{recordId}/analysis")
    public ResponseEntity<CallAnalysisResponseDTO> getCallAnalysis(
            @PathVariable Long recordId,
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        return ResponseEntity.ok(callService.getCallAnalysis(recordId));
    }

    // 5. 분석 기반 TODO 추출 (신규)
    @ApiCode(code = "CALL_TODOS_FETCHED", message = "통화 연관 할 일 목록 조회가 완료되었습니다.")
    @GetMapping("/{recordId}/todos")
    public ResponseEntity<CallTodoResponseDTO> getCallTodos(
            @PathVariable Long recordId,
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        return ResponseEntity.ok(callService.getCallTodos(recordId));
    }

    // 6. STT 변환 문장 텍스트 수정
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

    // 7. STT 변환 문장 삭제
    @ApiCode(code = "TRANSCRIPT_DELETED", message = "변환된 문장이 삭제되었습니다.")
    @DeleteMapping("/{recordId}/transcripts/{transcriptId}")
    public ResponseEntity<TranscriptDeleteResponseDTO> deleteTranscript(
            @PathVariable Long recordId,
            @PathVariable Long transcriptId,
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        return ResponseEntity.ok(callService.deleteTranscript(recordId, transcriptId));
    }

    // 8. 분석 상태 조회
    @GetMapping("/{recordId}/status")
    public ResponseEntity<java.util.Map<String, String>> getCallStatus(
            @PathVariable Long recordId
    ) {
        String status = callService.getCallStatus(recordId);
        // Map으로 감싸 반환 {"status": "완료"}
        return ResponseEntity.ok(java.util.Map.of("status", status));
    }

    // 9. 통화 기록 정보 수정 (파일명, 관계, 요약)
    @ApiCode(code = "CALL_RECORD_UPDATED", message = "통화 기록 정보가 수정되었습니다.")
    @PatchMapping("/{recordId}")
    public ResponseEntity<java.util.Map<String, Object>> updateCallRecordInfo(
            @PathVariable Long recordId,
            @RequestBody CallRecordUpdateRequestDTO request,
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        callService.updateCallRecordInfo(recordId, request);
        return ResponseEntity.ok(java.util.Map.of("recordId", recordId, "success", true));
    }

    // 10. 통화 기록 및 연관 데이터 삭제
    @ApiCode(code = "CALL_RECORD_DELETED", message = "통화 기록이 삭제되었습니다.")
    @DeleteMapping("/{recordId}")
    public ResponseEntity<java.util.Map<String, Object>> deleteCallRecord(
            @PathVariable Long recordId,
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        callService.deleteCallRecord(recordId);
        return ResponseEntity.ok(java.util.Map.of("recordId", recordId, "success", true));
    }

    // 11. 2단계 파이프라인: 수정한 대본으로 LoRA AI 분석 요청 (신규 추가)
    @ApiCode(code = "CALL_AI_ANALYSIS_STARTED", message = "AI 피드백 및 요약 분석이 시작되었습니다.")
    @PostMapping("/{recordId}/analyze")
    public ResponseEntity<java.util.Map<String, Object>> startAiAnalysis(
            @PathVariable Long recordId,
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        callService.startAiAnalysisAsync(recordId); // 백그라운드 AI 분석 트리거
        return ResponseEntity.ok(java.util.Map.of("recordId", recordId, "status", "AI 분석중"));
    }

    // 12. 말풍선 추가
    @PostMapping("/{recordId}/transcripts")
    public ResponseEntity<ApiResponse<TranscriptSegmentDTO>> addTranscript(
            @PathVariable Long recordId,
            @Valid @RequestBody TranscriptCreateRequestDTO request
    ) {
        TranscriptSegmentDTO addedSegment = callService.addTranscript(recordId, request);

        return ResponseEntity.ok(ApiResponse.success(
                200,
                "CALL_TRANSCRIPT_ADDED",
                "새로운 대화가 성공적으로 추가되었습니다.",
                "/calls/" + recordId + "/transcripts",
                addedSegment
        ));
    }


}
