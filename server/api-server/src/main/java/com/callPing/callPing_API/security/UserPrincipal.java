package com.callPing.callPing_API.security;

import com.callPing.callPing_API.domain.User;
import lombok.AllArgsConstructor;
import lombok.Getter;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.Collections;

/**
 * Spring Security 가 이해할 수 있는 형태의 '유저 인증 객체 (사원증)' 입니다.
 * [필요성]
 * 1. 프로젝트의 User 엔티티를 Spring Security 의 UserDetails 규격에 맞게 감싸는 어댑터 역할을 합니다.
 * 2. DB의 User 엔티티에 직접적인 Security 종속성을 없애기 위해 사용합니다.
 * 3. Controller 에서 @AuthenticationPrincipal UserPrincipal principal 로 선언 =>
 *    인증된 사용자의 정보(principal.getUserId() 등)를 즉시 꺼내 쓸 수 있습니다!
 */

@Getter
@AllArgsConstructor
public class UserPrincipal implements UserDetails {

    // 컨트롤러에서 @AuthenticationPrincipal로 바로 꺼내 쓸 핵심 ID!
    private final Long userId;

    private final String loginId;
    private final String password;
    private final Collection<? extends GrantedAuthority> authorities;
    private final boolean isLocked;

    // User 엔티티를 UserPrincipal로 변환하는 팩토리 메서드
    public static UserPrincipal create(User user) {
        // 권한은 우선 기본 유저 권한 하나만 부여합니다. (추후 Role 엔티티가 있다면 맵핑 가능)
        Collection<GrantedAuthority> authorities = Collections.singletonList(
                new SimpleGrantedAuthority("ROLE_USER")
        );

        return new UserPrincipal(
                user.getId(),
                user.getLoginId(),
                user.getPassword(),
                authorities,
                user.getIsLocked()
        );
    }

    // Spring Security가 권한을 확인할 때 호출
    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return authorities;
    }

    // Spring Security가 비밀번호를 확인할 때 호출
    @Override
    public String getPassword() {
        return password;
    }

    // Spring Security가 식별자를 확인할 때 호출
    @Override
    public String getUsername() {
        return loginId;
    }

    // 계정 만료 여부 (true: 만료 안 됨)
    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    // 계정 잠금 여부 (true: 잠금 안 됨)
    @Override
    public boolean isAccountNonLocked() {
        return !isLocked;
    }

    // 비밀번호 만료 여부 (true: 만료 안 됨)
    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    // 계정 활성화 여부 (true: 활성화 됨)
    @Override
    public boolean isEnabled() {
        return true;
    }
}