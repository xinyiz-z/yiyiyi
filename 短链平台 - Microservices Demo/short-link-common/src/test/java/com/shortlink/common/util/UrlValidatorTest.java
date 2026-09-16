package com.shortlink.common.util;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class UrlValidatorTest {

    @Test
    void testValidHttpUrl() {
        assertTrue(UrlValidator.isValid("http://www.example.com"));
        assertTrue(UrlValidator.isValid("https://www.example.com/path?q=1&b=2"));
        assertTrue(UrlValidator.isValid("https://api.example.com:8443/v1/users/123"));
    }

    @Test
    void testBlankUrl() {
        assertNotNull(UrlValidator.validate(null));
        assertNotNull(UrlValidator.validate(""));
        assertNotNull(UrlValidator.validate("   "));
    }

    @Test
    void testMissingScheme() {
        assertNotNull(UrlValidator.validate("www.example.com"));
        assertNotNull(UrlValidator.validate("//example.com"));
    }

    @Test
    void testDisallowedScheme() {
        assertNotNull(UrlValidator.validate("ftp://example.com"));
        assertNotNull(UrlValidator.validate("file:///etc/passwd"));
        assertNotNull(UrlValidator.validate("javascript:alert(1)"));
    }

    @Test
    void testMissingHost() {
        assertNotNull(UrlValidator.validate("https://"));
        assertNotNull(UrlValidator.validate("https:///path"));
    }

    @Test
    void testTooLongUrl() {
        StringBuilder sb = new StringBuilder("https://example.com/");
        while (sb.length() <= UrlValidator.MAX_URL_LENGTH) {
            sb.append("a");
        }
        assertNotNull(UrlValidator.validate(sb.toString()));
    }

    @Test
    void testWhitespaceTrimmed() {
        assertTrue(UrlValidator.isValid("  https://example.com  "));
    }

    @Test
    void testInvalidUrlReturnsMessage() {
        String msg = UrlValidator.validate("not-a-url");
        assertNotNull(msg);
        assertFalse(msg.isEmpty());
    }
}