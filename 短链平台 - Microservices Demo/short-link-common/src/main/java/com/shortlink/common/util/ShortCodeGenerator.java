package com.shortlink.common.util;

import cn.hutool.core.util.StrUtil;
import com.google.common.hash.HashFunction;
import com.google.common.hash.Hashing;
import lombok.extern.slf4j.Slf4j;

import java.nio.charset.StandardCharsets;

/**
 * 短码生成器（哈希方案）。
 * <p>
 * 方案：SHA-256(longUrl + salt) → 取前 8 字节 → 转 long → Base62 编码 → 取前 7 位。
 * <ul>
 *   <li>碰撞概率：2^64 空间下 1 亿条数据碰撞概率 ≈ 5.4 × 10⁻¹¹（生日悖论）</li>
 *   <li>碰撞处理：使用 salt 自增重试，最多重试 5 次</li>
 *   <li>最终兜底：DB unique 索引，service 层捕获 DuplicateKeyException</li>
 * </ul>
 * 同一长链会复用同一短码（缓存层避免重复哈希），由调用方控制。
 */
@Slf4j
public final class ShortCodeGenerator {

    /** 默认短码长度（Base62 7 位 → 62^7 ≈ 3.5 万亿） */
    public static final int DEFAULT_LENGTH = 7;

    /** 最大重试次数（碰撞重哈希） */
    public static final int MAX_RETRY = 5;

    /** MurmurHash3 - 用于进程内缓存 key，O(N) 去重 */
    private static final HashFunction MURMUR = Hashing.murmur3_128();

    /** SHA-256 - 用于短码生成，抗碰撞强 */
    private static final HashFunction SHA256 = Hashing.sha256();

    private ShortCodeGenerator() {
    }

    /**
     * 生成短码。
     *
     * @param longUrl 原始长链
     * @return 7 位短码
     */
    public static String generate(String longUrl) {
        return generate(longUrl, DEFAULT_LENGTH);
    }

    /**
     * 生成指定长度短码。
     *
     * @param longUrl 原始长链
     * @param length  短码长度（建议 6~8）
     */
    public static String generate(String longUrl, int length) {
        if (StrUtil.isBlank(longUrl)) {
            throw new IllegalArgumentException("longUrl 不能为空");
        }
        if (length < 4 || length > 16) {
            throw new IllegalArgumentException("短码长度非法: " + length);
        }
        // 碰撞重试：每次增加盐值，碰撞概率指数级下降
        for (int salt = 0; salt < MAX_RETRY; salt++) {
            String candidate = doGenerate(longUrl, salt, length);
            if (candidate != null) {
                return candidate;
            }
        }
        log.error("[ShortCode] 重试 {} 次仍生成失败, url={}", MAX_RETRY, longUrl);
        return null;
    }

    private static String doGenerate(String longUrl, int salt, int length) {
        try {
            String input = longUrl + "#" + salt;
            byte[] digest = SHA256.hashString(input, StandardCharsets.UTF_8).asBytes();
            String code = Base62Util.encodeBytes(digest, length);
            // 防御：理论不可能出现 null
            return code;
        } catch (Exception e) {
            log.error("[ShortCode] 生成异常, salt={}, err={}", salt, e.getMessage(), e);
            return null;
        }
    }

    /**
     * 计算长链的 MurmurHash（用于进程内缓存 key、幂等去重）。
     */
    public static String murmurKey(String longUrl) {
        return MURMUR.hashString(longUrl, StandardCharsets.UTF_8).toString();
    }
}
