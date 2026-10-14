package com.callPing.callPing_API.dto.request.call;

import jakarta.validation.constraints.NotBlank;

public record TranscriptCreateRequestDTO(
        @NotBlank(message = "화자 이름은 필수입니다.") String speaker,
        @NotBlank(message = "대화 내용은 필수입니다.") String text,
        String timestampOffset,
        Integer orderIndex // 끼워 넣을 위치의 인덱스
) {}