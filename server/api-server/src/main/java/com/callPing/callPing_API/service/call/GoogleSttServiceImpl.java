package com.callPing.callPing_API.service.call;

import com.callPing.callPing_API.domain.call.CallRecord;
import com.callPing.callPing_API.domain.call.CallTranscript;
import com.google.cloud.speech.v1.*;
import com.google.api.gax.longrunning.OperationFuture;
import com.google.protobuf.Duration;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Service
public class GoogleSttServiceImpl implements GoogleSttService {

    @Override
    public List<CallTranscript> transcribeAudio(String gcsUri, CallRecord callRecord) throws Exception {

        try (SpeechClient speechClient = SpeechClient.create()) {

            // 1. STT 환경 설정
            SpeakerDiarizationConfig diarizationConfig = SpeakerDiarizationConfig.newBuilder()
                    .setEnableSpeakerDiarization(true)
                    .setMinSpeakerCount(2)
                    .setMaxSpeakerCount(3)
                    .build();

            RecognitionConfig config = RecognitionConfig.newBuilder()
                    .setLanguageCode("ko-KR")
                    .setModel("telephony")
                    .setEnableAutomaticPunctuation(true) // 구두점 자동 생성
                    .setEnableWordTimeOffsets(true)      // 타임스탬프 활성화
                    .setDiarizationConfig(diarizationConfig)
                    .build();

            RecognitionAudio audio = RecognitionAudio.newBuilder()
                    .setUri(gcsUri) // GCS URI 사용
                    .build();

            // 2. 비동기 요청 호출
            OperationFuture<LongRunningRecognizeResponse, LongRunningRecognizeMetadata> response =
                    speechClient.longRunningRecognizeAsync(config, audio);

            // 완료될 때까지 대기
            LongRunningRecognizeResponse longRunningResponse = response.get();

            // 3. 단어 -> 문장 조합 로직
            return groupWordsIntoSentences(longRunningResponse, callRecord);
        }
    }

    private List<CallTranscript> groupWordsIntoSentences(LongRunningRecognizeResponse response, CallRecord callRecord) {
        List<CallTranscript> transcripts = new ArrayList<>();

        if (response.getResultsList().isEmpty()) {
            System.out.println("[STT 진단] 결과 리스트가 비어있습니다!");
            return transcripts;
        }

        // STT 진단 1. 전체 Result 개수 확인 (화자 분리 데이터는 항상 마지막 Result에 들어있음)
        System.out.println("==========================================");
        System.out.println("[STT 진단] 총 Result 블록 개수: " + response.getResultsCount());

        SpeechRecognitionResult lastResult = response.getResults(response.getResultsCount() - 1);
        SpeechRecognitionAlternative alternative = lastResult.getAlternatives(0);

        // STT 진단 2. 구글이 매긴 화자 태그 분포 확인
        long speaker1Count = alternative.getWordsList().stream().filter(w -> w.getSpeakerTag() == 1).count();
        long speaker2Count = alternative.getWordsList().stream().filter(w -> w.getSpeakerTag() == 2).count();
        long speaker0Count = alternative.getWordsList().stream().filter(w -> w.getSpeakerTag() == 0).count();

        System.out.println(String.format("[STT 진단] 총 단어 수: %d | 화자1: %d개, 화자2: %d개, 미분류(0): %d개",
                alternative.getWordsCount(), speaker1Count, speaker2Count, speaker0Count));
        System.out.println("==========================================");

        // 응답에 서브워드 기호(▁, _)가 포함되어 있는지 확인
        boolean hasSubwordMarkers = alternative.getWordsList().stream()
                .anyMatch(w -> {
                    String raw = w.getWord();
                    return raw.contains("▁") || raw.contains("\u2581") || raw.contains("_");
                });

        StringBuilder currentSentence = new StringBuilder();
        int currentSpeakerTag = -1;
        String startTime = "00:00";
        long lastWordEndTimeMs = -1;

        int orderIndex = 1000;

        for (WordInfo wordInfo : alternative.getWordsList()) {
            String rawWord = wordInfo.getWord().trim();

            // 1: 기호를 지우기 전에 '새 단어 시작(▁)'인지 체크
            boolean isWordStart = !hasSubwordMarkers
                    || rawWord.startsWith("▁")
                    || rawWord.startsWith("\u2581")
                    || rawWord.startsWith("_");

            // 기호 제거
            String word = rawWord
                    .replace("_", "")
                    .replace("\u2581", "")
                    .replace("▁", "")
                    .trim();

            if (word.isEmpty()) continue;

            // 2: 초(Second) 단위가 아닌 밀리초(ms) 단위로 정밀 계산
            long wordStartTimeMs = toMillis(wordInfo.getStartTime());
            long wordEndTimeMs = toMillis(wordInfo.getEndTime());
            long pauseMs = (lastWordEndTimeMs >= 0) ? (wordStartTimeMs - lastWordEndTimeMs) : 0;

            // 테스트 진단 3. 단어별 원본 데이터 출력 (화자태그 / 침묵시간 / 원본단어)
            System.out.println(String.format("[단어] 화자:%d | 침묵:%4dms | 시간:%5dms~%5dms | 원본:'%s'",
                    wordInfo.getSpeakerTag(), pauseMs, wordStartTimeMs, wordEndTimeMs, rawWord));

            // 화자 태그가 0으로 들어오면 1로 강제 폴백 보정
            int wordSpeakerTag = wordInfo.getSpeakerTag() > 0 ? wordInfo.getSpeakerTag() : 1;

            if (currentSpeakerTag == -1) {
                currentSpeakerTag = wordSpeakerTag;
                startTime = formatTime(wordInfo.getStartTime().getSeconds());
            }

            // 문장 끊는 조건 (화자 변경 / 0.8초 이상 침묵 / 문장이 40자 이상이면서 0.4초 이상 쉼)
            boolean isSpeakerChanged = (currentSpeakerTag != wordSpeakerTag);
            boolean isLongPause = (pauseMs >= 800); // 0.8초(800ms)로 조정
            boolean isMediumPauseOnLongSentence = (currentSentence.length() >= 40 && pauseMs >= 400);

            // 단어 중간이 아닌 '새 단어 시작점'이거나 화자가 바뀌었을 때 말풍선 분리
            if (isSpeakerChanged || (isWordStart && (isLongPause || isMediumPauseOnLongSentence))) {
                if (currentSentence.length() > 0) {
                    transcripts.add(createTranscript(callRecord, currentSpeakerTag, startTime, currentSentence.toString().trim(), orderIndex));
                    orderIndex += 1000;
                    currentSentence.setLength(0);
                }
                currentSpeakerTag = wordSpeakerTag;
                startTime = formatTime(wordInfo.getStartTime().getSeconds());
            }

            // 3: 새 단어(▁)일 때만 앞에 공백 추가
            if (currentSentence.length() > 0 && isWordStart) {
                currentSentence.append(" ");
            }
            currentSentence.append(word);

            lastWordEndTimeMs = wordEndTimeMs;

            // 마침표(. ? !)로 끝나거나, 문장이 길면서(35자 이상) 쉼표(,)로 끝나면 분리
            boolean isPunctuation = word.matches(".*[.?!]$");
            boolean isCommaOnLongSentence = (currentSentence.length() >= 35 && word.endsWith(","));

            if (isPunctuation || isCommaOnLongSentence) {
                transcripts.add(createTranscript(callRecord, currentSpeakerTag, startTime, currentSentence.toString().trim(), orderIndex));
                orderIndex += 1000;
                currentSentence.setLength(0);
                currentSpeakerTag = -1;
                lastWordEndTimeMs = -1;
            }
        }

        // 마지막 남은 텍스트 저장
        if (currentSentence.length() > 0) {
            transcripts.add(createTranscript(callRecord, currentSpeakerTag, startTime, currentSentence.toString().trim(), orderIndex));
        }

        return transcripts;
    }

    // Duration을 밀리초(ms)로 변환하는 헬퍼 메서드
    private long toMillis(Duration duration) {
        return duration.getSeconds() * 1000L + (duration.getNanos() / 1_000_000L);
    }

    private CallTranscript createTranscript(CallRecord callRecord, int speakerTag, String timestampOffset, String text, int orderIndex) {
        return CallTranscript.builder()
                .callRecord(callRecord)
                .speaker("화자 " + speakerTag)
                .timestampOffset(timestampOffset)
                .text(text.trim())
                .orderIndex(orderIndex)
                .build();
    }

    private String formatTime(long totalSeconds) {
        long minutes = totalSeconds / 60;
        long seconds = totalSeconds % 60;
        return String.format("%02d:%02d", minutes, seconds);
    }
}