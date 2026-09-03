package com.callPing.callPing_API.domain.guide;

import jakarta.persistence.*;
import lombok.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "guide_messages")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class GuideMessage {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "guide_session_id")
    private GuideSession guideSession;

    @Column(columnDefinition = "TEXT")
    private String question;

    @Column(columnDefinition = "TEXT")
    private String answer;

    @Column(columnDefinition = "TEXT")
    private String tips;

    private OffsetDateTime createdAt;

    @Builder
    public GuideMessage(GuideSession guideSession, String question, String answer, String tips) {
        this.guideSession = guideSession;
        this.question = question;
        this.answer = answer;
        this.tips = tips;
        this.createdAt = OffsetDateTime.now();
    }
}