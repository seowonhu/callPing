package com.callPing.callPing_API.service.call;

import com.callPing.callPing_API.domain.call.CallRecord;
import com.callPing.callPing_API.domain.call.CallTranscript;
import com.google.cloud.speech.v1.*;
import com.google.api.gax.longrunning.OperationFuture;
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

        StringBuilder currentSentence = new StringBuilder();
        int currentSpeakerTag = -1;
        String startTime = "00:00";
        long lastWordEndTime = 1;

        int orderIndex = 1000;

        for (WordInfo wordInfo : alternative.getWordsList()) {
            int wordSpeakerTag = wordInfo.getSpeakerTag();

            // 기호 제거 (언더바, 유니코드, 깍두기 기호 ▁ 모두 직접 치환)
            String word = wordInfo.getWord()
                    .replace("_", "")
                    .replace("\u2581", "")
                    .replace("▁", "")
                    .trim();

            if (word.isEmpty()) continue;

            long wordStartTime = wordInfo.getStartTime().getSeconds();

            if (currentSpeakerTag == -1) {
                currentSpeakerTag = wordSpeakerTag;
                startTime = formatTime(wordStartTime);
            }

            // 2. 문장 끊는 조건 3개
            boolean isSpeakerChanged = (currentSpeakerTag != wordSpeakerTag);
            boolean isLongPause = (lastWordEndTime > 0 && (wordStartTime - lastWordEndTime) >= 2); // 2초 이상 침묵
            boolean isPunctuation = word.matches(".*[.?!]$");

            // 화자가 바뀌었거나, 2초 이상 말이 없었을 때 강제 분리 ...
            if (isSpeakerChanged || isLongPause) {
                if (currentSentence.length() > 0) {
                    transcripts.add(createTranscript(callRecord, currentSpeakerTag, startTime, currentSentence.toString().trim(), orderIndex));
                    orderIndex += 1000;
                    currentSentence.setLength(0);
                }
                currentSpeakerTag = wordSpeakerTag;
                startTime = formatTime(wordStartTime);
            }

            currentSentence.append(word).append(" ");
            lastWordEndTime = wordInfo.getEndTime().getSeconds();

            // 구두점으로 끝났다면 저장하고 초기화
            if (isPunctuation) {
                transcripts.add(createTranscript(callRecord, currentSpeakerTag, startTime, currentSentence.toString().trim(), orderIndex));
                orderIndex += 1000;
                currentSentence.setLength(0);
                currentSpeakerTag = -1;
                lastWordEndTime = 0;
            }
        }

        // 마지막 남은 텍스트 저장
        if (currentSentence.length() > 0) {
            transcripts.add(createTranscript(callRecord, currentSpeakerTag, startTime, currentSentence.toString().trim(), orderIndex));
        }

        return transcripts;
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
