package com.callPing.callPing_API.service.call;

import java.util.List;

public interface AiFeedbackService {
    // 구글 STT가 쪼개준 문장 리스트를 AI 서버에 보내고 피드백을 받아오는 메서드
    String getAiFeedback(List<String> sentences);
}