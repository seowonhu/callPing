package com.callPing.callPing_API.domain.call;

import jakarta.persistence.*;
import lombok.*;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Getter
@Setter
@Builder
@AllArgsConstructor
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class CallRecord {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long userId; // User 엔티티와 연관관계 맵핑 필요 (@ManyToOne)
    private String callerName;
    private String fileName;

    // 분석 상태 - 대기중 / 분석중 / 완료 / 실패 등 (Enum)
    private String analysisStatus;

    // AI 분석 결과 필드
    @Column(columnDefinition = "TEXT")
    private String summary;
    private String speakerResult;
    @Column(columnDefinition = "TEXT")
    private String expression;
    @Column(columnDefinition = "TEXT")
    private String feedback;

    private OffsetDateTime uploadTime;

    // 1:N 관계
    @Builder.Default
    @OneToMany(mappedBy = "callRecord", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<CallTranscript> transcripts = new ArrayList<>();
    // 연관관계 편의 메서드 (문장을 리스트에 추가)
    public void addTranscript(CallTranscript transcript) {
        if (this.transcripts == null) {
            this.transcripts = new ArrayList<>(); // null 방어 코드
        }
        this.transcripts.add(transcript);
        transcript.setCallRecord(this);
    }

    // AI 분석 완료 후 결과 업데이트
    public void updateAiAnalysis(String expression, String feedback, String status) {
        this.expression = expression;
        this.feedback = feedback;
        this.analysisStatus = status;
    }

    // 상태만 단독으로 변경 (실패 등)
    public void updateStatus(String status) {
        this.analysisStatus = status;
    }

    // 기존 필드들 아래에 추가
    @Column(length = 200)
    private String keywords;

    // AI 결과 업데이트 메서드 수정
    public void updateAiAnalysis(String expression, String feedback, String summary, String keywords, String status) {
        this.expression = expression;
        this.feedback = feedback;
        this.summary = summary;
        this.keywords = keywords;
        this.analysisStatus = status;
    }
}
