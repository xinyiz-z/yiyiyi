package com.shortlink.common.util;

import cn.hutool.core.util.StrUtil;

/**
 * Base62 编码工具（0-9a-zA-Z）。
 * <p>
 * 常用于短链 ID 编码：相比 Base64 避免了 URL 传输中的 '+'、'/'、'=' 特殊字符问题。
 */
public final class Base62Util {

    private static final char[] CHARS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".toCharArray();

    private static final int BASE = CHARS.length;

    private static final int SCALE = 256;

    private static final int MIN_LENGTH = 6;

    private Base62Util() {
    }

    /**
     * 将 long 编码为 Base62 字符串。
     *
     * @param value 非负整数
     * @return Base62 字符串
     */
    public static String encode(long value) {
        if (value < 0) {
            throw new IllegalArgumentException("Base62 encode 仅支持非负整数, value=" + value);
        }
        if (value == 0) {
            return String.valueOf(CHARS[0]);
        }
        StringBuilder sb = new StringBuilder();
        while (value > 0) {
            int idx = (int) (value % BASE);
            sb.append(CHARS[idx]);
            value /= BASE;
        }
        return sb.reverse().toString();
    }

    /**
     * Base62 字符串转 long。
     */
    public static long decode(String base62) {
        if (StrUtil.isBlank(base62)) {
            throw new IllegalArgumentException("Base62 字符串不能为空");
        }
        long result = 0;
        for (int i = 0; i < base62.length(); i++) {
            char c = base62.charAt(i);
            int idx = indexOf(c);
            if (idx < 0) {
                throw new IllegalArgumentException("非法的 Base62 字符: " + c);
            }
            result = result * BASE + idx;
        }
        return result;
    }

    /**
     * 将字节数组（取前 8 字节）编码为指定长度的 Base62 字符串。长度不足时左补 0。
     * <p>
     * 用无符号 long 处理（高位字节可能让 long 解释为负数），保证编码成功。
     *
     * @param bytes   字节数组，至少 8 字节
     * @param length  目标字符串长度（建议 6~8）
     */
    public static String encodeBytes(byte[] bytes, int length) {
        if (bytes == null || bytes.length < 8) {
            throw new IllegalArgumentException("字节数组长度至少 8");
        }
        // 把 8 字节视为 unsigned big-endian → long
        long value = 0L;
        for (int i = 0; i < 8; i++) {
            value = (value << 8) | (bytes[i] & 0xffL);
        }
        // 用无符号除/取模转换 Base62
        StringBuilder sb = new StringBuilder();
        while (value != 0L) {
            long q = Long.divideUnsigned(value, BASE);
            int r = (int) Long.remainderUnsigned(value, BASE);
            sb.append(CHARS[r]);
            value = q;
        }
        if (sb.length() == 0) {
            sb.append(CHARS[0]);
        }
        String encoded = sb.reverse().toString();
        if (encoded.length() >= length) {
            return encoded.substring(0, length);
        }
        // 左补 '0'，保证短码长度一致（保证 URL 长度可控）
        return StrUtil.fillBefore(encoded, CHARS[0], length);
    }

    private static int indexOf(char c) {
        if (c >= '0' && c <= '9') return c - '0';
        if (c >= 'a' && c <= 'z') return c - 'a' + 10;
        if (c >= 'A' && c <= 'Z') return c - 'A' + 36;
        return -1;
    }

    /**
     * 校验字符串是否合法短码（仅含 Base62 字符）。
     */
    public static boolean isValidShortCode(String s) {
        if (s == null || s.length() < MIN_LENGTH || s.length() > 16) {
            return false;
        }
        for (int i = 0; i < s.length(); i++) {
            if (indexOf(s.charAt(i)) < 0) {
                return false;
            }
        }
        return true;
    }

    /** 仅供测试 */
    int scale() { return SCALE; }
}
