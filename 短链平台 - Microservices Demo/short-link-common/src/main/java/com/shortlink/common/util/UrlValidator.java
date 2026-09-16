package com.shortlink.common.util;

import cn.hutool.core.util.StrUtil;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.Set;

/**
 * 原始 URL 校验工具。
 */
public final class UrlValidator {

    /** 允许的协议 */
    private static final Set<String> ALLOWED_SCHEMES = Set.of("http", "https");

    /** 最长允许长度（防止恶意超长 URL 占存储） */
    public static final int MAX_URL_LENGTH = 2048;

    private UrlValidator() {
    }

    /**
     * 校验 URL 合法性。返回 null 表示通过，否则返回错误描述。
     */
    public static String validate(String url) {
        if (StrUtil.isBlank(url)) {
            return "URL 不能为空";
        }
        String trimmed = url.trim();
        if (trimmed.length() > MAX_URL_LENGTH) {
            return "URL 长度不能超过 " + MAX_URL_LENGTH;
        }
        URI uri;
        try {
            uri = new URI(trimmed);
        } catch (URISyntaxException e) {
            return "URL 格式不合法: " + e.getMessage();
        }
        String scheme = uri.getScheme();
        if (scheme == null) {
            return "URL 必须包含协议 (http/https)";
        }
        if (!ALLOWED_SCHEMES.contains(scheme.toLowerCase())) {
            return "URL 协议必须是 http 或 https，当前: " + scheme;
        }
        String host = uri.getHost();
        if (host == null || host.isBlank()) {
            return "URL 缺少有效域名";
        }
        return null;
    }

    public static boolean isValid(String url) {
        return validate(url) == null;
    }
}
