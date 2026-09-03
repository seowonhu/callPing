package com.callPing.callPing_API.controller.chat;

import com.callPing.callPing_API.dto.request.chat.ChatRequestDTO;
import com.callPing.callPing_API.dto.request.chat.ChatStopRequestDTO;
import com.callPing.callPing_API.dto.response.chat.*;
import com.callPing.callPing_API.dto.common.ApiCode;
import com.callPing.callPing_API.security.UserPrincipal;
import com.callPing.callPing_API.service.chat.ChatService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.HttpStatus;
import java.util.List;

@RestController
@RequestMapping("/chats")
@RequiredArgsConstructor

public class ChatController {

    private final ChatService chatService;

    /** 새 채팅방 생성 */
    @ApiCode(code = "CHAT_ROOM_CREATED", message = "새로운 채팅방이 성공적으로 생성되었습니다.")
    @PostMapping("/rooms")
    public ResponseEntity<ChatRoomResponseDTO> createRoom(
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(chatService.createRoom(userDetails.getUserId()));
    }

    /** 과거 채팅방 목록 조회 */
    @ApiCode(code = "CHAT_ROOM_LIST_FETCHED", message = "과거 채팅방 목록 조회가 완료되었습니다.")
    @GetMapping("/rooms")
    public ResponseEntity<List<ChatRoomResponseDTO>> getRooms(
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        return ResponseEntity.ok(chatService.getRooms(userDetails.getUserId()));
    }

    /** 특정 채팅방의 질문/답변 타임라인 조회 */
    @ApiCode(code = "CHAT_ROOM_DETAIL_FETCHED", message = "채팅방 상세 대화 내역 조회가 완료되었습니다.")
    @GetMapping("/rooms/{roomId}")
    public ResponseEntity<List<ChatRoomDetailResponseDTO>> getRoomDetail(
            @PathVariable Long roomId,
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        return ResponseEntity.ok(chatService.getRoomDetail(roomId, userDetails.getUserId()));
    }

    /** RAG 챗봇 질문 요청 → Python 서버 호출 */
    @ApiCode(code = "CHAT_ANSWER_SUCCESS", message = "LLM 답변 생성이 완료되었습니다.")
    @PostMapping
    public ResponseEntity<ChatResponseDTO> askQuestion(
            @Valid @RequestBody ChatRequestDTO request,
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        return ResponseEntity.ok(chatService.askQuestion(request, userDetails.getUserId()));
    }

    /** AI 답변 생성 중단 */
    @ApiCode(code = "CHAT_GENERATION_STOPPED", message = "AI 답변 생성이 중단되었습니다.")
    @PostMapping("/rooms/{roomId}/stop")
    public ResponseEntity<Void> stopGeneration(
            @PathVariable Long roomId,
            @Valid @RequestBody ChatStopRequestDTO request,
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        chatService.stopGeneration(roomId, request, userDetails.getUserId());
        return ResponseEntity.ok().build();
    }

    /** 질문/답변 삭제 (남은 채팅이 없으면 방도 함께 삭제) */
    @ApiCode(code = "CHAT_DELETE_SUCCESS", message = "채팅이 삭제되었습니다.")
    @DeleteMapping("/{chatId}")
    public ResponseEntity<ChatDeleteResponseDTO> deleteChat(
            @PathVariable Long chatId,
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        return ResponseEntity.ok(chatService.deleteChat(chatId, userDetails.getUserId()));
    }

    /** 채팅방 전체 삭제 (방 안의 모든 질문/답변 포함) */
    @ApiCode(code = "CHAT_ROOM_DELETE_SUCCESS", message = "채팅방이 삭제되었습니다.")
    @DeleteMapping("/rooms/{roomId}")
    public ResponseEntity<ChatRoomDeleteResponseDTO> deleteRoom(
            @PathVariable Long roomId,
            @AuthenticationPrincipal UserPrincipal userDetails
    ) {
        return ResponseEntity.ok(chatService.deleteRoom(roomId, userDetails.getUserId()));
    }
}