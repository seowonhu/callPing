package com.callPing.callPing_API.repository.call;

import com.callPing.callPing_API.domain.call.CallRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface CallRecordRepository extends JpaRepository<CallRecord, Long> {
    // 사용자의 전체 녹음 목록 조회 (최신순)
    List<CallRecord> findAllByUserIdOrderByUploadTimeDesc(Long userId);
}