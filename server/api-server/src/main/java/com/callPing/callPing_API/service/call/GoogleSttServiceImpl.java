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

        if (response.getResultsList().isEmpty()) return transcripts;

        // 구글 STT는 화자 분리 결과를 가장 마지막 Result에 몰아서 줌...
        SpeechRecognitionResult lastResult = response.getResults(response.getResultsCount() - 1);
        SpeechRecognitionAlternative alternative = lastResult.getAlternatives(0);

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
            int wordSpeakerTag = wordInfo.getSpeakerTag();
            String rawWord = wordInfo.getWord().trim();

            boolean isWordStart = !hasSubwordMarkers
                    || rawWord.startsWith("▁")
                    || rawWord.startsWith("\u2581")
                    || rawWord.startsWith("_");

            // 기호 제거 (언더바, 유니코드, 깍두기 기호 ▁ 모두 직접 치환)
            String word = rawWord
                    .replace("_", "")
                    .replace("\u2581", "")
                    .replace("▁", "")
                    .trim();

            if (word.isEmpty()) continue;

            long wordStartTimeMs = toMillis(wordInfo.getStartTime());
            long wordEndTimeMS = toMillis(wordInfo.getEndTime());

            if (currentSpeakerTag == -1) {
                currentSpeakerTag = wordSpeakerTag;
                startTime = formatTime(wordInfo.getStartTime().getSeconds());
            }

            // 2. 문장 끊는 조건 3개 => 5개
            boolean isSpeakerChanged = (currentSpeakerTag != wordSpeakerTag);
            long pauseMs = (lastWordEndTimeMs >= 0) ? (wordStartTimeMs - lastWordEndTimeMs) : 0;
            boolean isLongPause = (pauseMs>=800); // 2초 이상 침묵 => .8로 수정
            boolean isMediumPauseOnLongSentence = (currentSentence.length() >= 40 && pauseMs >= 400);

            // 화자 변경 시 말풍선 분리
            if (isSpeakerChanged || (isWordStart && (isLongPause || isMediumPauseOnLongSentence))) {
                if (currentSentence.length() > 0) {
                    transcripts.add(createTranscript(callRecord, currentSpeakerTag,
                            startTime, currentSentence.toString().trim(), orderIndex));
                    orderIndex += 1000;
                    currentSentence.setLength(0);
                }
                currentSpeakerTag = wordSpeakerTag;
                startTime = formatTime(wordInfo.getStartTime().getSeconds());
            }

            if (currentSentence.length() > 0 && isWordStart){
                currentSentence.append("");
            }
            currentSentence.append(word);

            lastWordEndTimeMs = wordEndTimeMS;

            //마침표 || 35자 이상 || 쉼표
            boolean isPunctuation = word.matches(".*[.?!]$");
            boolean isCommaOnLongSentence = (currentSentence.length() >= 35 && word.endsWith(","));

            // 구두점으로 끝났다면 저장하고 초기화
            if (isPunctuation || isCommaOnLongSentence) {
                transcripts.add(createTranscript(callRecord, currentSpeakerTag, startTime, currentSentence.toString().trim(), orderIndex));
                orderIndex += 1000;
                currentSentence.setLength(0);
                currentSpeakerTag = -1;
                lastWordEndTimeMs = 0;
            }
        }

        // 마지막 남은 텍스트 저장
        if (currentSentence.length() > 0) {
            transcripts.add(createTranscript(callRecord, currentSpeakerTag, startTime, currentSentence.toString().trim(), orderIndex));
        }

        return transcripts;
    }

    private long toMillis (Duration duration) {
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
