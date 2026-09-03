package com.callPing.callPing_API.service.chat;

import com.callPing.callPing_API.dto.request.chat.ChatRequestDTO;
import com.callPing.callPing_API.dto.request.chat.ChatStopRequestDTO;
import com.callPing.callPing_API.dto.response.chat.*;

import java.util.List;

public interface ChatService {
    ChatRoomResponseDTO createRoom(Long currentUserId);
    List<ChatRoomResponseDTO> getRooms(Long currentUserId);
    List<ChatRoomDetailResponseDTO> getRoomDetail(Long roomId, Long currentUserId);
    ChatResponseDTO askQuestion(ChatRequestDTO request, Long currentUserId);
    void stopGeneration(Long roomId, ChatStopRequestDTO request, Long currentUserId);
    ChatDeleteResponseDTO deleteChat(Long chatId, Long currentUserId);
    ChatRoomDeleteResponseDTO deleteRoom(Long roomId, Long currentUserId);
}