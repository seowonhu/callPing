package com.callPing.callPing_API.service;

import com.callPing.callPing_API.dto.request.session.LoginRequestDTO;
import com.callPing.callPing_API.dto.request.session.LogoutRequestDTO;
import com.callPing.callPing_API.dto.request.user.*;
import com.callPing.callPing_API.dto.response.session.LoginResponseDTO;
import com.callPing.callPing_API.dto.response.user.*;
import org.hibernate.annotations.processing.Find;

public interface UserService {

    // [0720 커밋] [POST] 회원가입용 이메일 인증번호 발송
    void sendSignUpEmailVerification(EmailVerificationRequestDTO requestDTO);

    // [0720 커밋] [POST] 이메일 인증번호 검증
    void checkEmailVerification(EmailVerificationCheckRequestDTO requestDTO);

    // [0720 커밋] [POST] 아이디 중복 체크
    boolean checkLoginIdAvailable(String loginId);

    // [POST] 회원가입
    SignUpResponseDTO signUp(SignUpRequestDTO requestDTO);

    // [0720 커밋] [POST] 아이디 찾기용 이메일 인증번호 발송
    void sendFindEmailVerification(EmailVerificationRequestDTO requestDTO);

    // [0720 커밋] [POST] 아이디 찾기
    FindIdResponseDTO findId(FindIdRequestDTO requestDTO);

    // [0720 커밋] [POST] 비밀번호 재설정용 이메일 인증번호 발송
    void sendPasswordResetEmailVerification(EmailVerificationRequestDTO requestDTO);

    // [0720 커밋] [POST] 비밀번호 재설정 (비로그인)
    void resetPassword(PasswordResetRequestDTO requestDTO);

    // [POST] 로그인 (임시로 JWT 토큰 문자열 반환으로 가정)
    LoginResponseDTO login(LoginRequestDTO requestDTO);

    // [0720] [DELETE] 로그아웃
    void logout(LogoutRequestDTO requestDTO);

    // [GET] 내 프로필 정보 조회
    UserProfileResponseDTO getMyProfile(Long userId);

    // [PATCH] 로그인 상태에서 비밀번호 변경
    void updatePassword(Long userId, PasswordChangeRequestDTO requestDTO);

//    // [PATCH] 계정 이메일 주소 변경 --> 삭제
//    void updateEmail(Long userId, EmailChangeRequestDTO requestDTO);

    // [POST] 이메일 변경 1단계: 본인 확인 및 새 이메일로 인증번호 발송
    void sendEmailChangeVerification(Long userId, EmailChangeVerificationRequestDTO requestDTO);

    // [PATCH] 이메일 변경 2단계: 인증번호 검증 및 즉시 이메일 변경
    void verifyAndChangeEmail(Long userId, EmailChangeVerificationCheckRequestDTO requestDTO);

    // [DELETE] 회원 탈퇴 처리
    void deleteAccount(Long userId);

    // [GET] 유저 권한 조회
    PermissionsResponseDTO getPermissions(Long userId);

    // [PATCH] 권한 설정 토글 업데이트
    void updatePermissions(Long userId, PermissionsUpdateRequestDTO requestDTO);

    // [PATCH] FCM 토큰 등록 및 갱신
    void updateFcmToken(Long userId, FcmTokenUpdateRequestDTO requestDTO);

    // [POST] 잠금 해제용 이메일 인증번호 발송
    void sendUnlockEmailVerification(EmailVerificationRequestDTO requestDTO);

    // [PATCH] 계정 잠금 최종 해제
    void unlockAccount(AccountUnlockRequestDTO requestDTO);

}