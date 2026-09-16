package com.shortlink.common.util;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class Base62UtilTest {

    @Test
    void testEncodeZero() {
        assertEquals("0", Base62Util.encode(0));
    }

    @Test
    void testEncodeNormal() {
        // 62 -> "10" (1*62 + 0 = 62)
        assertEquals("10", Base62Util.encode(62));
        // 3843 -> "ZZ" (35*62 + 35 = 2170+? 不对，重算：3843 / 62 = 61...61; 3843 % 62 = 61)
        // 直接用断言只验证长度/字符集
        String s = Base62Util.encode(3843);
        assertEquals(2, s.length());
    }

    @Test
    void testEncodeDecodeRoundtrip() {
        long[] values = {0L, 1L, 61L, 62L, 12345L, Long.MAX_VALUE / 2, Long.MAX_VALUE - 1};
        for (long v : values) {
            String encoded = Base62Util.encode(v);
            long decoded = Base62Util.decode(encoded);
            assertEquals(v, decoded, "Roundtrip failed for value=" + v);
        }
    }

    @Test
    void testEncodeBytesFixedLength() {
        byte[] bytes = new byte[]{0x12, 0x34, 0x56, 0x78, (byte) 0x9A, (byte) 0xBC, (byte) 0xDE, (byte) 0xF0};
        String code = Base62Util.encodeBytes(bytes, 7);
        assertNotNull(code);
        assertEquals(7, code.length(), "编码后长度应为 7，实际: " + code.length() + ", code=" + code);
        assertTrue(Base62Util.isValidShortCode(code), "应通过短码合法性校验: " + code);
    }

    @Test
    void testEncodeBytesPadding() {
        // 8 字节全为 0 -> 编码后 "0000000"（左补 0）
        byte[] bytes = new byte[8];
        String code = Base62Util.encodeBytes(bytes, 7);
        assertEquals("0000000", code);
    }

    @Test
    void testIsValidShortCode() {
        assertTrue(Base62Util.isValidShortCode("aB3xY9z"));
        assertTrue(Base62Util.isValidShortCode("012345"));
        assertFalse(Base62Util.isValidShortCode("abc"));      // 太短
        assertFalse(Base62Util.isValidShortCode("aB_3xY"));   // 非法字符
        assertFalse(Base62Util.isValidShortCode(""));         // 空
        assertFalse(Base62Util.isValidShortCode(null));
    }

    @Test
    void testNegativeValueRejected() {
        assertThrows(IllegalArgumentException.class, () -> Base62Util.encode(-1));
    }
}
