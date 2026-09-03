package com.callPing.callPing_API.controller;

import com.callPing.callPing_API.dto.common.ApiResponse;
import com.callPing.callPing_API.dto.request.user.*;
import com.callPing.callPing_API.dto.response.user.*;
import com.callPing.callPing_API.security.UserPrincipal;
import com.callPing.callPing_API.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import com.callPing.callPing_API.security.UserPrincipal;

@RestController
@RequestMapping("/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    // =================================================================================
    // #1. 회원가입 프로세스
    // =================================================================================

    @PostMapping("/email-verification")
    public ResponseEntity<ApiResponse<Void>> sendSignUpEmail(
            @Valid @RequestBody EmailVerificationRequestDTO requestDTO,
            HttpServletRequest request) {

        userService.sendSignUpEmailVerification(requestDTO);
        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_SIGNUP_CODE_SENT", "입력하신 이메일로 인증 코드가 발송되었습니다.", request.getRequestURI(), null
        ));
    }

    @PostMapping("/email-verification/check")
    public ResponseEntity<ApiResponse<Void>> verifySignUpEmail(
            @Valid @RequestBody EmailVerificationCheckRequestDTO requestDTO,
            HttpServletRequest request) {

        userService.checkEmailVerification(requestDTO);
        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_SIGNUP_CODE_VERIFIED", "이메일 인증이 완료되었습니다.", request.getRequestURI(), null
        ));
    }

    @PostMapping("/check-id")
    public ResponseEntity<ApiResponse<Void>> checkLoginId(
            @Valid @RequestBody CheckIdRequestDTO requestDTO,
            HttpServletRequest request) {

        boolean isAvailable = userService.checkLoginIdAvailable(requestDTO.loginId());

        if (!isAvailable) {
            throw new IllegalArgumentException("이미 사용 중인 아이디입니다.");
        }

        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_ID_AVAILABLE", "사용 가능한 아이디입니다.", request.getRequestURI(), null
        ));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<SignUpResponseDTO>> signUp(
            @Valid @RequestBody SignUpRequestDTO requestDTO,
            HttpServletRequest request) {

        SignUpResponseDTO responseData = userService.signUp(requestDTO);
        return ResponseEntity.status(201).body(ApiResponse.success(
                201, "USER_SIGNUP_SUCCESS", "회원가입이 성공적으로 완료되었습니다.", request.getRequestURI(), responseData
        ));
    }

    // =================================================================================
    // #2. 아이디 찾기 프로세스
    // =================================================================================

    @PostMapping("/find-id/email-verification")
    public ResponseEntity<ApiResponse<Void>> sendFindIdEmail(
            @Valid @RequestBody EmailVerificationRequestDTO requestDTO,
            HttpServletRequest request) {

        userService.sendFindEmailVerification(requestDTO);
        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_FINDID_CODE_SENT", "입력하신 이메일로 인증 코드가 발송되었습니다.", request.getRequestURI(), null
        ));
    }

    @PostMapping("/find-id/email-verification/check")
    public ResponseEntity<ApiResponse<Void>> verifyFindIdEmail(
            @Valid @RequestBody EmailVerificationCheckRequestDTO requestDTO,
            HttpServletRequest request) {

        userService.checkEmailVerification(requestDTO);
        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_FINDID_CODE_VERIFIED", "이메일 인증이 완료되었습니다.", request.getRequestURI(), null
        ));
    }

    @PostMapping("/find-id")
    public ResponseEntity<ApiResponse<FindIdResponseDTO>> findId(
            @Valid @RequestBody FindIdRequestDTO requestDTO,
            HttpServletRequest request) {

        FindIdResponseDTO responseData = userService.findId(requestDTO);
        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_ID_FOUND", "아이디 찾기에 성공했습니다.", request.getRequestURI(), responseData
        ));
    }

    // =================================================================================
    // #3. 비밀번호 재설정 프로세스
    // =================================================================================

    @PostMapping("/password-reset/email-verification")
    public ResponseEntity<ApiResponse<Void>> sendResetPasswordEmail(
            @Valid @RequestBody EmailVerificationRequestDTO requestDTO,
            HttpServletRequest request) {

        userService.sendPasswordResetEmailVerification(requestDTO);
        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_RESETPW_CODE_SENT", "입력하신 이메일로 인증 코드가 발송되었습니다.", request.getRequestURI(), null
        ));
    }

    @PostMapping("/password-reset/email-verification/check")
    public ResponseEntity<ApiResponse<Void>> verifyResetPasswordEmail(
            @Valid @RequestBody EmailVerificationCheckRequestDTO requestDTO,
            HttpServletRequest request) {

        userService.checkEmailVerification(requestDTO);
        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_RESETPW_CODE_VERIFIED", "이메일 인증이 완료되었습니다.", request.getRequestURI(), null
        ));
    }

    @PatchMapping("/password-reset")
    public ResponseEntity<ApiResponse<Void>> resetPassword(
            @Valid @RequestBody PasswordResetRequestDTO requestDTO,
            HttpServletRequest request) {

        userService.resetPassword(requestDTO);
        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_PASSWORD_RESET_SUCCESS", "비밀번호가 성공적으로 변경되었습니다.", request.getRequestURI(), null
        ));
    }

    // =================================================================================
    // #4. 로그인 된 사용자 계정/권한 관리 (/me) - Security 연동 완료
    // =================================================================================

    @GetMapping("/me")
    public ResponseEntity<ApiResponse<UserProfileResponseDTO>> getMyProfile(
            @AuthenticationPrincipal UserPrincipal userDetails,
            HttpServletRequest request) {

        // 로그인된 유저의 ID를 userDetails 객체에서 추출하여 서비스로 전달합니다.
        UserProfileResponseDTO responseData = userService.getMyProfile(userDetails.getUserId());
        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_PROFILE_FETCHED", "회원 정보 조회가 완료되었습니다.", request.getRequestURI(), responseData
        ));
    }

    @PatchMapping("/me/account/password")
    public ResponseEntity<ApiResponse<Void>> updatePassword(
            @AuthenticationPrincipal UserPrincipal userDetails,
            @Valid @RequestBody PasswordChangeRequestDTO requestDTO,
            HttpServletRequest request) {

        userService.updatePassword(userDetails.getUserId(), requestDTO);
        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_PASSWORD_CHANGED", "비밀번호가 안전하게 변경되었습니다.", request.getRequestURI(), null
        ));
    }

    @PostMapping("/me/account/email/verification")
    public ResponseEntity<ApiResponse<Void>> sendEmailChangeVerification(
            @AuthenticationPrincipal UserPrincipal userDetails,
            @Valid @RequestBody EmailChangeVerificationRequestDTO requestDTO,
            HttpServletRequest request) {

        userService.sendEmailChangeVerification(userDetails.getUserId(), requestDTO);
        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_EMAIL_CHANGE_CODE_SENT", "새 이메일 주소로 인증 코드가 발송되었습니다.", request.getRequestURI(), null
        ));
    }

    @PatchMapping("/me/account/email/verification/check")
    public ResponseEntity<ApiResponse<Void>> verifyAndChangeEmail(
            @AuthenticationPrincipal UserPrincipal userDetails,
            @Valid @RequestBody EmailChangeVerificationCheckRequestDTO requestDTO,
            HttpServletRequest request) {

        userService.verifyAndChangeEmail(userDetails.getUserId(), requestDTO);
        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_EMAIL_CHANGED", "이메일이 성공적으로 변경되었습니다.", request.getRequestURI(), null
        ));
    }

    @DeleteMapping("/me/account")
    public ResponseEntity<ApiResponse<Void>> deleteAccount(
            @AuthenticationPrincipal UserPrincipal userDetails,
            HttpServletRequest request) {

        userService.deleteAccount(userDetails.getUserId());
        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_ACCOUNT_DELETED", "회원 탈퇴가 정상적으로 처리되었습니다.", request.getRequestURI(), null
        ));
    }

    @GetMapping("/me/permissions")
    public ResponseEntity<ApiResponse<PermissionsResponseDTO>> getPermissions(
            @AuthenticationPrincipal UserPrincipal userDetails,
            HttpServletRequest request) {

        PermissionsResponseDTO responseData = userService.getPermissions(userDetails.getUserId());
        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_PERMISSIONS_FETCHED", "사용자 권한 설정 조회가 완료되었습니다.", request.getRequestURI(), responseData
        ));
    }

    @PatchMapping("/me/permissions")
    public ResponseEntity<ApiResponse<Void>> updatePermissions(
            @AuthenticationPrincipal UserPrincipal userDetails,
            @Valid @RequestBody PermissionsUpdateRequestDTO requestDTO,
            HttpServletRequest request) {

        userService.updatePermissions(userDetails.getUserId(), requestDTO);
        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_PERMISSIONS_UPDATED", "권한 설정이 변경되었습니다.", request.getRequestURI(), null
        ));
    }

    // =================================================================================
    // #5. 계정 잠금 해제 프로세스
    // =================================================================================

    @PostMapping("/account-unlock/email-verification")
    public ResponseEntity<ApiResponse<Void>> sendUnlockEmail(
            @Valid @RequestBody EmailVerificationRequestDTO requestDTO,
            HttpServletRequest request) {

        userService.sendUnlockEmailVerification(requestDTO);
        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_UNLOCK_CODE_SENT", "입력하신 이메일로 잠금 해제용 인증 코드가 발송되었습니다.", request.getRequestURI(), null
        ));
    }

    @PostMapping("/account-unlock/email-verification/check")
    public ResponseEntity<ApiResponse<Void>> verifyUnlockEmail(
            @Valid @RequestBody EmailVerificationCheckRequestDTO requestDTO,
            HttpServletRequest request) {

        userService.checkEmailVerification(requestDTO);
        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_UNLOCK_CODE_VERIFIED", "이메일 인증이 완료되었습니다.", request.getRequestURI(), null
        ));
    }

    @PatchMapping("/account-unlock")
    public ResponseEntity<ApiResponse<Void>> unlockAccount(
            @Valid @RequestBody AccountUnlockRequestDTO requestDTO,
            HttpServletRequest request) {

        userService.unlockAccount(requestDTO);
        return ResponseEntity.ok(ApiResponse.success(
                200, "USER_ACCOUNT_UNLOCKED", "계정 잠금이 성공적으로 해제되었습니다.", request.getRequestURI(), null
        ));
    }

}