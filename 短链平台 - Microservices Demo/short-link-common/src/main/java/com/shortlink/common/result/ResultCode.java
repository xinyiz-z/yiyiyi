package com.shortlink.common.result;

import lombok.Getter;

/**
 * 统一返回码枚举
 */
@Getter
public enum ResultCode {

    SUCCESS(0, "success"),
    FAIL(1, "fail"),

    // 通用错误 1xxx
    BAD_REQUEST(1001, "请求参数不合法"),
    UNAUTHORIZED(1002, "未登录或登录已过期"),
    FORBIDDEN(1003, "无访问权限"),
    NOT_FOUND(1004, "资源不存在"),
    METHOD_NOT_ALLOWED(1005, "请求方法不被允许"),
    INTERNAL_ERROR(1999, "服务器内部异常"),

    // 短链业务错误 2xxx
    SHORT_LINK_NOT_FOUND(2001, "短链不存在或已失效"),
    SHORT_LINK_EXPIRED(2002, "短链已过期"),
    SHORT_LINK_DISABLED(2003, "短链已被禁用"),
    LONG_URL_INVALID(2010, "原始链接不合法"),
    LONG_URL_TOO_LONG(2011, "原始链接过长"),
    SHORT_CODE_GENERATE_FAILED(2020, "短码生成失败，请重试"),
    SHORT_CODE_COLLISION(2021, "短码冲突已达上限，请重试");

    private final Integer code;
    private final String message;

    ResultCode(Integer code, String message) {
        this.code = code;
        this.message = message;
    }
}
