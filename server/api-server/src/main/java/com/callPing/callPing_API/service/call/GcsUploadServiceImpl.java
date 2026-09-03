package com.callPing.callPing_API.service.call;

import com.google.cloud.storage.BlobInfo;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.UUID;

@Service
public class GcsUploadServiceImpl implements GcsUploadService {

    @Value("${gcp.storage.bucket-name}")
    private String bucketName;

    @Override
    public String uploadAudioFile(MultipartFile file) throws IOException {
        // 파일 이름이 겹치지 않게 UUID를 붙여서 고유한 이름 생성
        String fileName = UUID.randomUUID() + "_" + file.getOriginalFilename();

        // 구글 스토리지 클라이언트 호출
        Storage storage = StorageOptions.getDefaultInstance().getService();

        // 업로드할 파일의 메타데이터 설정
        BlobInfo blobInfo = BlobInfo.newBuilder(bucketName, fileName)
                .setContentType(file.getContentType())
                .build();

        // GCS로 실제 파일 업로드
        storage.create(blobInfo, file.getBytes());

        // 구글 STT가 요구하는 "gs://" 형태의 URI 반환
        return String.format("gs://%s/%s", bucketName, fileName);
    }
}