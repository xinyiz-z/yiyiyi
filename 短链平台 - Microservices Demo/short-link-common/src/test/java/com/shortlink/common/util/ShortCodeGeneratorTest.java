package com.shortlink.common.util;

import org.junit.jupiter.api.Test;

import java.util.HashSet;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ShortCodeGeneratorTest {

    @Test
    void testGenerateDefaultLength() {
        String code = ShortCodeGenerator.generate("https://www.example.com/path/to/long/url");
        assertNotNull(code);
        assertEquals(ShortCodeGenerator.DEFAULT_LENGTH, code.length());
        assertTrue(Base62Util.isValidShortCode(code));
    }

    @Test
    void testGenerateCustomLength() {
        for (int len : new int[]{6, 7, 8}) {
            String code = ShortCodeGenerator.generate("https://example.com/" + System.nanoTime(), len);
            assertEquals(len, code.length(), "长度应为 " + len);
        }
    }

    @Test
    void testSameInputGeneratesSameCode() {
        // 同一长链 + 同 salt 应生成相同短码（确定性）
        String url = "https://www.example.com/stable";
        String c1 = ShortCodeGenerator.generate(url, 7);
        String c2 = ShortCodeGenerator.generate(url, 7);
        assertEquals(c1, c2, "SHA-256 输入相同应输出相同");
    }

    @Test
    void testNoCollisionForLargeBatch() {
        // 1 万条数据测试碰撞率
        int n = 10_000;
        Set<String> codes = new HashSet<>(n);
        for (int i = 0; i < n; i++) {
            String code = ShortCodeGenerator.generate("https://example.com/u/" + i, 7);
            assertNotNull(code);
            codes.add(code);
        }
        double uniqueRatio = (double) codes.size() / n;
        // 7位 Base62 = 62^7 ≈ 3.5 万亿空间，1 万条碰撞概率应 ≈ 0
        assertTrue(uniqueRatio > 0.999, "1 万条数据碰撞率过高: uniqueRatio=" + uniqueRatio);
    }

    @Test
    void testBlankInputRejected() {
        assertThrows(IllegalArgumentException.class, () -> ShortCodeGenerator.generate(null));
        assertThrows(IllegalArgumentException.class, () -> ShortCodeGenerator.generate(""));
    }
}
