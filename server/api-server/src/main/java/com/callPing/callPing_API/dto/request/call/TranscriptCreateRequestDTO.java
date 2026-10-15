package com.callPing.callPing_API.dto.request.call;

import com.fasterxml.jackson.annotation.JsonAlias;
import jakarta.validation.constraints.NotBlank;

public record TranscriptCreateRequestDTO(
        @NotBlank(message = "화자 이름은 필수입니다.") String speaker,
        @NotBlank(message = "대화 내용은 필수입니다.") String text,
        @JsonAlias({"timestamp_offset", "timestampOffset"}) String timestampOffset,
        @JsonAlias({"order_index", "orderIndex"}) Integer orderIndex
) {}