package com.callPing.callPing_API.dto.request.guide;

import jakarta.validation.constraints.NotBlank;

/**
 * 통화 가이드 세션 생성 요청 (첫 질문).
 * - POST /guides
 */
public record GuideRequestDTO(

        String category,

        @NotBlank(message = "통화 상황을 입력해주세요.")
        String description
) {}
