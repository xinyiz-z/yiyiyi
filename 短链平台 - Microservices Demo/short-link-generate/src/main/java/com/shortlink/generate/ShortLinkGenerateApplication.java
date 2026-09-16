package com.shortlink.generate;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.scheduling.annotation.EnableAsync;

/**
 * 短链生成服务启动类。
 * <p>
 * 职责：接收长链请求 → 生成短码 → 写入 MySQL 并缓存到 Redis。
 * 不负责跳转，跳转由 short-link-redirect 服务承担（读写分离，便于独立扩缩容）。
 */
@EnableAsync
@EnableDiscoveryClient
@SpringBootApplication(scanBasePackages = {"com.shortlink.generate", "com.shortlink.common"})
@MapperScan("com.shortlink.generate.mapper")
public class ShortLinkGenerateApplication {

    public static void main(String[] args) {
        SpringApplication.run(ShortLinkGenerateApplication.class, args);
    }
}
