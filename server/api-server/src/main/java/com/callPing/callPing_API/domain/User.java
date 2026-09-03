package com.callPing.callPing_API.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "users")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "user_id")
    private Long id;

    // 아이디(login_id)는 가입 후 시스템 내에서 변경되지 않으므로 수정 메서드를 제공하지 않음 [임시]
    @Column(name = "login_id", nullable = false, unique = true, length = 50)
    private String loginId;

    @Column(name = "password", nullable = false, length = 255)
    private String password;

    @Column(name = "email", nullable = false, unique = true, length = 100)
    private String email;

    @Column(name = "fcm_token", length = 255)
    private String fcmToken;

    @Column(name = "is_locked", nullable = false)
    private Boolean isLocked = false;

    @Column(name = "failed_login_count", nullable = false)
    private Integer failedLoginCount = 0;

    @Column(name = "terms_Agreed", nullable = false)
    private Boolean termsAgreed = false;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false, nullable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @OneToOne(mappedBy = "user", cascade = CascadeType.REMOVE, orphanRemoval = true)
    private UserSetting userSetting;

    // [객체 생성을 위한 빌더 패턴]
    // 가입 시 최초 필요한 필수 필드만 명확하게 정의하여 무분별한 인스턴스 생성을 방지
    @Builder
    private User(String loginId, String password, String email, Boolean termsAgreed) {
        this.loginId = loginId;
        this.password = password;
        this.email = email;
        this.isLocked = false;
        this.failedLoginCount = 0;
        this.termsAgreed = termsAgreed;
    }

    // ==========================================
    //  비즈니스 메서드
    // ==========================================

    // 로그인 상태에서 비밀번호 변경
    public void changePassword(String encodedPassword) {
        if (encodedPassword == null || encodedPassword.isBlank()) {
            throw new IllegalArgumentException("비밀번호는 공백일 수 없습니다.");
        }
        this.password = encodedPassword;
    }

    //계정 이메일 주소 변경
    public void changeEmail(String newEmail) {
        if (newEmail == null || newEmail.isBlank()) {
            throw new IllegalArgumentException("이메일 주소는 공백일 수 없습니다.");
        }
        this.email = newEmail;
    }

    // FCM 푸시 토큰 등록 및 주기적 갱신
    public void updateFcmToken(String fcmToken) {
        if (fcmToken == null || fcmToken.isBlank()) {
            throw new IllegalArgumentException("FCM 토큰이 올바르지 않습니다.");
        }
        this.fcmToken = fcmToken;
    }

    // 로그아웃 시 알림이 가지 않도록 서버 내 토큰 해제 [임시]
    public void clearFcmToken() {
        this.fcmToken = null;
    }

    // 로그인 실패 시 카운트 증가 및 5회 도달 시 자동 잠금 제어 로직
    public void increaseFailedLoginCount() {
        if (this.isLocked) {
            return;
        }
        this.failedLoginCount++;
        if (this.failedLoginCount >= 5) {
            this.isLocked = true;
        }
    }

    // 계정 잠금 해제 및 실패 카운트 초기화 'PATCH /api/v1/users/account-unlock' 연동용 비즈니스 메서드
    public void unlockAccount() {
        this.isLocked = false;
        this.failedLoginCount = 0;
    }
}