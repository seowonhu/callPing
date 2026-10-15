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

            // 1. STT 화자 분리 설정 (1:1 통화에 맞춰 Min 2, Max 2)
            SpeakerDiarizationConfig diarizationConfig = SpeakerDiarizationConfig.newBuilder()
                    .setEnableSpeakerDiarization(true)
                    .setMinSpeakerCount(2)
                    .setMaxSpeakerCount(2)
                    .build();

            RecognitionConfig config = RecognitionConfig.newBuilder()
                    .setLanguageCode("ko-KR")
                    .setEnableAutomaticPunctuation(true) // 구두점 자동 생성
                    .setEnableWordTimeOffsets(true)      // 타임스탬프 활성화
                    .setDiarizationConfig(diarizationConfig)
                    .build();

            RecognitionAudio audio = RecognitionAudio.newBuilder()
                    .setUri(gcsUri)
                    .build();

            // 2. 비동기 요청 호출
            OperationFuture<LongRunningRecognizeResponse, LongRunningRecognizeMetadata> response =
                    speechClient.longRunningRecognizeAsync(config, audio);

            LongRunningRecognizeResponse longRunningResponse = response.get();

            // 3. 단어 -> 문장 조합 로직
            return groupWordsIntoSentences(longRunningResponse, callRecord);
        }
    }

    private List<CallTranscript> groupWordsIntoSentences(LongRunningRecognizeResponse response, CallRecord callRecord) {
        List<CallTranscript> transcripts = new ArrayList<>();

        if (response.getResultsList().isEmpty()) return transcripts;

        // 구글 STT는 화자 분리 결과를 가장 마지막 Result에 몰아서 줌
        SpeechRecognitionResult lastResult = response.getResults(response.getResultsCount() - 1);
        SpeechRecognitionAlternative alternative = lastResult.getAlternatives(0);

        StringBuilder currentSentence = new StringBuilder();
        int currentSpeakerTag = -1;
        String startTime = "00:00";
        long lastWordEndTimeMs = -1;
        boolean prevEndedWithConnector = false;

        int orderIndex = 1000;

        long distinctSpeakers = alternative.getWordsList().stream()
                .mapToInt(WordInfo::getSpeakerTag)
                .distinct()
                .count();
        boolean isDiarizationCollapsed = (distinctSpeakers <= 1);
        int fallbackSpeaker = 1; // STT 화자 분리가 되지 않았을 때 교대해 줄 화자 번호 (1 <-> 2)

        for (WordInfo wordInfo : alternative.getWordsList()) {
            String rawWord = wordInfo.getWord().trim();
            if (rawWord.isEmpty()) continue;

            //1: '_' 나 '▁'가 붙어있는 조각인지 확인
            boolean startsWithUnderscore = rawWord.startsWith("_") || rawWord.startsWith("▁") || rawWord.startsWith("\u2581");
            boolean endsWithUnderscore = rawWord.endsWith("_") || rawWord.endsWith("▁") || rawWord.endsWith("\u2581");

            // 기호 제거 및 단어 내부의 불필요한 기호 밀착
            String word = rawWord
                    .replace("_", "")
                    .replace("\u2581", "")
                    .replace("▁", "")
                    .trim();

            if (word.isEmpty()) continue;

            long wordStartTimeMs = toMillis(wordInfo.getStartTime());
            long wordEndTimeMs = toMillis(wordInfo.getEndTime());
            long pauseMs = (lastWordEndTimeMs >= 0) ? (wordStartTimeMs - lastWordEndTimeMs) : 0;

            int wordSpeakerTag = wordInfo.getSpeakerTag() > 0 ? wordInfo.getSpeakerTag() : 1;

            if (currentSpeakerTag == -1) {
                currentSpeakerTag = isDiarizationCollapsed ? fallbackSpeaker : wordSpeakerTag;
                startTime = formatTime(wordInfo.getStartTime().getSeconds());
            }

            // 2: 문장 및 화자 분리 조건
            boolean isSpeakerChanged = (!isDiarizationCollapsed && currentSpeakerTag != wordSpeakerTag);
            boolean isLongPause = (pauseMs >= 650); // 0.65초 이상 침묵 시 분리
            // 대답/전환어("네", "아", "예", "우선", "여보세요")가 나오면서 잠깐(0.25초) 쉬었을 때 분리
            boolean isTurnTakingCue = (currentSentence.length() >= 8 && pauseMs >= 250
                    && word.matches("^(네|아|예|혹시|그|저|여보세요).*"));
            boolean isLengthLimit = (currentSentence.length() >= 45);

            if (isSpeakerChanged || isLongPause || isTurnTakingCue || isLengthLimit) {
                if (currentSentence.length() > 0) {
                    transcripts.add(createTranscript(callRecord, currentSpeakerTag, startTime, currentSentence.toString().trim(), orderIndex));
                    orderIndex += 1000;
                    currentSentence.setLength(0);

                    // STT 화자 분리가 1명으로 뭉개진 상태 && 침묵이나 대답으로
                    // 말풍선이 분리됐을 시 화자 1 <-> 화자 2를 교대
                    if (isDiarizationCollapsed && (isLongPause || isTurnTakingCue)) {
                        fallbackSpeaker = (fallbackSpeaker == 1) ? 2 : 1;
                    }
                }
                currentSpeakerTag = isDiarizationCollapsed ? fallbackSpeaker : wordSpeakerTag;
                startTime = formatTime(wordInfo.getStartTime().getSeconds());
                prevEndedWithConnector = false;
            }

            // 3: '_'가 있던 자리만 공백 없이 당겨붙이기
            if (currentSentence.length() > 0) {
                if (!startsWithUnderscore && !prevEndedWithConnector) {
                    currentSentence.append(" ");
                }
            }
            currentSentence.append(word);
            prevEndedWithConnector = endsWithUnderscore;
            lastWordEndTimeMs = wordEndTimeMs;

            // 구두점(. ? !)으로 끝나면 즉시 말풍선 분리
            if (word.matches(".*[.?!]$")) {
                transcripts.add(createTranscript(callRecord, currentSpeakerTag, startTime, currentSentence.toString().trim(), orderIndex));
                orderIndex += 1000;
                currentSentence.setLength(0);
                currentSpeakerTag = -1;
                lastWordEndTimeMs = wordEndTimeMs; // 다음 문장과의 침묵 계산을 위해 시간 유지
                prevEndedWithConnector = false;

                if (isDiarizationCollapsed) {
                    fallbackSpeaker = (fallbackSpeaker == 1) ? 2 : 1;
                }
            }
        }

        // 마지막 남은 텍스트 저장
        if (currentSentence.length() > 0) {
            transcripts.add(createTranscript(callRecord, currentSpeakerTag, startTime, currentSentence.toString().trim(), orderIndex));
        }

        return transcripts;
    }

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