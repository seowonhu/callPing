package com.callPing.callPing_API.controller;

import com.callPing.callPing_API.dto.common.ApiResponse;
import com.callPing.callPing_API.dto.request.session.LoginRequestDTO;
import com.callPing.callPing_API.dto.request.session.LogoutRequestDTO;
import com.callPing.callPing_API.dto.response.session.LoginResponseDTO;
import com.callPing.callPing_API.service.UserService; // 또는 SessionService로 분리
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/sessions")
@RequiredArgsConstructor
public class SessionController {

    private final UserService userService;

    @PostMapping
    public ResponseEntity<ApiResponse<LoginResponseDTO>> login(
            @Valid @RequestBody LoginRequestDTO requestDTO,
            HttpServletRequest request) {

        LoginResponseDTO responseData = userService.login(requestDTO);
        return ResponseEntity.ok(ApiResponse.success(
                200, "SESSION_LOGIN_SUCCESS", "로그인에 성공했습니다.", request.getRequestURI(), responseData
        ));
    }

    @DeleteMapping
    public ResponseEntity<ApiResponse<Void>> logout(
            @Valid @RequestBody LogoutRequestDTO requestDTO,
            HttpServletRequest request) {

        userService.logout(requestDTO);
        return ResponseEntity.ok(ApiResponse.success(
                200, "SESSION_LOGOUT_SUCCESS", "로그아웃되었습니다.", request.getRequestURI(), null
        ));
    }
}