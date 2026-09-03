package com.callPing.callPing_API.repository.guide;

import com.callPing.callPing_API.domain.guide.GuideSession;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface GuideSessionRepository extends JpaRepository<GuideSession, Long> {
    // 과거 가이드 목록 최신순 조회용
    List<GuideSession> findAllByUserIdOrderByCreatedAtDesc(Long userId);

    // 남의 가이드방 훔쳐보지 못하게 본인 확인용
    Optional<GuideSession> findByIdAndUserId(Long id, Long userId);
}