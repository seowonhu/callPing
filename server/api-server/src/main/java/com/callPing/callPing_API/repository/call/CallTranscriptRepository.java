package com.callPing.callPing_API.repository.call;

import com.callPing.callPing_API.domain.call.CallTranscript;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface CallTranscriptRepository extends JpaRepository<CallTranscript, Long> {
    // transcript는 is_deleted=true인 문장을 제외하고 반환
    List<CallTranscript> findAllByCallRecordIdAndIsDeletedFalseOrderByIdAsc(Long callRecordId);
}