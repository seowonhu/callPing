package com.callPing.callPing_API.controller.guide;

import com.callPing.callPing_API.dto.request.guide.*;
import com.callPing.callPing_API.dto.response.guide.*;
import com.callPing.callPing_API.dto.common.ApiCode;
import com.callPing.callPing_API.security.UserPrincipal;
import com.callPing.callPing_API.service.guide.GuideService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/guides")
@RequiredArgsConstructor
public class GuideController {

    private final GuideService guideService;

    @ApiCode(code = "GUIDE_CREATED", message = "통화 가이드가 생성되었습니다.")
    @PostMapping
    public ResponseEntity<GuideResponseDTO> createGuide(
            @Valid @RequestBody GuideRequestDTO request,
            @AuthenticationPrincipal UserPrincipal userDetails) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(guideService.createGuide(userDetails.getUserId(), request));
    }

    @ApiCode(code = "GUIDE_MESSAGE_CREATED", message = "답변이 생성되었습니다.")
    @PostMapping("/{guideId}/messages")
    public ResponseEntity<GuideMessageResponseDTO> addMessage(
            @PathVariable Long guideId,
            @Valid @RequestBody GuideMessageRequestDTO request,
            @AuthenticationPrincipal UserPrincipal userDetails) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(guideService.addMessage(userDetails.getUserId(), guideId, request));
    }

    @ApiCode(code = "GUIDE_LIST_FETCHED", message = "가이드 목록 조회가 완료되었습니다.")
    @GetMapping
    public ResponseEntity<List<GuideListResponseDTO>> getGuides(
            @AuthenticationPrincipal UserPrincipal userDetails) {
        return ResponseEntity.ok(guideService.getGuides(userDetails.getUserId()));
    }

    @ApiCode(code = "GUIDE_MESSAGES_FETCHED", message = "가이드 대화 내역 조회가 완료되었습니다.")
    @GetMapping("/{guideId}/messages")
    public ResponseEntity<List<GuideMessageHistoryResponseDTO>> getMessages(
            @PathVariable Long guideId,
            @AuthenticationPrincipal UserPrincipal userDetails) {
        return ResponseEntity.ok(guideService.getMessages(userDetails.getUserId(), guideId));
    }
}