package com.shortlink.generate.service;

import com.shortlink.common.result.Result;
import com.shortlink.generate.dto.GenerateRequest;
import com.shortlink.generate.dto.GenerateResponse;
import com.shortlink.generate.entity.ShortLink;

public interface ShortLinkService {

    /**
     * 生成短链。同一长链幂等返回同一短码。
     */
    Result<GenerateResponse> generate(GenerateRequest request);

    /**
     * 根据短码查询（用于跳转服务回源）。
     */
    Result<ShortLink> getByShortCode(String shortCode);

    /**
     * 根据长链哈希查询（幂等去重）。
     */
    Result<ShortLink> getByUrlHash(String urlHash);
}
