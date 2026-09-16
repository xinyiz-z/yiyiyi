package com.shortlink.common.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serial;
import java.io.Serializable;
import java.time.LocalDateTime;

/**
 * Redis 缓存中的轻量级短链 DTO（generate / redirect 共用）。
 * <p>
 * 只包含跳转所需字段，避免缓存全表字段浪费内存。
 * <p>
 * 跨服务缓存一致性：本 DTO 必须在 common 模块定义，使两个服务序列化的 JSON 结构一致，
 * 否则 generate 写入的 ShortLink 类型在 redirect 反序列化时类型不匹配，会导致缓存命中率低。
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ShortLinkCacheDTO implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    private String shortCode;

    private String longUrl;

    private LocalDateTime expireTime;

    private Integer status;
}