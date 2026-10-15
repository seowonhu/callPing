package com.callPing.callPing_API.dto.response.call;

import java.time.OffsetDateTime;
import java.util.List;

public record CallDetailsResponseDTO(
        Long recordId,
        String callerName,
        String recordTitle,
        OffsetDateTime uploadTime,
        String analysisStatus,
        List<TranscriptSegmentDTO> transcripts
) {}