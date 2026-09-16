package com.shortlink.generate.controller;

import com.shortlink.common.result.Result;
import com.shortlink.generate.dto.GenerateRequest;
import com.shortlink.generate.dto.GenerateResponse;
import com.shortlink.generate.entity.ShortLink;
import com.shortlink.generate.service.ShortLinkService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 短链生成 API。
 * <p>
 * 设计原则：本服务只承担"写"流量（生成短码），跳转流量由 short-link-redirect 服务承担。
 * 两个服务独立部署、独立扩缩容。
 */
@Slf4j
@RestController
@RequestMapping("/api/v1/short-link")
@RequiredArgsConstructor
public class ShortLinkController {

    private final ShortLinkService shortLinkService;

    /**
     * 生成短链（幂等）。同一长链重复请求返回同一短码。
     */
    @PostMapping("/generate")
    public Result<GenerateResponse> generate(@Valid @RequestBody GenerateRequest request) {
        log.debug("[API] generate request: {}", request);
        return shortLinkService.generate(request);
    }

    /**
     * 查询短链详情（按短码）。供 redirect 服务回源使用。
     */
    @GetMapping("/{shortCode}")
    public Result<ShortLink> getByShortCode(@PathVariable("shortCode") String shortCode) {
        return shortLinkService.getByShortCode(shortCode);
    }
}
