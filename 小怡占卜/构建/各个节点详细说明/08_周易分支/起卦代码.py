# -*- coding: utf-8 -*-
"""
小怡占卜 · 起卦代码节点
1. 输入：query, profile(可选)
2. 输出：iching_data (JSON)
"""

import json
import random


# 六十四卦数据(简化版)
HEXAGRAMS = {
    1: {"name": "乾为天", "symbol": "☰☰", "judgement": "元亨利贞"},
    2: {"name": "坤为地", "symbol": "☷☷", "judgement": "元亨利牝马之贞"},
    3: {"name": "水雷屯", "symbol": "☵☳", "judgement": "元亨利贞"},
    4: {"name": "山水蒙", "symbol": "☶☵", "judgement": "亨，匪我求童蒙"},
    5: {"name": "水天需", "symbol": "☵☰", "judgement": "有孚，光亨，贞吉"},
    6: {"name": "天水讼", "symbol": "☰☵", "judgement": "有孚，窒惕"},
    7: {"name": "地水师", "symbol": "☷☵", "judgement": "贞，丈人吉"},
    8: {"name": "水地比", "symbol": "☵☷", "judgement": "吉，原筮，元贞"},
    9: {"name": "风天小畜", "symbol": "☴☰", "judgement": "亨，密云不雨"},
    10: {"name": "天泽履", "symbol": "☰☱", "judgement": "亨，履虎尾"},
    11: {"name": "地天泰", "symbol": "☷☰", "judgement": "小往大来，吉亨"},
    12: {"name": "天地否", "symbol": "☰☷", "judgement": "否之匪人"},
    13: {"name": "天火同人", "symbol": "☰☲", "judgement": "同人于野，亨"},
    14: {"name": "火天大有", "symbol": "☲☰", "judgement": "元亨"},
    15: {"name": "地山谦", "symbol": "☷☶", "judgement": "亨，君子有终"},
    16: {"name": "雷地豫", "symbol": "☳☷", "judgement": "利建侯行师"},
    17: {"name": "泽雷随", "symbol": "☱☳", "judgement": "元亨利贞，无咎"},
    18: {"name": "山风蛊", "symbol": "☶☴", "judgement": "元亨，利涉大川"},
    19: {"name": "地泽临", "symbol": "☷☱", "judgement": "元亨利贞"},
    20: {"name": "风地观", "symbol": "☴☷", "judgement": "盥而不荐"},
    21: {"name": "火雷噬嗑", "symbol": "☲☳", "judgement": "亨，利用狱"},
    22: {"name": "山火贲", "symbol": "☶☲", "judgement": "亨，小利有所往"},
    23: {"name": "山地剥", "symbol": "☷☶", "judgement": "不利有攸往"},
    24: {"name": "地雷复", "symbol": "☷☳", "judgement": "亨，出入无疾"},
    25: {"name": "天雷无妄", "symbol": "☰☳", "judgement": "元亨利贞"},
    26: {"name": "山天大畜", "symbol": "☶☰", "judgement": "利贞，不家食吉"},
    27: {"name": "山雷颐", "symbol": "☶☳", "judgement": "贞吉，观颐"},
    28: {"name": "泽风大过", "symbol": "☱☴", "judgement": "栋桡，利有攸往"},
    29: {"name": "坎为水", "symbol": "☵☵", "judgement": "习坎，有孚"},
    30: {"name": "离为火", "symbol": "☲☲", "judgement": "畜牝牛，吉"},
    31: {"name": "泽山咸", "symbol": "☱☶", "judgement": "亨，利贞，取女吉"},
    32: {"name": "雷风恒", "symbol": "☳☴", "judgement": "亨，无咎，利贞"},
    33: {"name": "天山遁", "symbol": "☰☶", "judgement": "亨，小利贞"},
    34: {"name": "雷天大壮", "symbol": "☳☰", "judgement": "利贞"},
    35: {"name": "火地晋", "symbol": "☲☷", "judgement": "康侯用锡马蕃庶"},
    36: {"name": "地火明夷", "symbol": "☷☲", "judgement": "利艰贞"},
    37: {"name": "风火家人", "symbol": "☴☲", "judgement": "利女贞"},
    38: {"name": "火泽睽", "symbol": "☲☱", "judgement": "小事吉"},
    39: {"name": "水山蹇", "symbol": "☵☶", "judgement": "利西南，贞吉"},
    40: {"name": "雷水解", "symbol": "☳☵", "judgement": "利西南，无咎"},
    41: {"name": "山泽损", "symbol": "☶☱", "judgement": "有孚，元吉，无咎"},
    42: {"name": "风雷益", "symbol": "☴☳", "judgement": "利有攸往"},
    43: {"name": "泽天夬", "symbol": "☱☰", "judgement": "扬于王庭"},
    44: {"name": "天风姤", "symbol": "☰☴", "judgement": "女壮，勿用取女"},
    45: {"name": "泽地萃", "symbol": "☱☷", "judgement": "亨，王假有庙"},
    46: {"name": "地风升", "symbol": "☷☴", "judgement": "元亨，用见大人"},
    47: {"name": "泽水困", "symbol": "☱☵", "judgement": "亨，贞大人吉"},
    48: {"name": "水风井", "symbol": "☵☴", "judgement": "改邑不改井"},
    49: {"name": "泽火革", "symbol": "☱☲", "judgement": "巳日乃孚，元亨利贞"},
    50: {"name": "火风鼎", "symbol": "☲☴", "judgement": "元吉，亨"},
    51: {"name": "震为雷", "symbol": "☳☳", "judgement": "亨，震来虩虩"},
    52: {"name": "艮为山", "symbol": "☶☶", "judgement": "艮其背"},
    53: {"name": "风山渐", "symbol": "☴☶", "judgement": "女归吉，利贞"},
    54: {"name": "雷泽归妹", "symbol": "☳☱", "judgement": "征凶，无攸利"},
    55: {"name": "雷火丰", "symbol": "☳☲", "judgement": "亨，王假之"},
    56: {"name": "火山旅", "symbol": "☶☲", "judgement": "小亨，旅贞吉"},
    57: {"name": "巽为风", "symbol": "☴☴", "judgement": "小亨，利有攸往"},
    58: {"name": "兑为泽", "symbol": "☱☱", "judgement": "亨，利贞"},
    59: {"name": "风水涣", "symbol": "☴☵", "judgement": "亨，王假有庙"},
    60: {"name": "水泽节", "symbol": "☵☱", "judgement": "亨，苦节不可贞"},
    61: {"name": "风泽中孚", "symbol": "☴☱", "judgement": "豚鱼吉，利涉大川"},
    62: {"name": "雷山小过", "symbol": "☳☶", "judgement": "亨，利贞，可小事"},
    63: {"name": "水火既济", "symbol": "☵☲", "judgement": "亨，小利贞"},
    64: {"name": "火水未济", "symbol": "☲☵", "judgement": "亨，小狐汔济"},
}


def coin_toss() -> int:
    return 1 if sum(random.randint(0, 1) for _ in range(3)) % 2 == 1 else 0


def generate_hexagram() -> tuple:
    lines = [coin_toss() for _ in range(6)]
    changing = [i + 1 for i, l in enumerate(lines) if l == 1]
    num = int(''.join(str(l) for l in lines), 2) + 1
    return num, changing


async def main(params: dict) -> dict:
    if not isinstance(params, dict):
        return {"iching_data": json.dumps({"error": "params不是字典"}, ensure_ascii=False)}
    try:
        query = params.get("query", "")
        num, changing = generate_hexagram()
        h = HEXAGRAMS.get(num, {})
        info = {"lines": changing}
        if changing:
            info["from"] = h.get("name", "未知")
            info["to"] = HEXAGRAMS.get((num + len(changing) - 1) % 64 + 1, {}).get("name", "未知")
        else:
            info["from"] = h.get("name", "未知")
            info["to"] = None
        return {"iching_data": json.dumps({
            "hexagram": {"name": h.get("name", ""), "number": num, "symbol": h.get("symbol", "??"), "judgement": h.get("judgement", "")},
            "changing": info, "question": query
        }, ensure_ascii=False)}
    except Exception as e:
        return {"iching_data": json.dumps({"error": str(e)}, ensure_ascii=False)}


if __name__ == "__main__":
    import asyncio
    for q in ["事业如何？", "感情运势"]:
        r = asyncio.run(main({"query": q}))
        d = json.loads(r["iching_data"])
        print(f"问题: {q} -> 卦: {d['hexagram']['name']}({d['hexagram']['number']})")
