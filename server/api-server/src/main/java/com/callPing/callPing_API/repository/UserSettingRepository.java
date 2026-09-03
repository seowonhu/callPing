package com.callPing.callPing_API.repository;

import com.callPing.callPing_API.domain.UserSetting;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface UserSettingRepository extends JpaRepository<UserSetting, Long> {
    // CRUD는 JpaRepository 내에서 제공되므로 우선 생략
    // TODO 차후 필요시 CRUD 기술
}
