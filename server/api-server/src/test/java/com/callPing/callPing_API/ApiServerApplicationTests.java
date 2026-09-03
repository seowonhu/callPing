package com.callPing.callPing_API;

/**
 * 애플리케이션의 전반적인 컨텍스트 로드 및 통합 테스트를 위한 기본 클래스로
 * @SpringBootTest 어노테이션을 사용하여 실제 운영 환경과 유사한 스프링 컨텍스트를 로드하고,
 * 각 계층이 정상적으로 연동되는지 테스트할 수 있는 환경을 제공합니다.
 */

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class ApiServerApplicationTests {

	@Test
	void contextLoads() {
	}

}
