package com.shortlink.generate.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serial;
import java.io.Serializable;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateResponse implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    /** 短码 */
    private String shortCode;

    /** 短链完整 URL */
    private String shortUrl;

    /** 原始长链 */
    private String longUrl;

    /** 过期时间 */
    private LocalDateTime expireTime;

    /** 创建时间 */
    private LocalDateTime createdTime;
}
