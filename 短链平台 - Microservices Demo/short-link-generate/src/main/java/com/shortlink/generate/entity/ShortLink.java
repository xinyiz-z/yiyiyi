package com.shortlink.generate.entity;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;

import java.io.Serial;
import java.io.Serializable;
import java.time.LocalDateTime;

/**
 * 短链映射实体。
 * <p>
 * 唯一性约束：
 * <ul>
 *   <li>uniq_short_code：短码唯一</li>
 *   <li>uniq_url_hash：长链哈希唯一（幂等去重）</li>
 * </ul>
 */
@Data
@TableName("t_short_link")
public class ShortLink implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    /** 主键（雪花算法） */
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;

    /** 短码（如 aB3xY9z） */
    private String shortCode;

    /** 原始长链 */
    private String longUrl;

    /** 长链 SHA-256/Murmur 哈希（用于幂等去重） */
    private String urlHash;

    /** 短链完整 URL（如 http://s.local/aB3xY9z） */
    private String shortUrl;

    /** 过期时间（NULL 表示永不过期） */
    private LocalDateTime expireTime;

    /** 状态：1-有效 0-禁用 */
    private Integer status;

    /** 访问次数（异步累加，定时 flush 到 DB） */
    private Long clickCount;

    /** 创建者 */
    private String createdBy;

    /** 创建时间 */
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdTime;

    /** 更新时间 */
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedTime;

    /** 逻辑删除标记 */
    @TableLogic
    private Integer deleted;

    /** 乐观锁版本号 */
    @Version
    private Integer version;
}
