package com.callPing.callPing_API;
/**
 * 애플리케이션의 메인 진입점(Entry Point)을 담당하는 클래스입니다.
 * * @SpringBootApplication 어노테이션을 통해 스프링 부트의 자동 설정,
 * Bean 읽기와 생성을 자동으로 처리하며, 내장 WAS(Web Application Server)를 실행하여
 * API 서버를 구동합니다.
 */

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class ApiServerApplication {
	public static void main(String[] args) {
		SpringApplication.run(ApiServerApplication.class, args);
	}
}
