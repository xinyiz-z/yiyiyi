# -*- coding: utf-8 -*-
"""
小怡占卜 · 灵签抽签代码节点
Coze 代码节点配置说明：
1. 输入变量：query (String), profile (String, 可选)
2. 输出变量：lingsign_basic (JSON)
"""

import json
import random


# 灵签基础数据
LINGSIGNS = {
    1: {"level": "上签", "title": "锺离成道"}, 2: {"level": "下签", "title": "苏秦不第"},
    3: {"level": "中签", "title": "董永遇仙"}, 4: {"level": "中签", "title": "玉莲会十朋"},
    5: {"level": "中签", "title": "刘晨遇仙"}, 6: {"level": "中签", "title": "仁贵遇主"},
    7: {"level": "下签", "title": "苏娘走难"}, 8: {"level": "上签", "title": "姚能受职"},
    9: {"level": "中签", "title": "陶渊明归隐"}, 10: {"level": "中签", "title": "庞涓被害"},
    11: {"level": "上签", "title": "书荐姜维"}, 12: {"level": "上签", "title": "武吉遇师"},
    13: {"level": "上签", "title": "李国舅得道"}, 14: {"level": "中签", "title": "子牙弃官"},
    15: {"level": "中签", "title": "苏秦得志"}, 16: {"level": "中签", "title": "叶梦熊朝帝"},
    17: {"level": "中签", "title": "话梅止渴"}, 18: {"level": "上签", "title": "曹国舅为仙"},
    19: {"level": "中签", "title": "子仪封王"}, 20: {"level": "中签", "title": "姜太公遇文王"},
    21: {"level": "上签", "title": "李靖归山"}, 22: {"level": "中签", "title": "王孝先为民"},
    23: {"level": "中签", "title": "怀德招亲"}, 24: {"level": "下签", "title": "李德裕贬崖州"},
    25: {"level": "中签", "title": "刘基得道"}, 26: {"level": "下签", "title": "吴王爱西施"},
    27: {"level": "中签", "title": "陈情表中"}, 28: {"level": "中签", "title": "庄周梦蝴蝶"},
    29: {"level": "中签", "title": "苏秦刺股"}, 30: {"level": "中签", "title": "江遗嘱托"},
    31: {"level": "中签", "title": "佛印会东坡"}, 32: {"level": "中签", "title": "root"},
    33: {"level": "中签", "title": "page"}, 34: {"level": "中签", "title": "六出祁山"},
    35: {"level": "中签", "title": "识还珠"}, 36: {"level": "中签", "title": "王昭君出塞"},
    37: {"level": "中签", "title": "苏武牧羊"}, 38: {"level": "中签", "title": "陶渊明赏菊"},
    39: {"level": "中签", "title": "观音第三十二签"}, 40: {"level": "下签", "title": "武则天降凤凰"},
    41: {"level": "中签", "title": "李太白匹配凤凰"}, 42: {"level": "上签", "title": "行者得道"},
    43: {"level": "中签", "title": "韩非子说难"}, 44: {"level": "中签", "title": "姜子牙得志"},
    45: {"level": "上签", "title": "袁盎却座"}, 46: {"level": "上签", "title": "秦昭王连横"},
    47: {"level": "上签", "title": "陆士衔得志"}, 48: {"level": "中签", "title": "郑国泰平"},
    49: {"level": "上签", "title": "班超归玉门关"}, 50: {"level": "上签", "title": "黄忠得令"},
    51: {"level": "上签", "title": "韩信破齐"}, 52: {"level": "中签", "title": "赵孝争楚"},
    53: {"level": "中签", "title": "萧何追韩信"}, 54: {"level": "下签", "title": "陈桥兵变"},
    55: {"level": "中签", "title": "赵匡胤困河东"}, 56: {"level": "中签", "title": "张良访张天师"},
    57: {"level": "中签", "title": "张天师托关"}, 58: {"level": "中签", "title": "苻坚侵晋"},
    59: {"level": "中签", "title": "苻坚望阵"}, 60: {"level": "中签", "title": "郑却说三计"},
    61: {"level": "中签", "title": "张良受书"}, 62: {"level": "中签", "title": "东庭老子"},
    63: {"level": "中签", "title": "王母寿诞"}, 64: {"level": "中签", "title": "张天师亲传"},
    65: {"level": "中签", "title": "张天师七试赵升"}, 66: {"level": "中签", "title": "凤凰枝"},
    67: {"level": "中签", "title": "赵上升"}, 68: {"level": "中签", "title": "红灯大使"},
    69: {"level": "下签", "title": "高君保归队"}, 70: {"level": "下签", "title": "三战吕布"},
    71: {"level": "中签", "title": "病龙行雨"}, 72: {"level": "中签", "title": "五关斩将"},
    73: {"level": "上签", "title": "孔明求计"}, 74: {"level": "中签", "title": "谢安石柄政"},
    75: {"level": "中签", "title": "八仙看云"}, 76: {"level": "中签", "title": "陈平游春"},
    77: {"level": "中签", "title": "陈平卖卦"}, 78: {"level": "中签", "title": "袁安卧雪"},
    79: {"level": "中签", "title": "三藏取经"}, 80: {"level": "上签", "title": "郭威即位"},
    81: {"level": "上签", "title": "风送滕王阁"}, 82: {"level": "中签", "title": "火烧葫芦谷"},
    83: {"level": "中签", "title": "诸葛隐卧龙岗"}, 84: {"level": "中签", "title": "庄子试妻"},
    85: {"level": "中签", "title": "程咬金遇赦"}, 86: {"level": "上签", "title": "秦琼卖马"},
    87: {"level": "中签", "title": "武侯伐魏"}, 88: {"level": "中签", "title": "高文定遇女"},
    89: {"level": "上签", "title": "班超封侯"}, 90: {"level": "中签", "title": "杨文广陷柳州"},
    91: {"level": "中签", "title": "赵子龙救阿斗"}, 92: {"level": "中签", "title": "蔡卿报恩"},
    93: {"level": "中签", "title": "高怀德卖剑"}, 94: {"level": "中签", "title": "伯牙碎琴"},
    95: {"level": "中签", "title": "张飞遇严颜"}, 96: {"level": "中签", "title": "山涛见王衍"},
    97: {"level": "中签", "title": "买臣负薪"}, 98: {"level": "中签", "title": "管鲍分金"},
    99: {"level": "中签", "title": "百里奚认妻"}, 100: {"level": "上签", "title": "三诏出山"},
}


def draw_lottery() -> int:
    """随机抽取一支灵签"""
    return random.randint(1, 100)


def get_level_emoji(level: str) -> str:
    """获取签等级表情"""
    return {"上签": "🌟", "中签": "✨", "下签": "🌙"}.get(level, "")


async def main(params: dict) -> dict:
    """入口函数"""
    if not isinstance(params, dict):
        return {"lingsign_basic": json.dumps({"error": "params 不是字典"}, ensure_ascii=False)}
    
    try:
        query = params.get("query", "")
        number = draw_lottery()
        sign_info = LINGSIGNS.get(number, {})
        
        result = {
            "number": number,
            "level": sign_info.get("level", "未知"),
            "title": sign_info.get("title", "未知"),
            "question": query,
            "level_emoji": get_level_emoji(sign_info.get("level", ""))
        }
        
        return {"lingsign_basic": json.dumps(result, ensure_ascii=False)}
    except Exception as e:
        return {"lingsign_basic": json.dumps({"error": str(e)}, ensure_ascii=False)}


if __name__ == "__main__":
    import asyncio
    for q in ["事业运如何？", "求财", "感情"]:
        result = asyncio.run(main({"query": q}))
        data = json.loads(result["lingsign_basic"])
        print(f"心愿: {q} -> 第{data['number']}签 · {data['level']} · {data['title']}")
