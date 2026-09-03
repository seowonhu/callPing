package com.callPing.callPing_API.repository.guide;

import com.callPing.callPing_API.domain.guide.GuideMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface GuideMessageRepository extends JpaRepository<GuideMessage, Long> {
    // 특정 방의 대화 내역 시간순(오래된 순) 조회용
    List<GuideMessage> findAllByGuideSessionIdOrderByCreatedAtAsc(Long guideSessionId);
}