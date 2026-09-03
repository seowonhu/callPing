package com.callPing.callPing_API.repository.chat;

import com.callPing.callPing_API.domain.chat.ChatRoom;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface ChatRoomRepository extends JpaRepository<ChatRoom, Long> {

    List<ChatRoom> findAllByUserIdOrderByCreatedAtDesc(Long userId);

    @Modifying
    @Query("DELETE FROM ChatRoom r WHERE r.userId = :userId AND r.roomId NOT IN " +
            "(SELECT DISTINCT h.roomId FROM ChatHistory h)")
    void deleteEmptyRoomsByUserId(@Param("userId") Long userId);
}