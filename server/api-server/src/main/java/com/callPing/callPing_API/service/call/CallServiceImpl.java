package com.callPing.callPing_API.service.call;

import com.callPing.callPing_API.domain.Todo;
import com.callPing.callPing_API.domain.call.CallRecord;
import com.callPing.callPing_API.domain.call.CallTranscript;
import com.callPing.callPing_API.dto.request.call.CallRecordUpdateRequestDTO;
import com.callPing.callPing_API.dto.request.call.TranscriptCreateRequestDTO;
import com.callPing.callPing_API.dto.request.call.TranscriptUpdateRequestDTO;
import com.callPing.callPing_API.dto.response.call.*;
import com.callPing.callPing_API.repository.TodoRepository;
import com.callPing.callPing_API.repository.call.CallRecordRepository;
import com.callPing.callPing_API.repository.call.CallTranscriptRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class CallServiceImpl implements CallService {

    private final CallRecordRepository callRecordRepository;
    private final CallTranscriptRepository callTranscriptRepository;
    private final TodoRepository todoRepository;
    private final GoogleSttService googleSttService;
    private final AiFeedbackService aiFeedbackService;
    private final GcsUploadService gcsUploadService;
    private final ObjectMapper objectMapper;

    // =========================================================================
    // 1. 녹음 파일 목록 페이징 조회
    // =========================================================================
    @Override
    @Transactional(readOnly = true)
    public Page<CallRecordListResponseDTO> getCallRecords(Long userId, Pageable pageable) {
        return callRecordRepository.findAllByUserIdOrderByUploadTimeDesc(userId, pageable)
                .map(record -> new CallRecordListResponseDTO(
                        record.getId(),
                        record.getCallerName(),
                        record.getUploadTime(),
                        record.getAnalysisStatus()
                ));
    }

    // =========================================================================
    // 2. 녹음 파일 업로드 및 분석 요청
    // =========================================================================
    @Override
    @Transactional
    public CallRecordResponseDTO processCallRecord(Long userId, String callerName, MultipartFile file) {
        CallRecord callRecord = CallRecord.builder()
                .userId(userId)
                .callerName(callerName)
                .fileName(file.getOriginalFilename())
                .uploadTime(OffsetDateTime.now())
                .analysisStatus("분석중")
                .build();
        callRecordRepository.save(callRecord);

        try {
            String gcsUri = gcsUploadService.uploadAudioFile(file);
            processSttAsync(callRecord.getId(), gcsUri);
        } catch (Exception e) {
            log.error("GCS 업로드 실패", e);
            throw new RuntimeException("녹음 파일 업로드에 실패했습니다.");
        }

        return new CallRecordResponseDTO(
                callRecord.getId(),
                callRecord.getCallerName(),
                callRecord.getFileName(),
                callRecord.getUploadTime(),
                callRecord.getAnalysisStatus()
        );
    }

    // =========================================================================
    // 3. 통화 분석/피드백 결과 조회
    // =========================================================================
    @Override
    @Transactional(readOnly = true)
    public CallAnalysisResponseDTO getCallAnalysis(Long recordId) {
        CallRecord callRecord = callRecordRepository.findById(recordId)
                .orElseThrow(() -> new IllegalArgumentException("해당 녹음 기록을 찾을 수 없습니다."));

        List<TranscriptSegmentDTO> segments = callRecord.getTranscripts().stream()
                .filter(t -> !t.isDeleted())
                .map(t -> new TranscriptSegmentDTO(
                        t.getId(),
                        t.getSpeaker(),
                        t.getTimestampOffset(),
                        t.getText(),
                        t.getOrderIndex()
                ))
                .collect(Collectors.toList());

        return new CallAnalysisResponseDTO(
                callRecord.getId(),
                callRecord.getFileName(),
                segments,               // 1. 기존 DTO에 있던 transcript 리스트
                callRecord.getSummary(),    // 2. summary
                "화자 분석 완료",          // 3. speakerResult (현재 AI 모델에 없으므로 임시 문자열)
                callRecord.getExpression(), // 4. expression
                callRecord.getFeedback(),   // 5. feedback
                callRecord.getUploadTime()  // 6. createdAt (업로드 시간으로 대체)
        );
    }

    // =========================================================================
    // 3-1. 개별 통화 상세 조회 (STT 대본)
    // =========================================================================
    @Override
    @Transactional(readOnly = true)
    public CallDetailsResponseDTO getCallDetails(Long recordId) {
        CallRecord record = callRecordRepository.findById(recordId)
                .orElseThrow(() -> new IllegalArgumentException("레코드 없음"));

        // 삭제 안 된 대본을 DTO로 변환
        List<TranscriptSegmentDTO> segments = record.getTranscripts().stream()
                .filter(t -> !t.isDeleted())
                .map(t -> new TranscriptSegmentDTO(
                        t.getId(),
                        t.getSpeaker(),
                        t.getTimestampOffset(),
                        t.getText(),
                        t.getOrderIndex()
                ))
                .collect(Collectors.toList());

        return new CallDetailsResponseDTO(
                record.getId(),
                record.getCallerName(),
                record.getUploadTime(),
                record.getAnalysisStatus(),
                segments
        );
    }

    // =========================================================================
    // 3-2. 분석 기반 TODO 추출
    // =========================================================================
    @Override
    @Transactional(readOnly = true)
    public CallTodoResponseDTO getCallTodos(Long recordId) {
        CallRecord record = callRecordRepository.findById(recordId)
                .orElseThrow(() -> new IllegalArgumentException("레코드 없음"));

        // 이 통화 기록에서 파생된 TODO 목록 꺼내오기
        List<Todo> todos = todoRepository.findByCallRecordId(recordId);

        // TODO들을 DTO로 변환
        List<TodoDTO> todoDTOs = todos.stream()
                .map(t -> new TodoDTO(t.getId(), t.getTaskType(), t.getDescription(), t.getPriority(), t.getStatus()))
                .collect(Collectors.toList());

        String summary = "총 " + todos.size() + "건의 후속 조치가 필요합니다.";

        return new CallTodoResponseDTO(record.getId(),
                record.getFileName(),
                summary, todoDTOs);
    }

    // =========================================================================
    // 4. STT 변환 문장 수정
    // =========================================================================
    @Override
    @Transactional
    public TranscriptSegmentDTO updateTranscript(Long recordId, Long transcriptId, TranscriptUpdateRequestDTO request) {
        // 1. 해당 문장이 DB에 존재하는지 확인
        CallTranscript transcript = callTranscriptRepository.findById(transcriptId)
                .orElseThrow(() -> new IllegalArgumentException("해당 문장을 찾을 수 없습니다."));

        // 2. 엔티티 텍스트 수정
        transcript.updateText(request.text(), request.speaker(), request.orderIndex());
        // 3. 수정된 결과를 DTO로 조립하여 반환
        return new TranscriptSegmentDTO(
                transcript.getId(),
                transcript.getSpeaker(),
                transcript.getTimestampOffset(),
                transcript.getText(),
                transcript.getOrderIndex()
        );
    }

    // =========================================================================
    // 5. STT 문장 삭제
    // =========================================================================
    @Override
    @Transactional
    public TranscriptDeleteResponseDTO deleteTranscript(Long recordId, Long transcriptId) {
        // 1. 해당 문장 조회
        CallTranscript transcript = callTranscriptRepository.findById(transcriptId)
                .orElseThrow(() -> new IllegalArgumentException("해당 문장을 찾을 수 없습니다."));

        // 2. 삭제 상태로 변경 (실제 DB에서 지우지 않고 숨김 처리)
        transcript.markAsDeleted();

        // 3. 삭제 성공 응답 반환
        return new TranscriptDeleteResponseDTO(
                transcriptId,
                true
        );
    }

    // =========================================================================
    // 비동기 STT & AI 피드백 파이프라인 ==> 2단계로 분리
    // =========================================================================
    // =========================================================================
    // [1단계] 파일 업로드 직후: 비동기 STT 변환 수행
    // =========================================================================
    @Async
    @Transactional
    public void processSttAsync(Long recordId, String gcsUri) { // 메서드명 변경 및 AI호출 부분 삭제
        CallRecord callRecord = callRecordRepository.findById(recordId)
                .orElseThrow(() -> new IllegalArgumentException("레코드 없음"));
        try {
            log.info("1단계 STT 분석 시작 - recordId: {}", recordId);
            List<CallTranscript> transcripts = googleSttService.transcribeAudio(gcsUri, callRecord);
            transcripts.forEach(callRecord::addTranscript);
            callTranscriptRepository.saveAll(transcripts);

            // STT 완료 후 상태를 변경하여 프론트가 대본을 불러오도록 유도
            callRecord.updateAiAnalysis(null, null, null, null, "대본 수정 대기");
            log.info("1단계 STT 분석 완료 (수정 대기 상태 전환) - recordId: {}", recordId);
        } catch (Exception e) {
            log.error("STT 변환 중 에러 발생", e);
            callRecord.updateAiAnalysis(null, null, null, null, "실패");
        }
    }

    // =========================================================================
    // [2단계] 프론트엔드 호출 후: 교정된 대본으로 LoRA AI 분석 수행
    // =========================================================================
    @Override
    @Async
    @Transactional
    public void startAiAnalysisAsync(Long recordId) {
        CallRecord callRecord = callRecordRepository.findById(recordId)
                .orElseThrow(() -> new IllegalArgumentException("레코드 없음"));

        try {
            log.info("2단계 LoRA AI 분석 시작 - recordId: {}", recordId);
            callRecord.updateAiAnalysis(null, null, null, null, "AI 분석중"); // 로딩바 진행용

            // 삭제 처리되지 않은 대본만 모아서 AI 서버로 전송
            List<CallTranscript> activeTranscripts = callRecord.getTranscripts().stream()
                    .filter(t -> !t.isDeleted())
                    .collect(Collectors.toList());

            String rawAiResponse = aiFeedbackService.getAiFeedback(activeTranscripts);

            log.info("🚨 LoRA AI 실제 응답 원문: \n{}", rawAiResponse);

            // 파싱 및 저장
            parseAndSaveAiResponse(rawAiResponse, callRecord);
            log.info("2단계 LoRA AI 분석 완료 - recordId: {}", recordId);

        } catch (Exception e) {
            log.error("LoRA AI 분석 중 에러 발생", e);
            callRecord.updateAiAnalysis(null, null, null, null, "AI 분석 실패");
        }
    }

    // 새로운 AI 응답 파서
    private void parseAndSaveAiResponse(String rawAiResponse, CallRecord callRecord) {
        try {
            JsonNode rootNode = objectMapper.readTree(rawAiResponse);

            // 1. AI가 'llm_feedback' 껍데기를 누락하거나 이름을 바꿨을 경우를 대비한 다중 탐색
            JsonNode feedbackNode = rootNode.path("llm_feedback");
            if (feedbackNode.isMissingNode()) feedbackNode = rootNode.path("llmFeedback"); // 카멜케이스 대비
            if (feedbackNode.isMissingNode()) feedbackNode = rootNode; // 껍데기 없이 평면(Flat)으로 보냈을 경우 대비

            // 2. 각 필드 데이터 추출 (스네이크 케이스, 카멜 케이스 모두 대비)
            String expression = feedbackNode.path("tone_analysis").asText("");
            if (expression.isBlank()) expression = feedbackNode.path("toneAnalysis").asText("");

            String speechFeedback = feedbackNode.path("speech_feedback").asText("");
            if (speechFeedback.isBlank()) speechFeedback = feedbackNode.path("speechFeedback").asText("");

            String improvement = feedbackNode.path("improvement_points").asText("");
            if (improvement.isBlank()) improvement = feedbackNode.path("improvementPoints").asText("");

            // 3. 피드백 문자열 조합 (빈 껍데기 " / 개선점: " 방지)
            String feedback = speechFeedback;
            if (!improvement.isBlank()) {
                feedback += (feedback.isBlank() ? "" : " / 개선점: ") + improvement;
            }

            // 값이 없을 때의 깔끔한 기본값
            if (expression.isBlank()) expression = "표현 분석 결과가 없습니다.";
            if (feedback.isBlank()) feedback = "피드백 내용이 없습니다.";

            // 요약 추출
            String summary = rootNode.path("todo_summary").asText("");
            if (summary.isBlank()) summary = rootNode.path("todoSummary").asText("요약 정보가 없습니다.");
            String keywords = "미제공";

            // DB 업데이트
            callRecord.updateAiAnalysis(expression, feedback, summary, keywords, "완료");

            // 4. TODO 리스트 추출
            JsonNode todosNode = rootNode.path("todos");
            if (todosNode.isArray()) {
                List<Todo> newTodos = new ArrayList<>();
                for (JsonNode todoItem : todosNode) {
                    Todo todo = Todo.builder()
                            .userId(callRecord.getUserId())
                            .callRecord(callRecord)
                            .taskType(todoItem.path("task_type").asText(todoItem.path("taskType").asText("MANUAL")))
                            .description(todoItem.path("description").asText("내용 없음"))
                            .priority(todoItem.path("priority").asText("MEDIUM"))
                            .status(todoItem.path("status").asText("PENDING"))
                            .createdAt(OffsetDateTime.now())
                            .build();
                    newTodos.add(todo);
                }
                todoRepository.saveAll(newTodos);
            }

        } catch (Exception e) {
            log.warn("AI 응답 JSON 파싱 실패. 일반 텍스트로 간주하여 저장합니다. 원문: {}", rawAiResponse);
            callRecord.updateAiAnalysis("파싱 실패", rawAiResponse, "파싱 실패", "", "완료");
        }
    }

    // =========================================================================
    // 통화 분석 진행 상태 조회 (프론트엔드 폴링용)
    // =========================================================================
    @Override
    @Transactional(readOnly = true)
    public String getCallStatus(Long recordId) {
        return callRecordRepository.findById(recordId)
                .map(CallRecord::getAnalysisStatus)
                .orElseThrow(() -> new IllegalArgumentException("레코드 없음"));
    }

    // =========================================================================
    // 9. 통화 기록 정보 수정 (파일명, 관계, 요약)
    // =========================================================================
    @Override
    @Transactional
    public void updateCallRecordInfo(Long recordId, CallRecordUpdateRequestDTO request) {
        CallRecord callRecord = callRecordRepository.findById(recordId)
                .orElseThrow(() -> new IllegalArgumentException("해당 녹음 기록을 찾을 수 없습니다."));

        callRecord.updateFileInfo(request.fileName(), request.callerName(), request.summary());
    }

    // =========================================================================
    // 10. 통화 기록 완전 삭제
    // =========================================================================
    @Override
    @Transactional
    public void deleteCallRecord(Long recordId) {
        CallRecord callRecord = callRecordRepository.findById(recordId)
                .orElseThrow(() -> new IllegalArgumentException("해당 녹음 기록을 찾을 수 없습니다."));

        //  1. 자식 데이터(todos)를 먼저 삭제
        // (TodoRepository에 void deleteByCallRecordId(Long callRecordId); 메서드가 있어야 함)
        todoRepository.deleteAll(callRecord.getTodos());

        // 2. 그 다음 부모(callRecord)를 지운다.
        callRecordRepository.delete(callRecord);

        callRecordRepository.delete(callRecord);
    }

    // =========================================================================
    // 11. STT 문장(말풍선) 수동 추가
    // =========================================================================
    @Override
    @Transactional
    public TranscriptSegmentDTO addTranscript(Long recordId, TranscriptCreateRequestDTO request) {
        // 1. 부모 통화 기록 찾기
        CallRecord callRecord = callRecordRepository.findById(recordId)
                .orElseThrow(() -> new IllegalArgumentException("해당 녹음 기록을 찾을 수 없습니다."));

        // 말풍선 끼워넣을 위치(orderIndex, 예: 1500)를 보냈으면 그 값을 그대로 사용
        // 안 보냈을 때(null)만 맨 마지막 말풍선 뒤에 붙도록 처리
        int targetOrderIndex;
        if (request.orderIndex() != null) {
            targetOrderIndex = request.orderIndex();
        } else {
            targetOrderIndex = callRecord.getTranscripts().stream()
                    .mapToInt(t -> t.getOrderIndex() != null ? t.getOrderIndex() : 0)
                    .max()
                    .orElse(0) + 1000;
        }

        CallTranscript newTranscript = CallTranscript.builder()
                .callRecord(callRecord)
                .speaker(request.speaker())
                .text(request.text())
                .timestampOffset(request.timestampOffset() != null ? request.timestampOffset() : "00:00")
                .orderIndex(targetOrderIndex) // 지정된 위치 인덱스로 저장
                .isDeleted(false)
                .build();

        // 3. 부모 리스트에 추가하고 저장 (Cascade 설정으로 인해 save 됨)
        callRecord.addTranscript(newTranscript);
        callTranscriptRepository.save(newTranscript);

        // 4. 생성된 결과를  DTO로 반환
        return new TranscriptSegmentDTO(
                newTranscript.getId(),
                newTranscript.getSpeaker(),
                newTranscript.getTimestampOffset(),
                newTranscript.getText(),
                newTranscript.getOrderIndex()
        );
    }
}
