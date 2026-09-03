package com.callPing.callPing_API.domain;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "user_settings")
@Getter
@Setter
@Builder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
public class UserSetting {

    @Id
    @Column(name = "user_id")
    private Long userId;

    @OneToOne(fetch = FetchType.LAZY)
    @MapsId // User 엔티티의 PK(user_id)를 자신의 PK로 매핑 및 공유
    @JoinColumn(name = "user_id")
    private User user;

    @Column(name = "upload_permission", nullable = false)
    private Boolean fileUploadPermission = true;

    @Column(name = "push_permission", nullable = false)
    private Boolean pushPermission = true;

    // 연관관계 편의 메서드 및 비즈니스 메서드
    // => 회원가입 시 회원정보와 기본권한설정정보가 누락되지 않고 한 번에 묶여 생성되도록
    // 보장하는 로직
    public static UserSetting createSetting(User user) {
        UserSetting setting = new UserSetting();
        setting.setUser(user);
        setting.setFileUploadPermission(true);
        setting.setPushPermission(true);
        return setting;
    }

    public void updatePermissions(boolean fileUploadPermission, boolean pushPermission) {
        this.fileUploadPermission = fileUploadPermission;
        this.pushPermission = pushPermission;
    }
}