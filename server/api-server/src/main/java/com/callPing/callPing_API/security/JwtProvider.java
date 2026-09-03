package com.callPing.callPing_API.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.util.Date;

//JWT 토큰 생성, 검증, 정보 추출을 담당하는 클래스

@Slf4j
@Component
@RequiredArgsConstructor
public class JwtProvider {

    // application.properties 에 설정된 비밀키와 만료시간 지정
    @Value("${jwt.secret}")
    private String secretKeyString;

    @Value("${jwt.access-expiration}")
    private long accessExpiration;

    private Key secretKey;
    private final UserPrincipalService userPrincipalService;

    // 빈이 생성된 후 비밀키를 암호화 키 객체로 변환
    @PostConstruct
    protected void init() {
        secretKey = Keys.hmacShaKeyFor(secretKeyString.getBytes(StandardCharsets.UTF_8));
    }

    // 1. 엑세스 토큰 생성
    public String createAccessToken(String loginId) {
        Date now = new Date();
        Date validity = new Date(now.getTime() + accessExpiration);

        return Jwts.builder()
                .setSubject(loginId) // 토큰 주인을 loginId로 설정
                .setIssuedAt(now) // 발행 시간
                .setExpiration(validity) // 만료 시간
                .signWith(secretKey, SignatureAlgorithm.HS256) // 비밀키로 서명 (위조 방지)
                .compact();
    }

    // 2. 토큰 유효성 및 만료일자 확인
    public boolean validateToken(String token) {
        try {
            Jwts.parserBuilder().setSigningKey(secretKey).build().parseClaimsJws(token);
            return true;
        } catch (ExpiredJwtException e) {
            log.error("만료된 JWT 토큰입니다.");
        } catch (Exception e) {
            log.error("유효하지 않은 JWT 토큰입니다: {}", e.getMessage());
        }
        return false;
    }

    // 3. 토큰에서 인증 정보 추출 -> SecurityContext 에 저장하기 위함
    public Authentication getAuthentication(String token) {
        Claims claims = Jwts.parserBuilder()
                .setSigningKey(secretKey)
                .build()
                .parseClaimsJws(token)
                .getBody();

        String loginId = claims.getSubject();

        // UserPrincipalService 를 통해 DB에서 유저 정보를 가져옴
        UserDetails userDetails = userPrincipalService.loadUserByUsername(loginId);

        // SecurityContext 에 넣을 인증 완료 객체 생성 (비밀번호는 보안상 빈 문자열 처리)
        return new UsernamePasswordAuthenticationToken(userDetails, "", userDetails.getAuthorities());
    }
}