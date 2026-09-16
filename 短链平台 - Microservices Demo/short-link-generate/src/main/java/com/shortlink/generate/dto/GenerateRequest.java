package com.shortlink.generate.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.io.Serial;
import java.io.Serializable;
import java.time.LocalDateTime;

@Data
public class GenerateRequest implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    /** 原始长链 */
    @NotBlank(message = "长链不能为空")
    @Size(max = 2048, message = "长链长度不能超过 2048")
    private String longUrl;

    /** 过期时间（可选，默认永不过期） */
    private LocalDateTime expireTime;

    /** 创建者（可选） */
    private String createdBy;
}
