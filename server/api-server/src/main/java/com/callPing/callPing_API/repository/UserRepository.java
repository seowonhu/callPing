package com.callPing.callPing_API.repository;

import com.callPing.callPing_API.domain.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository   <User, Long>{
 // [최현수] 로그인/중복확인 검증 시 필요한 쿼리 메소드입니다 ... 가져다 사용하십쇼
 Optional<User> findByLoginId(String loginId);
 Optional<User> findByEmail(String email);

 boolean existsByLoginId(String loginId);
 boolean existsByEmail(String email);

}