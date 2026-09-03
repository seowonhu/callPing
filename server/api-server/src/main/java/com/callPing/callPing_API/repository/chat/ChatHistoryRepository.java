package com.callPing.callPing_API.repository.chat;

import com.callPing.callPing_API.domain.chat.ChatHistory;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ChatHistoryRepository extends JpaRepository<ChatHistory, Long> {
    List<ChatHistory> findAllByRoomIdOrderByCreatedAtAsc(Long roomId);
    long countByRoomId(Long roomId);
    void deleteAllByRoomId(Long roomId);
}
