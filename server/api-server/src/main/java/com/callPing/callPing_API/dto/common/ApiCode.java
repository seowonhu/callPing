package com.callPing.callPing_API.dto.common;

import java.lang.annotation.*;

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface ApiCode {
    String code();
    String message();
}