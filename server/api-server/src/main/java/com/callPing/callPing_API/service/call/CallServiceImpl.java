package com.callPing.callPing_API.service.call;

import com.callPing.callPing_API.domain.call.CallRecord;
import com.callPing.callPing_API.domain.call.CallTranscript;
import com.callPing.callPing_API.dto.request.call.TranscriptUpdateRequestDTO;
import com.callPing.callPing_API.dto.response.call.*;
import com.callPing.callPing_API.repository.call.CallRecordRepository;
import com.callPing.callPing_API.repository.call.CallTranscriptRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class CallServiceImpl implements CallService {

    private final CallRecordRepository callRecordRepository;
    private final CallTranscriptRepository callTranscriptRepository;
    private final GoogleSttService googleSttService;
    private final AiFeedbackService aiFeedbackService;
    private final GcsUploadService gcsUploadService;

    // =========================================================================
    // 녹음 파일 목록 조회
    // =========================================================================
    @Override
    @Transactional(readOnly = true)
    public List<CallRecordListResponseDTO> getCallRecords(Long userId) {
        return callRecordRepository.findAllByUserIdOrderByUploadTimeDesc(userId).stream()
                .map(record -> new CallRecordListResponseDTO(
                        record.getId(),
                        record.getCallerName(),
                        record.getUploadTime(),
                        record.getAnalysisStatus()
                ))
                .toList();
    }

    // =========================================================================
    // 녹음 파일 업로드 및 분석 요청
    // =========================================================================
    @Override
    @Transactional
    public CallRecordResponseDTO processCallRecord(Long userId, String callerName, MultipartFile file) {

        // DB에 '분석 중'으로 레코드 생성
        CallRecord callRecord = CallRecord.builder()
                .userId(userId)
                .callerName(callerName)
                .fileName(file.getOriginalFilename())
                .uploadTime(OffsetDateTime.now())
                .analysisStatus("분석중")
                .build();
        callRecordRepository.save(callRecord);

        try {
            // GCS에 파일 업로드 후 gs:// URI 반환
            String gcsUri = gcsUploadService.uploadAudioFile(file);

            // 비동기로 STT 분석 및 AI 분석 백그라운드 실행
            processSttAndAiAsync(callRecord.getId(), gcsUri);

        } catch (Exception e) {
            log.error("GCS 업로드 실패", e);
            throw new RuntimeException("녹음 파일 업로드에 실패했습니다.");
        }

        // 클라이언트에는 즉시 업로드 성공 응답 반환
        return new CallRecordResponseDTO(
                callRecord.getId(),
                callRecord.getCallerName(),
                callRecord.getFileName(),
                callRecord.getUploadTime(),
                callRecord.getAnalysisStatus()
        );
    }

    // =========================================================================
    // 3. 통화 분석/피드백 결과 조회 (임시)
    // =========================================================================
    @Override
    @Transactional(readOnly = true)
    public CallAnalysisResponseDTO getCallAnalysis(Long recordId) {
        CallRecord callRecord = callRecordRepository.findById(recordId)
                .orElseThrow(() -> new IllegalArgumentException("해당 녹음 기록을 찾을 수 없습니다."));

        // TODO: CallAnalysisResponseDTO 스펙에 맞추어 변환 로직 보완
        return null;
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
        transcript.updateText(request.text());

        // 3. 수정된 결과를 DTO로 반환
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

        // 2. 삭제 상태로 변경 (Soft Delete)
        transcript.markAsDeleted();

        // 3. 삭제 완료 응답 반환
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

            // Google STT V2 호출 및 단어를 문장으로 병합
            List<CallTranscript> transcripts = googleSttService.transcribeAudio(gcsUri, callRecord);

            transcripts.forEach(callRecord::addTranscript);
            callTranscriptRepository.saveAll(transcripts);

            // AI 서버용 문장 리스트 추출
            List<String> sentences = transcripts.stream()
                    .map(CallTranscript::getText)
                    .collect(Collectors.toList());

            // AI 서버에 전송 (최대 60초 대기)
            String rawAiResponse = aiFeedbackService.getAiFeedback(sentences);

            // AI 텍스트 결과 파싱
            String[] parsedResults = parseAiResponse(rawAiResponse);
            String expression = parsedResults[0];
            String feedback = parsedResults[1];

            // DB 상태 업데이트
            callRecord.updateAiAnalysis(expression, feedback, "완료");
            log.info("비동기 분석 완료 - recordId: {}", recordId);

        } catch (Exception e) {
            log.error("비동기 분석 중 에러 발생 - recordId: {}", recordId, e);
            callRecord.updateStatus("실패");
        }
    }


    private String[] parseAiResponse(String rawText) {
        String expression = "";
        String feedback = "";

        if (rawText.contains("[표현 분석]") && rawText.contains("[개선 피드백]")) {
            try {
                int expStart = rawText.indexOf("[표현 분석]") + "[표현 분석]".length();
                int fbStart = rawText.indexOf("[개선 피드백]");

                expression = rawText.substring(expStart, fbStart).trim();
                feedback = rawText.substring(fbStart + "[개선 피드백]".length()).trim();

            } catch (Exception e) {
                log.warn("AI 텍스트 파싱 오류 발생. 원문 전체를 피드백으로 이동합니다.");
                feedback = rawText;
            }
        } else {
            log.info("AI 응답에 섹션 헤더가 없어 전체 텍스트를 피드백으로 폴백합니다.");
            feedback = rawText;
        }

        return new String[]{expression, feedback};
    }
}