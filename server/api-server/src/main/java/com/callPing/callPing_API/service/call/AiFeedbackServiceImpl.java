package com.callPing.callPing_API.service.call;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
public class AiFeedbackServiceImpl implements AiFeedbackService {

    private final RestTemplate restTemplate;

    public AiFeedbackServiceImpl() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(60000);
        factory.setReadTimeout(60000);

        this.restTemplate = new RestTemplate(factory);
    }

    @Override
    public String getAiFeedback(List<String> sentences) {
        //1. 엔드포인트
        String aiServerUrl = "http://localhost:18020/lora/feedback";

        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);

            // 2. STT 문장 데이터를 요구되는 형태로 변환 [{"speaker":"1", "text":"..."}]
            List<Map<String, String>> transcriptList = new ArrayList<>();
            for (String sentence : sentences) {
                Map<String, String> transcriptItem = new HashMap<>();
                transcriptItem.put("speaker", "1"); // TODO: 화자 구분 로직 확인
                transcriptItem.put("text", sentence);
                transcriptList.add(transcriptItem);
            }

            Map<String, Object> requestBody = new HashMap<>();
            requestBody.put("transcript", transcriptList);

            HttpEntity<Map<String, Object>> requestEntity = new HttpEntity<>(requestBody, headers);

            log.info("LoRA AI 서버로 피드백 요청 전송 시작... 최대 60초 대기");

            ResponseEntity<String> response = restTemplate.postForEntity(
                    aiServerUrl,
                    requestEntity,
                    String.class
            );

            log.info("LoRA AI 서버 분석 완료 응답 수신");

            return response.getBody();

        } catch (Exception e) {
            log.error("LoRA AI 서버 통신 중 오류 발생: ", e);
            return "AI 분석 중 오류가 발생했습니다.\nAI 서버 연결 상태를 확인해 주세요.";
        }
    }
}