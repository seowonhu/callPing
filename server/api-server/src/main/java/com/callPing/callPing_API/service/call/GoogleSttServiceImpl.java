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

            // 1. 화자 분리 설정 (1:1 통화 최적화)
            SpeakerDiarizationConfig diarizationConfig = SpeakerDiarizationConfig.newBuilder()
                    .setEnableSpeakerDiarization(true)
                    .setMinSpeakerCount(2)
                    .setMaxSpeakerCount(2)
                    .build();

            // 전화 통화 인식률 최대화 => 최신 장문 모델(latest_long) 및 전화 오디오 클래스 적용
            RecognitionConfig config = RecognitionConfig.newBuilder()
                    .setLanguageCode("ko-KR")
                    .setModel("latest_long")
                    .setAudioChannelCount(1)
                    .setEnableAutomaticPunctuation(true)
                    .setEnableWordTimeOffsets(true)
                    .setDiarizationConfig(diarizationConfig)
                    .build();

            RecognitionAudio audio = RecognitionAudio.newBuilder()
                    .setUri(gcsUri)
                    .build();

            OperationFuture<LongRunningRecognizeResponse, LongRunningRecognizeMetadata> response =
                    speechClient.longRunningRecognizeAsync(config, audio);

            LongRunningRecognizeResponse longRunningResponse = response.get();

            return groupWordsIntoSentences(longRunningResponse, callRecord);
        }
    }

    private List<CallTranscript> groupWordsIntoSentences(LongRunningRecognizeResponse response, CallRecord callRecord) {
        List<CallTranscript> transcripts = new ArrayList<>();

        if (response.getResultsList().isEmpty()) return transcripts;

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
        int fallbackSpeaker = 1;

        for (WordInfo wordInfo : alternative.getWordsList()) {
            String rawWord = wordInfo.getWord().trim();
            if (rawWord.isEmpty()) continue;

            boolean startsWithUnderscore = rawWord.startsWith("_") || rawWord.startsWith("▁") || rawWord.startsWith("\u2581");
            boolean endsWithUnderscore = rawWord.endsWith("_") || rawWord.endsWith("▁") || rawWord.endsWith("\u2581");

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

            boolean isSpeakerChanged = (!isDiarizationCollapsed && currentSpeakerTag != wordSpeakerTag);
            boolean isLongPause = (pauseMs >= 700);
            boolean isTurnTakingCue = (currentSentence.length() >= 8 && pauseMs >= 300
                    && word.matches("^(네|아|예|그|저|여보세요).*"));
            boolean isLengthLimit = (currentSentence.length() >= 50);

            if (isSpeakerChanged || isLongPause || isTurnTakingCue || isLengthLimit) {
                if (currentSentence.length() > 0) {
                    transcripts.add(createTranscript(callRecord, currentSpeakerTag, startTime, currentSentence.toString().trim(), orderIndex));
                    orderIndex += 1000;
                    currentSentence.setLength(0);

                    if (isDiarizationCollapsed && (isLongPause || isTurnTakingCue)) {
                        fallbackSpeaker = (fallbackSpeaker == 1) ? 2 : 1;
                    }
                }
                currentSpeakerTag = isDiarizationCollapsed ? fallbackSpeaker : wordSpeakerTag;
                startTime = formatTime(wordInfo.getStartTime().getSeconds());
                prevEndedWithConnector = false;
            }

            if (currentSentence.length() > 0) {
                if (!startsWithUnderscore && !prevEndedWithConnector) {
                    currentSentence.append(" ");
                }
            }
            currentSentence.append(word);
            prevEndedWithConnector = endsWithUnderscore;
            lastWordEndTimeMs = wordEndTimeMs;

            if (word.matches(".*[.?!]$")) {
                transcripts.add(createTranscript(callRecord, currentSpeakerTag, startTime, currentSentence.toString().trim(), orderIndex));
                orderIndex += 1000;
                currentSentence.setLength(0);
                currentSpeakerTag = -1;
                lastWordEndTimeMs = wordEndTimeMs;
                prevEndedWithConnector = false;

                if (isDiarizationCollapsed) {
                    fallbackSpeaker = (fallbackSpeaker == 1) ? 2 : 1;
                }
            }
        }

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