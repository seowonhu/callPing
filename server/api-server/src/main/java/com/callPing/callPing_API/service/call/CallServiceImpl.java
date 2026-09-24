package com.callPing.callPing_API.service.call;

import com.callPing.callPing_API.domain.Todo;
import com.callPing.callPing_API.domain.call.CallRecord;
import com.callPing.callPing_API.domain.call.CallTranscript;
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
            processSttAndAiAsync(callRecord.getId(), gcsUri);
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
                .map(t -> new TranscriptSegmentDTO(t.getId(), t.getSpeaker(), t.getTimestampOffset(), t.getText()))
                .collect(Collectors.toList());

        return new CallAnalysisResponseDTO(
                callRecord.getId(),
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
                .map(t -> new TranscriptSegmentDTO(t.getId(), t.getSpeaker(), t.getTimestampOffset(), t.getText()))
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

        return new CallTodoResponseDTO(record.getId(), summary, todoDTOs);
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

        // 2. 엔티티 텍스트 수정 (TranscriptUpdateRequestDTO가 record 타입이면 request.text(), 일반 클래스면 request.getText() 사용)
        transcript.updateText(request.text());

        // 3. 수정된 결과를 DTO로 조립하여 반환
        return new TranscriptSegmentDTO(
                transcript.getId(),
                transcript.getSpeaker(),
                transcript.getTimestampOffset(),
                transcript.getText()
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
    // 비동기 STT & AI 피드백 파이프라인
    // =========================================================================
    @Async
    @Transactional
    public void processSttAndAiAsync(Long recordId, String gcsUri) {
        CallRecord callRecord = callRecordRepository.findById(recordId)
                .orElseThrow(() -> new IllegalArgumentException("레코드 없음"));

        try {
            log.info("비동기 분석 시작 - recordId: {}", recordId);

            List<CallTranscript> transcripts = googleSttService.transcribeAudio(gcsUri, callRecord);
            transcripts.forEach(callRecord::addTranscript);
            callTranscriptRepository.saveAll(transcripts);

            List<String> sentences = transcripts.stream()
                    .map(CallTranscript::getText)
                    .collect(Collectors.toList());

            // AI 서버에 전송
            String rawAiResponse = aiFeedbackService.getAiFeedback(sentences);

            // AI 텍스트 JSON 파싱 및 TODO 추출 로직 실행
            parseAndSaveAiResponse(rawAiResponse, callRecord);

            log.info("비동기 분석 및 TODO 추출 완료 - recordId: {}", recordId);

        } catch (Exception e) {
            log.error("비동기 분석 중 에러 발생 - recordId: {}", recordId, e);
            callRecord.updateAiAnalysis(null, null, null, null, "실패");
        }
    }

    // 새로운 AI 응답 파서
    private void parseAndSaveAiResponse(String rawAiResponse, CallRecord callRecord) {
        try {
            JsonNode rootNode = objectMapper.readTree(rawAiResponse);

            JsonNode feedbackNode = rootNode.path("llm_feedback");
            String expression = feedbackNode.path("tone_analysis").asText("");
            String feedback = feedbackNode.path("speech_feedback").asText("")
                    + " / 개선점: " + feedbackNode.path("improvement_points").asText("");
            String summary = rootNode.path("todo_summary").asText("요약 정보가 없습니다.");
            String keywords = "미제공";

            callRecord.updateAiAnalysis(expression, feedback, summary, keywords, "완료");

            JsonNode todosNode = rootNode.path("todos");
            if (todosNode.isArray()) {
                List<Todo> newTodos = new ArrayList<>();
                for (JsonNode todoItem : todosNode) {
                    Todo todo = Todo.builder()
                            .userId(callRecord.getUserId())
                            .callRecord(callRecord)
                            .taskType(todoItem.path("task_type").asText("MANUAL"))
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
            callRecord.updateAiAnalysis("", rawAiResponse, "파싱 실패", "", "완료");
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
}
