package com.callPing.callPing_API.service.call;

import com.callPing.callPing_API.domain.call.CallRecord;
import com.callPing.callPing_API.domain.call.CallTranscript;
import java.util.List;

public interface GoogleSttService {
    // GCS에 업로드된 파일 URI를 받아 분석
    List<CallTranscript> transcribeAudio(String gcsUri, CallRecord callRecord) throws Exception;
}