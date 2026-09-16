# -*- coding: utf-8 -*-
"""
小怡占卜 · 用户画像补全节点

Coze 代码节点配置说明：
1. 输入变量（请按下面名字配置）：
   - birthday       →  开始.birthday  （Number / String，支持各种格式，见下）
   - city           →  开始.city      （String，可选）
   - sex            →  开始.sex       （String，可选）
   - nickname       →  开始.nickname  （String，可选）
   - calendar_type  →  意图识别.calendar_type  （String，可选："solar" / "lunar" / "auto"，默认 auto）

2. 支持的生日写法（代码都能解析）：
   阳历：2004.11.22 / 2004年11月22号 / 2004/11/22 / 20041122 / 时间戳(秒或毫秒) / 2004年11月
   农历：农历2004年10月初八 / 阴历2004.10.8 / 农历2004-10-08
   - 农历会自动转成阳历，再算星座 / 生肖 / 生命数字。

3. 输出变量：
   - profile   →  String（JSON 字符串，birthday 字段统一为阳历 YYYY-MM-DD）

返回示例：
{
    "nickname": "小雅",
    "sex": "女",
    "city": "上海",
    "birthday": "1995-08-15",
    "sign": "狮子座",
    "zodiac": "猪",
    "life_number": "11"
}
"""

import json
import re
from datetime import datetime, timedelta


# ============================================================
# 农历数据（1900-2100，纯标准库，无需第三方依赖）
# 每项含义（位布局，公开标准表）：
#   bit4~15    : 农历 1~12 月大小月（bit(16-m) 对应第 m 月；1=大月30天，0=小月29天）
#   bit16      : 闰月大小月（1=大月30天，0=小月29天）
#   bit0~3     : 闰月月份（1~12，0=当年无闰月）
#   数据由 cnlunar 真值（1901-2099）校准生成，1900 年用公认值 0x04bd8。
# ============================================================
LUNAR_INFO = [
    0x4bd8, 0x4ae0, 0xa570, 0x54d5, 0xd260, 0xd950, 0x16554, 0x56a0, 0x9ad0, 0x55d2,
    0x4ae0, 0xa5b6, 0xa4d0, 0xd250, 0x1d255, 0xb540, 0xd6a0, 0xada2, 0x95b0, 0x14977,
    0x4970, 0xa4b0, 0xb4b5, 0x6a50, 0x6d40, 0x1ab54, 0x2b60, 0x9570, 0x52f2, 0x4970,
    0x6566, 0xd4a0, 0xea50, 0x16a95, 0x5ad0, 0x2b60, 0x186e3, 0x92e0, 0x1c8d7, 0xc950,
    0xd4a0, 0x1d8a6, 0xb550, 0x56a0, 0x1a5b4, 0x25d0, 0x92d0, 0xd2b2, 0xa950, 0xb557,
    0x6ca0, 0xb550, 0x15355, 0x4da0, 0xa5b0, 0x14573, 0x52b0, 0xa9a8, 0xe950, 0x6aa0,
    0xaea6, 0xab50, 0x4b60, 0xaae4, 0xa570, 0x5260, 0xf263, 0xd950, 0x5b57, 0x56a0,
    0x96d0, 0x4dd5, 0x4ad0, 0xa4d0, 0xd4d4, 0xd250, 0xd558, 0xb540, 0xb6a0, 0x195a6,
    0x95b0, 0x49b0, 0xa974, 0xa4b0, 0xb27a, 0x6a50, 0x6d40, 0xaf46, 0xab60, 0x9570,
    0x4af5, 0x4970, 0x64b0, 0x74a3, 0xea50, 0x6b58, 0x5ac0, 0xab60, 0x96d5, 0x92e0,
    0xc960, 0xd954, 0xd4a0, 0xda50, 0x7552, 0x56a0, 0xabb7, 0x25d0, 0x92d0, 0xcab5,
    0xa950, 0xb4a0, 0xbaa4, 0xad50, 0x55d9, 0x4ba0, 0xa5b0, 0x15176, 0x52b0, 0xa930,
    0x7954, 0x6aa0, 0xad50, 0x5b52, 0x4b60, 0xa6e6, 0xa4e0, 0xd260, 0xea65, 0xd530,
    0x5aa0, 0x76a3, 0x96d0, 0x4afb, 0x4ad0, 0xa4d0, 0x1d0b6, 0xd250, 0xd520, 0xdd45,
    0xb5a0, 0x56d0, 0x55b2, 0x49b0, 0xa577, 0xa4b0, 0xaa50, 0x1b255, 0x6d20, 0xada0,
    0x14b63, 0x9370, 0x49f8, 0x4970, 0x64b0, 0x168a6, 0xea50, 0x6aa0, 0x1a6c4, 0xaae0,
    0x92e0, 0xd2e3, 0xc960, 0xd557, 0xd4a0, 0xda50, 0x5d55, 0x56a0, 0xa6d0, 0x55d4,
    0x52d0, 0xa9b8, 0xa950, 0xb4a0, 0xb6a6, 0xad50, 0x55a0, 0xaba4, 0xa5b0, 0x52b0,
    0xb273, 0x6930, 0x7337, 0x6aa0, 0xad50, 0x14b55, 0x4b60, 0xa570, 0x54e4, 0xd160,
    0xe968, 0xd520, 0xdaa0, 0x16aa6, 0x56d0, 0x4ae0, 0xa9d4, 0xa2d0, 0xd150, 0xf242,
]


def l_year_days(y):
    """农历 y 年总天数（含闰月）。"""
    info = LUNAR_INFO[y - 1900]
    days = 348  # 12 * 29
    i = 0x8000
    while i > 0x8:
        if info & i:
            days += 1
        i >>= 1
    return days + l_leap_days(y)


def l_leap_month(y):
    """当年闰月月份（1~12，0=无闰月）。"""
    return LUNAR_INFO[y - 1900] & 0xf


def l_leap_days(y):
    """当年闰月天数（0=无闰月）。"""
    if l_leap_month(y) == 0:
        return 0
    return 30 if (LUNAR_INFO[y - 1900] >> 16) & 1 else 29


def l_month_days(y, m):
    """农历 y 年 m 月（非闰月）天数。位布局：bit(16-m) 表示第 m 月大小。"""
    return 30 if (LUNAR_INFO[y - 1900] & (0x10000 >> m)) else 29


def lunar_to_solar(ly, lm, ld, is_leap=False):
    """农历转阳历。返回 datetime 或 None。"""
    if ly < 1900 or ly > 2099:
        return None
    base = datetime(1900, 1, 31)  # 1900 年正月初一
    offset = 0
    for y in range(1900, ly):
        offset += l_year_days(y)
    leap = l_leap_month(ly)
    for m in range(1, lm):
        offset += l_month_days(ly, m)
        if leap != 0 and m == leap:
            offset += l_leap_days(ly)
    if is_leap:
        offset += l_leap_days(ly)
    offset += ld - 1
    return base + timedelta(days=offset)


def solar_to_lunar(d):
    """阳历转农历。返回 (年, 月, 日, 是否闰月) 或 None。"""
    base = datetime(1900, 1, 31)
    if d < base:
        return None
    offset = (d - base).days
    ly = 1900
    while offset >= l_year_days(ly):
        offset -= l_year_days(ly)
        ly += 1
        if ly > 2099:
            return None
    leap = l_leap_month(ly)
    is_leap = False
    lm = 1
    for m in range(1, 13):
        days = l_month_days(ly, m)
        if offset < days:
            lm = m
            break
        offset -= days
        if leap != 0 and m == leap:
            if offset < l_leap_days(ly):
                lm = m
                is_leap = True
                break
            offset -= l_leap_days(ly)
    ld = offset + 1
    return (ly, lm, ld, is_leap)


def safe_string(value):
    """把空值统一处理成空字符串。"""
    if value is None:
        return ""
    return str(value).strip()


def parse_birthday(birthday, calendar_type="auto"):
    """
    把各种生日格式解析成阳历 datetime。
    支持：Unix 毫秒/秒时间戳、YYYYMMDD 数字、各种分隔的字符串、农历写法（含中文日）。
    calendar_type: "solar" / "lunar" / "auto"（auto 时若含农历关键词则按农历）。
    """
    if birthday is None or birthday == "":
        return None

    s = safe_string(birthday)

    if calendar_type == "auto":
        if re.search(r"农历|阴历|旧历|农厉|闰.*月|腊月|冬月|正月|初[一二三四五六七八九十]|廿|卅", s):
            calendar_type = "lunar"
        else:
            calendar_type = "solar"

    # 数字类型：可能是时间戳或 YYYYMMDD
    if isinstance(birthday, (int, float)):
        ts = int(birthday)
        if ts > 1e10:
            return datetime.fromtimestamp(ts / 1000)
        if ts > 1e8:
            return datetime.fromtimestamp(ts)
        # YYYYMMDD 数字，如 19950815
        m = re.match(r"(\d{4})(\d{2})(\d{2})", str(ts).zfill(8))
        if m and calendar_type == "solar":
            try:
                return datetime(int(m.group(1)), int(m.group(2)), int(m.group(3)))
            except Exception:
                return None
        return None

    # 字符串类型：归一化分隔符（处理 . / 年 月 日 号 等）
    norm = (
        s.replace("年", "-").replace("月", "-").replace("日", "")
        .replace("号", "").replace("。", "").replace("/", "-")
        .replace(".", "-").replace("、", "-").replace(" ", "-")
        .strip("-")
    )

    nums = re.findall(r"\d+", norm)

    # 单串数字：可能是时间戳字符串，或只有年份（农历时可能配中文月日）
    if len(nums) == 1:
        try:
            ts = int(nums[0])
            if ts > 1e10:
                return datetime.fromtimestamp(ts / 1000)
            if ts > 1e8:
                return datetime.fromtimestamp(ts)
        except Exception:
            pass
        if calendar_type == "lunar":
            md = _lunar_cn_md(s)
            if md:
                return lunar_to_solar(int(nums[0]), md[0], md[1], False)
        return None

    # 年 + 月 + 日
    if len(nums) >= 3:
        y, mo, d = int(nums[0]), int(nums[1]), int(nums[2])
        if calendar_type == "lunar":
            return lunar_to_solar(y, mo, d, False)
        try:
            return datetime(y, mo, d)
        except Exception:
            return None

    # 只有年 + 月：日默认 1 号；农历时尝试从中文（初八/廿三）提取日
    if len(nums) == 2:
        y, mo = int(nums[0]), int(nums[1])
        if calendar_type == "lunar":
            cn_day = _lunar_cn_day(s)
            return lunar_to_solar(y, mo, cn_day if cn_day else 1, False)
        try:
            return datetime(y, mo, 1)
        except Exception:
            return None

    return None


_CN_D = {"一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5,
         "六": 6, "七": 7, "八": 8, "九": 9}


def _cn_day(tok):
    """把单个中文数字日（初八/十/十一/廿三/卅）转成 int。"""
    t = tok.replace("初", "").replace("号", "")
    if t == "十":
        return 10
    if t == "二十":
        return 20
    if t in ("三十", "卅"):
        return 30
    if t.startswith("十"):
        return 10 + (_CN_D.get(t[1:]) or 0)
    if t.startswith("廿"):
        return 20 + (_CN_D.get(t[1:]) or 0)
    if t.startswith("卅"):
        return 30 + (_CN_D.get(t[1:]) or 0)
    return _CN_D.get(t)


def _lunar_cn_day(s):
    """从农历字符串里提取中文数字表示的「日」，如 初八 / 廿三 / 三十。无则返回 None。"""
    for p in (r"初[一二三四五六七八九十两]",
              r"十[一二三四五六七八九]?",
              r"廿[一二三四五六七八九]?",
              r"卅[一二三四五六七八九]?",
              r"二十[一二三四五六七八九]?",
              r"三十"):
        m = re.search(p, s)
        if m:
            v = _cn_day(m.group(0))
            if v:
                return v
    return None


_MONTH_CN = {"正": 1, "一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6,
             "七": 7, "八": 8, "九": 9, "十": 10, "冬": 11, "腊": 12}


def _lunar_cn_md(s):
    """农历中文「月+日」提取，如 腊月廿三 / 正月初一 / 八月十五。返回 (月, 日) 或 None。"""
    mm = re.search(r"(正|冬|腊|十[一二]?|[一二三四五六七八九])月", s)
    if not mm:
        return None
    tok = mm.group(1)
    if tok == "十":
        month = 10
    elif tok == "十一":
        month = 11
    elif tok == "十二":
        month = 12
    else:
        month = _MONTH_CN.get(tok)
    day = _lunar_cn_day(s)
    if month and day:
        return month, day
    return None


def get_zodiac(birth_date):
    """根据阳历日期返回西方星座。"""
    if not birth_date:
        return ""
    month_day = birth_date.month * 100 + birth_date.day
    zodiac_map = [
        (120, "摩羯座"),   # 12.22-1.19
        (219, "水瓶座"),   # 1.20-2.18
        (320, "双鱼座"),   # 2.19-3.20
        (420, "白羊座"),   # 3.21-4.19
        (521, "金牛座"),   # 4.20-5.20
        (622, "双子座"),   # 5.21-6.21
        (723, "巨蟹座"),   # 6.22-7.22
        (823, "狮子座"),   # 7.23-8.22
        (923, "处女座"),   # 8.23-9.22
        (1023, "天秤座"),  # 9.23-10.23
        (1122, "天蝎座"),  # 10.24-11.22
        (1221, "射手座"),  # 11.23-12.21
        (1231, "摩羯座")   # fallback
    ]
    for threshold, sign in zodiac_map:
        if month_day < threshold:
            return sign
    return "摩羯座"


def get_chinese_zodiac(birth_date):
    """
    根据农历年返回生肖。
    注意：生肖按农历年，所以先把阳历生日映射到农历年（春节分界）。
    """
    if not birth_date:
        return ""
    lun = solar_to_lunar(birth_date)
    if not lun:
        return ""
    animals = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]
    return animals[(lun[0] - 1900) % 12]


def get_life_number(birth_date):
    """
    计算生命数字（生命灵数）。
    把阳历 YYYYMMDD 各位相加，再不断化简到个位数（保留 11/22/33 大师数）。
    """
    if not birth_date:
        return ""
    s = birth_date.strftime("%Y%m%d")
    total = sum(int(d) for d in s if d.isdigit())

    def reduce_num(n):
        while n > 9 and n not in (11, 22, 33):
            n = sum(int(d) for d in str(n))
        return n

    return str(reduce_num(total))


async def main(params):
    """
    Coze 代码节点入口函数（必须是 async 协程）。
    params 是一个字典，包含你在输入区域配置的变量。
    """
    # 兜底：params 不是字典时也能报错而不是整个节点崩溃
    if not isinstance(params, dict):
        return {
            "profile": json.dumps({"error": "params 不是字典，请检查代码节点输入配置"}, ensure_ascii=False),
            "debug_params": json.dumps({"received_keys": [], "params_type": str(type(params)), "note": "params 类型异常"}, ensure_ascii=False),
        }

    # 先记录「Coze 实际传进来的所有参数名」，这是排查「输出为空」的关键
    received_keys = list(params.keys())

    try:
        birthday = params.get("birthday")
        city = safe_string(params.get("city"))
        sex = safe_string(params.get("sex"))
        nickname = safe_string(params.get("nickname"))
        calendar_type = safe_string(params.get("calendar_type")) or "auto"

        # 解析生日（自动处理农历/各种格式）
        birth_date = parse_birthday(birthday, calendar_type)

        # 组装画像
        profile = {
            "nickname": nickname,
            "sex": sex,
            "city": city,
            "birthday": birth_date.strftime("%Y-%m-%d") if birth_date else "",
            "sign": get_zodiac(birth_date),
            "zodiac": get_chinese_zodiac(birth_date),
            "life_number": get_life_number(birth_date),
        }
    except Exception as e:
        import traceback
        return {
            "profile": json.dumps({"error": str(e)}, ensure_ascii=False),
            "debug_params": json.dumps({
                "received_keys": received_keys,
                "exception": str(e),
                "trace": traceback.format_exc()[-500:],
            }, ensure_ascii=False),
        }

    # 输出 JSON 字符串，便于下游大模型解析
    # 同时附带 debug_params，方便在 Coze 里排查输入变量是否真正传入
    return {
        "profile": json.dumps(profile, ensure_ascii=False),
        "debug_params": json.dumps({
            "received_keys": received_keys,
            "birthday": birthday,
            "city": city,
            "sex": sex,
            "nickname": nickname,
            "calendar_type": calendar_type,
            "birth_date": birth_date.strftime("%Y-%m-%d") if birth_date else None,
            "hint": "若 city/sex 有值但为空字符串，说明代码节点输入参数名与这里不一致；若 birthday 只是 1990，说明上游把具体生日截断了" if (not city and not sex) or (isinstance(birthday, (int,)) and birthday < 10000) else "",
        }, ensure_ascii=False)
    }


# 本地调试示例（Coze 中不需要这段，但方便你本地测试）
if __name__ == "__main__":
    import asyncio

    test_cases = [
        {"name": "点分隔", "params": {"birthday": "2004.11.22", "city": "上海", "sex": "女", "nickname": "小雅"}},
        {"name": "年号写法", "params": {"birthday": "2004年11月22号", "city": "北京", "sex": "男", "nickname": "阿强"}},
        {"name": "斜杠", "params": {"birthday": "2004/11/22", "city": "广州"}},
        {"name": "纯数字YYYYMMDD", "params": {"birthday": 19950815, "city": "深圳", "sex": "女", "nickname": "小怡"}},
        {"name": "农历写法", "params": {"birthday": "农历2004年10月初八", "city": "重庆", "sex": "女", "nickname": "欣欣"}},
        {"name": "农历中文日", "params": {"birthday": "农历1999年腊月廿三", "city": "天津"}},
        {"name": "农历(阴历)auto", "params": {"birthday": "阴历2000.2.2", "city": "杭州"}},
        {"name": "仅年份(无法算)", "params": {"birthday": 2005, "city": "成都"}},
    ]

    for case in test_cases:
        result = asyncio.run(main(case["params"]))
        print(case["name"], "->", result)
