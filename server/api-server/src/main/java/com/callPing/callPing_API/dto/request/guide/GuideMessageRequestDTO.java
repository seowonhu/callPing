package com.callPing.callPing_API.dto.request.guide;

import jakarta.validation.constraints.NotBlank;

/**
 * 이미 생성된 가이드 세션에 이어서 보내는 추가 질문(재요청).
 * - POST /guides/{guide_id}/messages
 */
public record GuideMessageRequestDTO(

        @NotBlank(message = "질문 내용은 필수입니다.")
        String question
) {}
