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

            // 1. 중간 보고에 맞춘 STT 환경 설정
            SpeakerDiarizationConfig diarizationConfig = SpeakerDiarizationConfig.newBuilder()
                    .setEnableSpeakerDiarization(true)
                    // 화자 수는 지정하지 않음
                    .build();

            RecognitionConfig config = RecognitionConfig.newBuilder()
                    .setLanguageCode("ko-KR")
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

        // 결과가 비어있으면 리턴
        if (response.getResultsList().isEmpty()) return transcripts;

        SpeechRecognitionResult lastResult = response.getResults(response.getResultsCount() - 1);
        SpeechRecognitionAlternative alternative = lastResult.getAlternatives(0);

        StringBuilder currentSentence = new StringBuilder();
        int currentSpeakerTag = -1;
        String startTime = "00:00"; // 첫 단어의 시작 시간

        for (WordInfo wordInfo : alternative.getWordsList()) {
            int wordSpeakerTag = wordInfo.getSpeakerTag();
            String word = wordInfo.getWord();

            // 첫 단어 세팅
            if (currentSpeakerTag == -1) {
                currentSpeakerTag = wordSpeakerTag;
                startTime = formatTime(wordInfo.getStartTime().getSeconds());
            }

            // [문장을 끊는 조건]
            boolean isSpeakerChanged = (currentSpeakerTag != wordSpeakerTag);

            if (isSpeakerChanged) {
                transcripts.add(createTranscript(callRecord, currentSpeakerTag, startTime, currentSentence.toString()));
                currentSentence.setLength(0);
                currentSpeakerTag = wordSpeakerTag;
                startTime = formatTime(wordInfo.getStartTime().getSeconds());
            }

            currentSentence.append(word).append(" ");

            // 구두점으로 끝났다면 저장하고 초기화
            if (word.matches(".*[.?!]$")) {
                transcripts.add(createTranscript(callRecord, currentSpeakerTag, startTime, currentSentence.toString().trim()));
                currentSentence.setLength(0);
                currentSpeakerTag = -1;
            }
        }

        // 마지막에 남은 텍스트가 있다면 저장
        if (currentSentence.length() > 0) {
            transcripts.add(createTranscript(callRecord, currentSpeakerTag, startTime, currentSentence.toString().trim()));
        }

        return transcripts;
    }

    private CallTranscript createTranscript(CallRecord callRecord, int speakerTag, String timestampOffset, String text) {
        return CallTranscript.builder()
                .callRecord(callRecord)
                .speaker("화자 " + speakerTag)
                .timestampOffset(timestampOffset)
                .text(text.trim())
                .build();
    }

    private String formatTime(long totalSeconds) {
        long minutes = totalSeconds / 60;
        long seconds = totalSeconds % 60;
        return String.format("%02d:%02d", minutes, seconds);
    }
}
