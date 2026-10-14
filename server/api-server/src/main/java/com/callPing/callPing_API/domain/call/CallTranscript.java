package com.callPing.callPing_API.domain.call;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Getter
@Setter
@Builder
@AllArgsConstructor
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class CallTranscript {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "call_record_id")
    private CallRecord callRecord;

    private String speaker; // "화자1", "화자2"
    private String timestampOffset; // "00:12"

    @Column(columnDefinition = "TEXT")
    private String text;

    @Column(name = "order_index")
    private Integer orderIndex;

    // 소프트 삭제
    @Column(nullable = false)
    private boolean isDeleted = false;


    // 수정 메서드
    public void updateText(String newText, String newSpeaker, Integer newOrderIndex) {
        if (newText != null && !newText.isBlank()) {
            this.text = newText;
        }
        if (newSpeaker != null && !newSpeaker.isBlank()) {
            this.speaker = newSpeaker;
        }
        if (newOrderIndex != null) {
            this.orderIndex = newOrderIndex; // 드래그로 이동한 새 위치 인덱스 반영
        }
    }

    // 삭제 상태 변경하는 메서드
    public void markAsDeleted() {
        this.isDeleted = true;
    }

    // 텍스트와 화자를 업데이트하는 메서드 추가
    public void updateContent(String text, String speaker) {
        if (text != null && !text.isBlank()) this.text = text;
        if (speaker != null && !speaker.isBlank()) this.speaker = speaker;
    }
}
