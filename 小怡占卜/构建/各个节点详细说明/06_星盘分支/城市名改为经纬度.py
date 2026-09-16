# -*- coding: utf-8 -*-
"""
小怡占卜 · 城市名改为经纬度节点
Coze 代码节点配置说明：
1. 输入变量：city (String)
2. 输出变量：coordinates (JSON), location_name (String)
"""

import json


# 城市坐标数据库
CITY_COORDINATES = {
    # 一线城市
    "北京": (39.9042, 116.4074, "中国"),
    "上海": (31.2304, 121.4737, "中国"),
    "广州": (23.1291, 113.2644, "中国"),
    "深圳": (22.5431, 114.0579, "中国"),
    # 省会城市
    "天津": (39.3434, 117.3616, "中国"),
    "重庆": (29.4316, 106.9123, "中国"),
    "成都": (30.5728, 104.0668, "中国"),
    "杭州": (30.2741, 120.1551, "中国"),
    "武汉": (30.5928, 114.3055, "中国"),
    "南京": (32.0603, 118.7969, "中国"),
    "西安": (34.3416, 108.9398, "中国"),
    "长沙": (28.2282, 112.9388, "中国"),
    "郑州": (34.7466, 113.6253, "中国"),
    "沈阳": (41.8057, 123.4328, "中国"),
    "青岛": (36.0671, 120.3826, "中国"),
    "济南": (36.6512, 117.1201, "中国"),
    "哈尔滨": (45.8038, 126.5340, "中国"),
    "长春": (43.8171, 125.3235, "中国"),
    "石家庄": (38.0428, 114.5149, "中国"),
    "太原": (37.8706, 112.5489, "中国"),
    "南昌": (28.6829, 115.8579, "中国"),
    "福州": (26.0745, 119.2965, "中国"),
    "贵阳": (26.6470, 106.6302, "中国"),
    "昆明": (25.0406, 102.7129, "中国"),
    "南宁": (22.8170, 108.3665, "中国"),
    "兰州": (36.0611, 103.8343, "中国"),
    "乌鲁木齐": (43.8256, 87.6168, "中国"),
    "海口": (20.0444, 110.3497, "中国"),
    # 主要城市
    "苏州": (31.2989, 120.5853, "中国"),
    "宁波": (29.8683, 121.5440, "中国"),
    "厦门": (24.4798, 118.0894, "中国"),
    "大连": (38.9140, 121.6147, "中国"),
    "无锡": (31.4912, 120.3119, "中国"),
    "温州": (28.0006, 120.6994, "中国"),
    "南通": (31.9807, 120.8942, "中国"),
    "佛山": (23.0218, 113.1219, "中国"),
    "合肥": (31.8206, 117.2272, "中国"),
    "东莞": (23.0205, 113.7518, "中国"),
    "珠海": (22.2710, 113.5767, "中国"),
    "三亚": (18.2528, 109.5117, "中国"),
    "丽江": (26.8721, 100.2289, "中国"),
    # 港澳台
    "香港": (22.3193, 114.1694, "中国香港"),
    "澳门": (22.1987, 113.5439, "中国澳门"),
    "台北": (25.0330, 121.5654, "中国台湾"),
    # 海外
    "纽约": (40.7128, -74.0060, "美国"),
    "伦敦": (51.5074, -0.1278, "英国"),
    "巴黎": (48.8566, 2.3522, "法国"),
    "东京": (35.6762, 139.6503, "日本"),
    "首尔": (37.5665, 126.9780, "韩国"),
    "新加坡": (1.3521, 103.8198, "新加坡"),
}


def normalize_city(city: str) -> str:
    """标准化城市名称"""
    if not city:
        return ""
    city = city.strip()
    if city.endswith("市"):
        city = city[:-1]
    if "香港" in city:
        return "香港"
    if "澳门" in city:
        return "澳门"
    if "台湾" in city or "台北" in city:
        return "台北"
    return city


def get_coordinates(city: str) -> dict:
    """获取城市坐标"""
    if not city:
        return {"latitude": 39.9042, "longitude": 116.4074, "city": "未知", "country": "中国"}
    
    normalized = normalize_city(city)
    
    if normalized in CITY_COORDINATES:
        lat, lon, country = CITY_COORDINATES[normalized]
        return {"latitude": lat, "longitude": lon, "city": normalized, "country": country}
    
    # 模糊匹配
    for name, (lat, lon, country) in CITY_COORDINATES.items():
        if name in normalized or normalized in name:
            return {"latitude": lat, "longitude": lon, "city": name, "country": country}
    
    return {"latitude": 39.9042, "longitude": 116.4074, "city": normalized, "country": "中国"}


async def main(params: dict) -> dict:
    """入口函数"""
    if not isinstance(params, dict):
        return {"coordinates": json.dumps({"error": "params 不是字典"}, ensure_ascii=False), "location_name": "未知"}
    
    try:
        city = params.get("city", "")
        result = get_coordinates(city)
        return {"coordinates": json.dumps(result, ensure_ascii=False), "location_name": result.get("city", city)}
    except Exception as e:
        return {"coordinates": json.dumps({"error": str(e)}, ensure_ascii=False), "location_name": "未知"}


if __name__ == "__main__":
    import asyncio
    for city in ["上海", "东京", "unknown"]:
        result = asyncio.run(main({"city": city}))
        print(f"{city} -> {result}")
