package com.callPing.callPing_API.dto.common.constant;

/**
 * Bean Validation(@Pattern 등)에서 공통으로 쓰는 정규식/메시지 상수.
 * 여러 DTO에서 동일한 검증 규칙을 사용할 때 값이 어긋나지 않도록 여기서만 관리한다.
 */
public final class ValidationRule {

    private ValidationRule() {}

    // 아이디 (5~20자의 영문 소문자, 숫자)
    public static final String LOGIN_ID_REGEXP = "^[a-z0-9]{5,20}$";
    public static final String LOGIN_ID_FORMAT_MESSAGE = "아이디는 5~20자의 영문 소문자, 숫자만 사용 가능합니다.";
    public static final String LOGIN_ID_BLANK_MESSAGE = "아이디는 필수입니다.";

    // 비밀번호 (영문, 숫자, 특수문자 포함 8자 이상)
    public static final String PASSWORD_REGEXP =
            "^(?=.*[A-Za-z])(?=.*\\d)(?=.*[!@#$%^&*()_+])[A-Za-z\\d!@#$%^&*()_+]{8,}$";
    public static final String PASSWORD_FORMAT_MESSAGE = "비밀번호 형식이 올바르지 않습니다. (영문, 숫자, 특수문자 포함 8자 이상)";
    public static final String PASSWORD_BLANK_MESSAGE = "비밀번호는 필수입니다.";

    // 이메일
    public static final String EMAIL_BLANK_MESSAGE = "이메일은 필수입니다.";
    public static final String EMAIL_FORMAT_MESSAGE = "올바른 이메일 형식이 아닙니다.";

    // 이메일 인증 코드 (6자리 숫자)
    public static final String VERIFICATION_CODE_REGEXP = "^[0-9]{6}$";
    public static final String VERIFICATION_CODE_FORMAT_MESSAGE = "인증 코드는 6자리 숫자입니다.";
    public static final String VERIFICATION_CODE_BLANK_MESSAGE = "인증 코드는 필수입니다.";

    // 약관 동의
    public static final String TERMS_AGREED_BLANK_MESSAGE = "약관 동의 여부는 필수입니다.";
    public static final String TERMS_AGREED_FALSE_MESSAGE = "필수 약관에 동의해야 회원가입이 가능합니다.";
}