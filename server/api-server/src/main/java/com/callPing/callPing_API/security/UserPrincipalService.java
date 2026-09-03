package com.callPing.callPing_API.security;

import com.callPing.callPing_API.domain.User;
import com.callPing.callPing_API.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

/**
 * Spring Security 의 인증 과정에서 실제 DB의 유저 데이터를 찾아오는 '인증 전용 서비스' 입니다.
 * [필요성]
 * 1. 이 클래스는 Security 전용 부품으로만 사용됩니다.
 * 2. DB에서 User 엔티티를 찾은 후, Security 가 이해할 수 있는 UserPrincipal 객체로 변환하여 반환합니다.
 */

@Service
@RequiredArgsConstructor
public class UserPrincipalService implements UserDetailsService {

    private final UserRepository userRepository;

    @Override
    public UserDetails loadUserByUsername(String loginId) throws UsernameNotFoundException {
        //1. DB에서 loginId로 유저를 찾음
        User user = userRepository.findByLoginId(loginId)
                .orElseThrow(() -> new UsernameNotFoundException("사용자를 찾을 수 없습니다: " + loginId));

        //2. 찾아온 User 엔티티를 감싸서 반환
        return UserPrincipal.create(user);
    }
}