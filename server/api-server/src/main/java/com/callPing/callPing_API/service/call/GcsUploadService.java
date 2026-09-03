package com.callPing.callPing_API.service.call;

import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;

public interface GcsUploadService {
    String uploadAudioFile(MultipartFile file) throws IOException;
}