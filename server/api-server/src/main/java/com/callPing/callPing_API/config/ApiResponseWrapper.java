package com.callPing.callPing_API.config;

import com.callPing.callPing_API.dto.common.ApiCode;
import com.callPing.callPing_API.dto.common.ApiResponse;
import org.springframework.core.MethodParameter;
import org.springframework.http.MediaType;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.http.server.ServletServerHttpResponse;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.mvc.method.annotation.ResponseBodyAdvice;

@RestControllerAdvice
public class ApiResponseWrapper implements ResponseBodyAdvice<Object> {

    @Override
    public boolean supports(MethodParameter returnType, Class converterType) {
        return true; // 실제 감쌀지 여부는 beforeBodyWrite에서 body를 보고 판단
    }

    @Override
    public Object beforeBodyWrite(Object body, MethodParameter returnType,
                                  MediaType selectedContentType,
                                  Class selectedConverterType,
                                  ServerHttpRequest request,
                                  ServerHttpResponse response) {

        // 이미 ApiResponse로 감싸진 경우(GlobalExceptionHandler가 처리한 경우) 그대로 반환
        if (body instanceof ApiResponse) {
            return body;
        }

        int status = ((ServletServerHttpResponse) response).getServletResponse().getStatus();

        ApiCode apiCode = returnType.getMethodAnnotation(ApiCode.class);
        String code = apiCode != null ? apiCode.code() : "SUCCESS";
        String message = apiCode != null ? apiCode.message() : "요청이 성공적으로 처리되었습니다.";

        return ApiResponse.success(status, code, message, request.getURI().getPath(), body);
    }
}