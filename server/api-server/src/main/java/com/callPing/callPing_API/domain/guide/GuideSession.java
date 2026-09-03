package com.callPing.callPing_API.domain.guide;

import jakarta.persistence.*;
import lombok.*;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "guide_sessions")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class GuideSession {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long userId; // 회원 매핑

    private String category;

    private String title;

    private OffsetDateTime createdAt;

    // 방 하나가 삭제되면 달린 메시지도 다 날아가도록 설정
    @OneToMany(mappedBy = "guideSession", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<GuideMessage> messages = new ArrayList<>();

    @Builder
    public GuideSession(Long userId, String category, String title) {
        this.userId = userId;
        this.category = category;
        this.title = title;
        this.createdAt = OffsetDateTime.now();
    }
}