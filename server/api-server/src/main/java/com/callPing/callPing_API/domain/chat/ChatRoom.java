package com.callPing.callPing_API.domain.chat;

import jakarta.persistence.*;
import lombok.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "chat_room")
@Getter
@Setter
@NoArgsConstructor
public class ChatRoom {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "room_id")
    private Long roomId;

    // User엔티티 완성 시 fk추가(@ManyToOne)
    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "title")
    private String title; // 첫 질문 전까지는 null

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    public void prePersist() {
        this.createdAt = OffsetDateTime.now();
    }
}