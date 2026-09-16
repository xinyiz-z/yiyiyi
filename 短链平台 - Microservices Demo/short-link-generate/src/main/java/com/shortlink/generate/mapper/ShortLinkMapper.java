package com.shortlink.generate.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.shortlink.generate.entity.ShortLink;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface ShortLinkMapper extends BaseMapper<ShortLink> {

    /**
     * 根据长链哈希查询（幂等查重用）。
     */
    ShortLink selectByUrlHash(@Param("urlHash") String urlHash);

    /**
     * 根据短码查询。
     */
    ShortLink selectByShortCode(@Param("shortCode") String shortCode);

    /**
     * 原子自增点击数（用于跳转服务异步累加，避免行锁竞争）。
     */
    int incrementClickCount(@Param("shortCode") String shortCode, @Param("delta") long delta);
}
