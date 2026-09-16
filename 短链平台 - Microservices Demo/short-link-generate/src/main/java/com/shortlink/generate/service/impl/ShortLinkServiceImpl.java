package com.shortlink.generate.service.impl;

import com.shortlink.common.dto.ShortLinkCacheDTO;
import com.shortlink.common.exception.BizException;
import com.shortlink.common.result.Result;
import com.shortlink.common.result.ResultCode;
import com.shortlink.common.util.ShortCodeGenerator;
import com.shortlink.common.util.UrlValidator;
import com.shortlink.generate.dto.GenerateRequest;
import com.shortlink.generate.dto.GenerateResponse;
import com.shortlink.generate.entity.ShortLink;
import com.shortlink.generate.mapper.ShortLinkMapper;
import com.shortlink.generate.service.ShortLinkService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.HexFormat;
import java.util.concurrent.TimeUnit;

/**
 * 短链生成核心服务。
 *
 * <h3>生成流程</h3>
 * <pre>
 *   1. 校验长链合法性
 *   2. 计算 urlHash（SHA-256）
 *   3. Redis 查重 → MySQL 查重（同一长链幂等）
 *   4. 命中 → 直接返回
 *   5. 未命中 → ShortCodeGenerator 生成短码（SHA-256 + Base62）
 *   6. 写 MySQL（捕获唯一约束冲突 → 重试）
 *   7. 写 Redis 缓存
 *   8. 返回结果
 * </pre>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ShortLinkServiceImpl implements ShortLinkService {

    private final ShortLinkMapper shortLinkMapper;
    private final RedisTemplate<String, Object> redisTemplate;

    @Value("${shortlink.short-domain}")
    private String shortDomain;

    @Value("${shortlink.cache-key-prefix}")
    private String cacheKeyPrefix;

    @Value("${shortlink.url-hash-prefix}")
    private String urlHashPrefix;

    @Value("${shortlink.cache-ttl-seconds}")
    private long cacheTtlSeconds;

    @Value("${shortlink.code-length:7}")
    private int codeLength;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Result<GenerateResponse> generate(GenerateRequest request) {
        // 1. 校验
        String urlErr = UrlValidator.validate(request.getLongUrl());
        if (urlErr != null) {
            return Result.fail(ResultCode.LONG_URL_INVALID.getCode(), urlErr);
        }
        String longUrl = request.getLongUrl().trim();

        // 2. 计算长链哈希
        String urlHash = sha256Hex(longUrl);

        // 3. Redis 缓存查重（O(1)）
        String hashCacheKey = urlHashPrefix + urlHash;
        Object cachedCode = redisTemplate.opsForValue().get(hashCacheKey);
        if (cachedCode instanceof String codeStr && !codeStr.isEmpty()) {
            ShortLink exist = shortLinkMapper.selectByShortCode(codeStr);
            if (exist != null) {
                log.info("[Generate] 缓存命中 urlHash={}, shortCode={}", urlHash, codeStr);
                return Result.success(toResponse(exist));
            }
        }

        // 4. DB 查重
        ShortLink exist = shortLinkMapper.selectByUrlHash(urlHash);
        if (exist != null) {
            log.info("[Generate] DB 命中 urlHash={}, shortCode={}", urlHash, exist.getShortCode());
            cacheHashMapping(urlHash, exist.getShortCode());
            cacheShortCode(exist);
            return Result.success(toResponse(exist));
        }

        // 5. 生成短码（最多重试 5 次碰撞）
        LocalDateTime expireTime = request.getExpireTime();
        ShortLink saved = null;
        for (int attempt = 0; attempt < ShortCodeGenerator.MAX_RETRY; attempt++) {
            String shortCode = ShortCodeGenerator.generate(longUrl, codeLength);
            if (shortCode == null) {
                continue;
            }
            ShortLink link = buildEntity(shortCode, longUrl, urlHash, expireTime, request.getCreatedBy());
            try {
                shortLinkMapper.insert(link);
                saved = link;
                break;
            } catch (DuplicateKeyException e) {
                log.warn("[Generate] 短码碰撞, shortCode={}, attempt={}", shortCode, attempt + 1);
                ShortLink raceWinner = shortLinkMapper.selectByUrlHash(urlHash);
                if (raceWinner != null) {
                    saved = raceWinner;
                    break;
                }
            }
        }
        if (saved == null) {
            log.error("[Generate] 短码生成失败 urlHash={}", urlHash);
            return Result.fail(ResultCode.SHORT_CODE_GENERATE_FAILED);
        }

        // 6. 写缓存
        cacheHashMapping(urlHash, saved.getShortCode());
        cacheShortCode(saved);

        log.info("[Generate] 生成成功 longUrl={}, shortCode={}", longUrl, saved.getShortCode());
        return Result.success(toResponse(saved));
    }

    @Override
    public Result<ShortLink> getByShortCode(String shortCode) {
        if (shortCode == null || shortCode.isBlank()) {
            return Result.fail(ResultCode.BAD_REQUEST.getCode(), "shortCode 不能为空");
        }
        // 先查缓存（统一缓存 DTO）
        String key = cacheKeyPrefix + shortCode;
        Object cached = redisTemplate.opsForValue().get(key);
        if (cached instanceof ShortLinkCacheDTO dto) {
            // 从 DTO 重建 ShortLink（缺失字段用默认值，DB 才是 source of truth）
            ShortLink stub = new ShortLink();
            stub.setShortCode(dto.getShortCode());
            stub.setLongUrl(dto.getLongUrl());
            stub.setExpireTime(dto.getExpireTime());
            stub.setStatus(dto.getStatus());
            return Result.success(stub);
        }
        ShortLink link = shortLinkMapper.selectByShortCode(shortCode);
        if (link == null) {
            return Result.fail(ResultCode.SHORT_LINK_NOT_FOUND);
        }
        cacheShortCode(link);
        return Result.success(link);
    }

    @Override
    public Result<ShortLink> getByUrlHash(String urlHash) {
        ShortLink link = shortLinkMapper.selectByUrlHash(urlHash);
        return link == null ? Result.fail(ResultCode.SHORT_LINK_NOT_FOUND) : Result.success(link);
    }

    // ====================== 私有方法 ======================

    private ShortLink buildEntity(String shortCode, String longUrl, String urlHash,
                                  LocalDateTime expireTime, String createdBy) {
        ShortLink link = new ShortLink();
        link.setShortCode(shortCode);
        link.setLongUrl(longUrl);
        link.setUrlHash(urlHash);
        link.setShortUrl(shortDomain + shortCode);
        link.setExpireTime(expireTime);
        link.setStatus(1);
        link.setClickCount(0L);
        link.setCreatedBy(createdBy);
        return link;
    }

    private void cacheHashMapping(String urlHash, String shortCode) {
        try {
            redisTemplate.opsForValue().set(
                    urlHashPrefix + urlHash, shortCode, cacheTtlSeconds, TimeUnit.SECONDS);
        } catch (Exception e) {
            log.warn("[Cache] 写 urlHash 缓存失败, err={}", e.getMessage());
        }
    }

    private void cacheShortCode(ShortLink link) {
        try {
            String key = cacheKeyPrefix + link.getShortCode();
            long ttl = cacheTtlSeconds;
            if (link.getExpireTime() != null) {
                long remain = Duration.between(LocalDateTime.now(), link.getExpireTime()).getSeconds();
                if (remain > 0) {
                    ttl = Math.min(ttl, remain);
                }
            }
            // 跨服务一致：写入精简 DTO，避免 redirect 反序列化时类型不匹配
            ShortLinkCacheDTO dto = toCacheDTO(link);
            redisTemplate.opsForValue().set(key, dto, ttl, TimeUnit.SECONDS);
        } catch (Exception e) {
            log.warn("[Cache] 写 shortCode 缓存失败, err={}", e.getMessage());
        }
    }

    private ShortLinkCacheDTO toCacheDTO(ShortLink link) {
        return ShortLinkCacheDTO.builder()
                .shortCode(link.getShortCode())
                .longUrl(link.getLongUrl())
                .expireTime(link.getExpireTime())
                .status(link.getStatus())
                .build();
    }

    private GenerateResponse toResponse(ShortLink link) {
        return GenerateResponse.builder()
                .shortCode(link.getShortCode())
                .shortUrl(link.getShortUrl())
                .longUrl(link.getLongUrl())
                .expireTime(link.getExpireTime())
                .createdTime(link.getCreatedTime())
                .build();
    }

    /**
     * SHA-256 哈希（用于幂等去重 key）。
     */
    public static String sha256Hex(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(input.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new BizException("SHA-256 算法不可用", e);
        }
    }
}
