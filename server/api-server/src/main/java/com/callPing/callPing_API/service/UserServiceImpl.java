package com.callPing.callPing_API.service;

import com.callPing.callPing_API.domain.User;
import com.callPing.callPing_API.domain.UserSetting;
import com.callPing.callPing_API.dto.request.session.LoginRequestDTO;
import com.callPing.callPing_API.dto.request.session.LogoutRequestDTO;
import com.callPing.callPing_API.dto.request.user.*;
import com.callPing.callPing_API.dto.response.session.LoginResponseDTO;
import com.callPing.callPing_API.dto.response.user.*;
import com.callPing.callPing_API.repository.UserRepository;
import com.callPing.callPing_API.repository.UserSettingRepository;
import com.callPing.callPing_API.security.JwtProvider;
import com.callPing.callPing_API.exception.ApiException;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.data.redis.core.StringRedisTemplate;

import java.time.OffsetDateTime;
import java.time.Duration;
import java.security.SecureRandom;
import java.util.UUID; // UUID 추가

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;
    private final UserSettingRepository userSettingRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtProvider jwtProvider;
    private final JavaMailSender mailSender;
    private final StringRedisTemplate redisTemplate;

    // Redis Key Prefix 및 만료 시간 정의
    private static final String AUTH_CODE_PREFIX = "AUTH_CODE:";
    private static final String FAIL_COUNT_PREFIX = "AUTH_FAIL:";
    private static final String VERIFIED_EMAIL_PREFIX = "VERIFIED_EMAIL:";
    private static final String REFRESH_TOKEN_PREFIX = "RT:";
    private static final String EMAIL_CHANGE_CODE_PREFIX = "EMAIL_CHANGE_CODE:";
    private static final String EMAIL_CHANGE_TARGET_PREFIX = "EMAIL_CHANGE_TARGET:";

    private static final long AUTH_CODE_EXPIRATION_MINUTES = 3;
    private static final long VERIFIED_EMAIL_EXPIRATION_MINUTES = 30;
    private static final int MAX_FAIL_COUNT = 5;
    private static final long LOCK_TIME_MINUTES = 30;
    private static final long REFRESH_TOKEN_EXPIRATION_DAYS = 14;

    // =================================================================================
    // #1. 로그인/회원가입 로직
    // =================================================================================

    @Override
    public void sendSignUpEmailVerification(EmailVerificationRequestDTO requestDTO) {
        String email = requestDTO.email();
        if (userRepository.existsByEmail(email)) {
            throw new ApiException(409, "USER_ERR_DUPLICATED_EMAIL", "이미 가입된 이메일입니다.");
        }
        sendAndStoreVerificationCode(email, AUTH_CODE_PREFIX);
    }

    @Override
    public void checkEmailVerification(EmailVerificationCheckRequestDTO requestDTO) {
        String email = requestDTO.email();
        String inputCode = requestDTO.verificationCode();
        String storedCode = redisTemplate.opsForValue().get(AUTH_CODE_PREFIX + email);

        if (storedCode == null) {
            throw new ApiException(401, "AUTH_ERR_CODE_EXPIRED", "인증 시간이 만료되었습니다. 다시 시도해 주세요.");
        }
        if (!storedCode.equals(inputCode)) {
            throw new ApiException(401, "AUTH_ERR_INVALID_CODE", "인증 코드가 일치하지 않습니다.");
        }

        redisTemplate.delete(AUTH_CODE_PREFIX + email);
        redisTemplate.opsForValue().set(
                VERIFIED_EMAIL_PREFIX + email,
                "VERIFIED",
                Duration.ofMinutes(VERIFIED_EMAIL_EXPIRATION_MINUTES)
        );
        log.info("이메일 인증 성공: {}", email);
    }

    @Override
    public boolean checkLoginIdAvailable(String loginId) {
        return !userRepository.existsByLoginId(loginId);
    }

    @Override
    @Transactional
    public SignUpResponseDTO signUp(SignUpRequestDTO requestDTO) {
        if (!requestDTO.termsAgreed()) {
            throw new ApiException(400, "USER_ERR_TERMS_NOT_AGREED", "필수 약관에 동의해야 합니다.");
        }
        if (userRepository.existsByLoginId(requestDTO.loginId())) {
            throw new ApiException(409, "USER_ERR_DUPLICATED_LOGIN_ID", "이미 사용 중인 아이디입니다.");
        }

        String encodedPassword = passwordEncoder.encode(requestDTO.password());

        User user = User.builder()
                .loginId(requestDTO.loginId())
                .password(encodedPassword)
                .email(requestDTO.email())
                .termsAgreed(requestDTO.termsAgreed())
                .build();

        User savedUser = userRepository.save(user);

        UserSetting defaultSetting = UserSetting.builder()
                .user(savedUser)
                .fileUploadPermission(false)
                .pushPermission(true)
                .build();
        userSettingRepository.save(defaultSetting);

        redisTemplate.delete(VERIFIED_EMAIL_PREFIX + requestDTO.email());

        return new SignUpResponseDTO(
                savedUser.getId(),
                savedUser.getLoginId(),
                OffsetDateTime.now() // TODO: 추후 savedUser.getCreatedAt() 으로 변경 권장
        );
    }

    // =================================================================================
    // #2. 계정 찾기 & 비밀번호 재설정
    // =================================================================================

    @Override
    public void sendFindEmailVerification(EmailVerificationRequestDTO requestDTO) {
        if (!userRepository.existsByEmail(requestDTO.email())) {
            throw new ApiException(404, "USER_ERR_NOT_FOUND", "가입되지 않은 이메일입니다.");
        }
        sendAndStoreVerificationCode(requestDTO.email(), AUTH_CODE_PREFIX);
    }

    @Override
    public FindIdResponseDTO findId(FindIdRequestDTO requestDTO) {
        User user = userRepository.findByEmail(requestDTO.email())
                .orElseThrow(() -> new ApiException(404, "USER_ERR_NOT_FOUND", "해당 이메일로 가입된 유저를 찾을 수 없습니다."));
        return new FindIdResponseDTO(user.getLoginId());
    }

    @Override
    public void sendPasswordResetEmailVerification(EmailVerificationRequestDTO requestDTO) {
        if (!userRepository.existsByEmail(requestDTO.email())) {
            throw new ApiException(404, "USER_ERR_NOT_FOUND", "가입되지 않은 이메일입니다.");
        }
        sendAndStoreVerificationCode(requestDTO.email(), AUTH_CODE_PREFIX);
    }

    @Override
    @Transactional
    public void resetPassword(PasswordResetRequestDTO requestDTO) {
        User user = userRepository.findByLoginId(requestDTO.loginId())
                .orElseThrow(() -> new ApiException(404, "USER_ERR_NOT_FOUND", "사용자를 찾을 수 없습니다."));

        if (!user.getEmail().equals(requestDTO.email())) {
            throw new ApiException(400, "USER_ERR_INFO_MISMATCH", "회원 정보가 일치하지 않습니다.");
        }

        String encodedPassword = passwordEncoder.encode(requestDTO.password());
        user.changePassword(encodedPassword);
    }

    // =================================================================================
    // #3. 세션 도메인 (로그인/로그아웃)
    // =================================================================================

    @Override
    @Transactional(noRollbackFor = { ApiException.class }) // 중복된 ApiException 제거
    public LoginResponseDTO login(LoginRequestDTO requestDTO) {
        String loginId = requestDTO.loginId();

        // 1. 유저 조회 (가장 먼저 해야 함)
        User user = userRepository.findByLoginId(loginId)
                .orElseThrow(() -> new ApiException(401, "AUTH_ERR_INVALID_CREDENTIALS", "아이디 또는 비밀번호가 잘못되었습니다."));

        // 2. 이미 계정이 잠겨 있는지 DB 기준으로 확인
        if (user.getFailedLoginCount() >= MAX_FAIL_COUNT || user.getIsLocked()) {
            throw new ApiException(403, "AUTH_ERR_ACCOUNT_LOCKED", "비밀번호 5회 오류로 계정이 잠겼습니다. 잠시 후 다시 시도해주세요.");
        }

        // 3. 비밀번호 검증
        if (!passwordEncoder.matches(requestDTO.password(), user.getPassword())) {

            user.increaseFailedLoginCount();

            userRepository.saveAndFlush(user);

            // 잠겼을 때와 단순 틀렸을 때의 응답 분리
            if (user.getIsLocked()) {
                throw new ApiException(403, "AUTH_ERR_ACCOUNT_LOCKED", "비밀번호 5회 오류로 계정이 잠겼습니다. 잠시 후 다시 시도해주세요.");
            } else {
                throw new ApiException(401, "AUTH_ERR_INVALID_CREDENTIALS", "아이디 또는 비밀번호가 잘못되었습니다. (실패 횟수: " + user.getFailedLoginCount() + "/" + MAX_FAIL_COUNT + ")");
            }
        }

        // 4. 로그인 성공 시 실패 카운트 및 잠금 상태 초기화
        if (user.getFailedLoginCount() > 0) {
            user.unlockAccount();
            userRepository.saveAndFlush(user);
        }

        // 5. Access Token 및 Refresh Token 발급
        String accessToken = jwtProvider.createAccessToken(user.getLoginId());
        String refreshToken = UUID.randomUUID().toString();

        redisTemplate.opsForValue().set(
                REFRESH_TOKEN_PREFIX + refreshToken,
                user.getLoginId(),
                Duration.ofDays(REFRESH_TOKEN_EXPIRATION_DAYS)
        );

        return new LoginResponseDTO(accessToken, user.getId(), refreshToken);
    }

    @Override
    public void logout(LogoutRequestDTO requestDTO) {
        String refreshToken = requestDTO.refreshToken();
        if (refreshToken == null || refreshToken.isEmpty()) {
            throw new ApiException(400, "AUTH_ERR_INVALID_TOKEN", "유효하지 않은 토큰입니다.");
        }

        String loginId = redisTemplate.opsForValue().get(REFRESH_TOKEN_PREFIX + refreshToken);

        if (loginId != null) {
            redisTemplate.delete(REFRESH_TOKEN_PREFIX + refreshToken);
            log.info("로그아웃 처리 완료 (loginId: {})", loginId);
        } else {
            log.warn("로그아웃 요청 - 이미 만료되었거나 존재하지 않는 Refresh Token입니다.");
        }
    }

    // =================================================================================
    // #4. 계정 잠금 해제 로직
    // =================================================================================

    @Override
    public void sendUnlockEmailVerification(EmailVerificationRequestDTO requestDTO) {
        if (!userRepository.existsByEmail(requestDTO.email())) {
            throw new ApiException(404, "USER_ERR_NOT_FOUND", "가입되지 않은 이메일입니다.");
        }
        sendAndStoreVerificationCode(requestDTO.email(), AUTH_CODE_PREFIX);
        log.info("잠금 해제용 이메일 발송 완료: email={}", requestDTO.email());
    }

    @Override
    @Transactional
    public void unlockAccount(AccountUnlockRequestDTO requestDTO) {
        User user = userRepository.findByLoginId(requestDTO.loginId())
                .orElseThrow(() -> new ApiException(404, "USER_ERR_NOT_FOUND", "사용자를 찾을 수 없습니다."));

        if (!user.getEmail().equals(requestDTO.email())) {
            throw new ApiException(400, "USER_ERR_CURRENT_EMAIL_MISMATCH", "회원 정보에 등록된 이메일과 일치하지 않습니다.");
        }

        String verifiedStatus = redisTemplate.opsForValue().get(VERIFIED_EMAIL_PREFIX + requestDTO.email());
        if (!"VERIFIED".equals(verifiedStatus)) {
            throw new ApiException(403, "AUTH_ERR_NOT_VERIFIED", "이메일 인증이 완료되지 않았거나 만료되었습니다.");
        }

        // Redis failKey 확인 로직을 지우고, DB 기준으로 잠금 여부 확인
        if (!user.getIsLocked()) {
            throw new ApiException(400, "AUTH_ERR_ACCOUNT_NOT_LOCKED", "잠금 처리된 계정이 아닙니다.");
        }
        // 해제
        user.unlockAccount();

        // 인증 상태 삭제
        redisTemplate.delete(VERIFIED_EMAIL_PREFIX + requestDTO.email());

        log.info("계정 잠금 해제 완료: loginId={}", requestDTO.loginId());
    }


    // =================================================================================
    // 기존 설정 및 프로필 로직
    // =================================================================================

    @Override
    public UserProfileResponseDTO getMyProfile(Long userId) {
        User user = getUserById(userId);
        return new UserProfileResponseDTO(user.getId(), user.getLoginId(), user.getEmail());
    }

    @Override
    @Transactional
    public void updatePassword(Long userId, PasswordChangeRequestDTO requestDTO) {
        User user = getUserById(userId);

        if (!passwordEncoder.matches(requestDTO.currentPassword(), user.getPassword())) {
            throw new ApiException(401, "USER_ERR_INVALID_PASSWORD", "현재 비밀번호가 일치하지 않습니다.");
        }

        String encodedPassword = passwordEncoder.encode(requestDTO.newPassword());
        user.changePassword(encodedPassword);
        log.info("비밀번호 변경 완료: userId={}", userId);
    }

    @Override
    public void sendEmailChangeVerification(Long userId, EmailChangeVerificationRequestDTO requestDTO) {
        User user = getUserById(userId);

        if (!user.getEmail().equals(requestDTO.currentEmail())) {
            throw new ApiException(400, "USER_ERR_CURRENT_EMAIL_MISMATCH", "현재 이메일 정보가 일치하지 않습니다.");
        }
        if (userRepository.existsByEmail(requestDTO.newEmail())) {
            throw new ApiException(409, "USER_ERR_DUPLICATED_EMAIL", "이미 사용 중인 이메일 주소입니다.");
        }

        String verificationCode = generateRandomCode();
        redisTemplate.opsForValue().set(
                EMAIL_CHANGE_CODE_PREFIX + userId,
                verificationCode,
                Duration.ofMinutes(AUTH_CODE_EXPIRATION_MINUTES)
        );
        redisTemplate.opsForValue().set(
                EMAIL_CHANGE_TARGET_PREFIX + userId,
                requestDTO.newEmail(),
                Duration.ofMinutes(AUTH_CODE_EXPIRATION_MINUTES)
        );

        sendEmail(requestDTO.newEmail(), verificationCode);
        log.info("이메일 변경용 인증코드 발송 완료: userId={}, targetEmail={}", userId, requestDTO.newEmail());
    }

    @Override
    @Transactional
    public void verifyAndChangeEmail(Long userId, EmailChangeVerificationCheckRequestDTO requestDTO) {
        String storedCode = redisTemplate.opsForValue().get(EMAIL_CHANGE_CODE_PREFIX + userId);
        if (storedCode == null || !storedCode.equals(requestDTO.verificationCode())) {
            throw new ApiException(401, "AUTH_ERR_INVALID_CODE", "인증번호가 일치하지 않거나 만료되었습니다.");
        }

        String targetEmail = redisTemplate.opsForValue().get(EMAIL_CHANGE_TARGET_PREFIX + userId);
        if (targetEmail == null) {
            throw new ApiException(401, "AUTH_ERR_EXPIRED_REQUEST", "이메일 변경 요청 정보가 만료되었습니다. 처음부터 다시 시도해주세요.");
        }

        User user = getUserById(userId);
        user.changeEmail(targetEmail);

        redisTemplate.delete(EMAIL_CHANGE_CODE_PREFIX + userId);
        redisTemplate.delete(EMAIL_CHANGE_TARGET_PREFIX + userId);

        log.info("이메일 성공적 변경 완료: userId={}, newEmail={}", userId, targetEmail);
    }

    @Override
    @Transactional
    public void deleteAccount(Long userId) {
        User user = getUserById(userId);
        userRepository.delete(user);
    }

    @Override
    public PermissionsResponseDTO getPermissions(Long userId) {
        UserSetting setting = userSettingRepository.findById(userId)
                .orElseThrow(() -> new ApiException(404, "USER_SETTING_NOT_FOUND", "사용자 설정 정보가 존재하지 않습니다."));

        return new PermissionsResponseDTO(
                setting.getFileUploadPermission(),
                setting.getPushPermission()
        );
    }

    @Override
    @Transactional
    public void updatePermissions(Long userId, PermissionsUpdateRequestDTO requestDTO) {
        UserSetting setting = userSettingRepository.findById(userId)
                .orElseThrow(() -> new ApiException(404, "USER_SETTING_NOT_FOUND", "사용자 정보가 존재하지 않습니다."));

        setting.updatePermissions(requestDTO.fileUploadPermission(), requestDTO.pushNotificationPermission());
    }

    @Override
    @Transactional
    public void updateFcmToken(Long userId, FcmTokenUpdateRequestDTO requestDTO) {
        User user = getUserById(userId);
        user.updateFcmToken(requestDTO.fcmToken());
    }

    // =================================================================================
    // 내부 헬퍼 메서드
    // =================================================================================

    private void sendAndStoreVerificationCode(String email, String prefix) {
        String verificationCode = generateRandomCode();
        redisTemplate.opsForValue().set(
                prefix + email,
                verificationCode,
                Duration.ofMinutes(AUTH_CODE_EXPIRATION_MINUTES)
        );
        sendEmail(email, verificationCode);
        log.info("이메일 발송 완료: {}", email);
    }

    private String generateRandomCode() {
        SecureRandom secureRandom = new SecureRandom();
        int code = 100000 + secureRandom.nextInt(900000);
        return String.valueOf(code);
    }

    private void sendEmail(String toEmail, String code) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(toEmail);
        message.setSubject("[CallPing] 이메일 인증 번호입니다.");
        message.setText("안녕하세요.\nCallPing 요청하신 인증 번호는 [" + code + "] 입니다.\n3분 안에 입력해 주세요.");
        mailSender.send(message);
    }

    private User getUserById(Long userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(404, "USER_ERR_NOT_FOUND", "존재하지 않는 사용자입니다."));
    }
}