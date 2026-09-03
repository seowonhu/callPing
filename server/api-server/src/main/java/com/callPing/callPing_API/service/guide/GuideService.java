package com.callPing.callPing_API.service.guide;

import com.callPing.callPing_API.dto.request.guide.*;
import com.callPing.callPing_API.dto.response.guide.*;
import java.util.List;

public interface GuideService {
    GuideResponseDTO createGuide(Long userId, GuideRequestDTO request);
    GuideMessageResponseDTO addMessage(Long userId, Long guideId, GuideMessageRequestDTO request);
    List<GuideListResponseDTO> getGuides(Long userId);
    List<GuideMessageHistoryResponseDTO> getMessages(Long userId, Long guideId);
}