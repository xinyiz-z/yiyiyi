-- =====================================================
-- 短链平台 - 数据库初始化脚本
-- =====================================================

CREATE DATABASE IF NOT EXISTS short_link
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE short_link;

DROP TABLE IF EXISTS t_short_link;

CREATE TABLE t_short_link (
    id            BIGINT       NOT NULL COMMENT '雪花算法主键',
    short_code    VARCHAR(16)  NOT NULL COMMENT '短码（Base62 6~8 位）',
    long_url      VARCHAR(2048) NOT NULL COMMENT '原始长链',
    url_hash      CHAR(64)     NOT NULL COMMENT '长链 SHA-256（幂等去重）',
    short_url     VARCHAR(256) NOT NULL COMMENT '短链完整 URL',
    expire_time   DATETIME     DEFAULT NULL COMMENT '过期时间，NULL=永不过期',
    status        TINYINT      NOT NULL DEFAULT 1 COMMENT '1-有效 0-禁用',
    click_count   BIGINT       NOT NULL DEFAULT 0 COMMENT '累计点击数',
    created_by    VARCHAR(64)  DEFAULT NULL COMMENT '创建者',
    created_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted       TINYINT      NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    version       INT          NOT NULL DEFAULT 0 COMMENT '乐观锁版本',
    PRIMARY KEY (id),
    UNIQUE KEY uniq_short_code (short_code),
    UNIQUE KEY uniq_url_hash   (url_hash),
    KEY idx_expire_time (expire_time),
    KEY idx_created_time (created_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='短链映射表';

-- =====================================================
-- 初始化测试数据（可选）
-- =====================================================
-- INSERT INTO t_short_link (short_code, long_url, url_hash, short_url, status)
-- VALUES ('test01', 'https://www.example.com/very/long/path', '<sha256>', 'http://s.local/test01', 1);
