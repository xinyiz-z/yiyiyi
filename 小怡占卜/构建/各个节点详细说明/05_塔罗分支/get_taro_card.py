# -*- coding: utf-8 -*-
"""
小怡占卜 · 塔罗抽牌代码节点
1. 输入：query, profile(可选)
2. 输出：tarot_data (JSON)
"""

import json
import random


# 塔罗牌数据(简化版)
TAROT_CARDS = {
    "0": {"name": "愚人", "meaning": "新的开始，无限可能"},
    "1": {"name": "魔术师", "meaning": "心想事成，资源丰富"},
    "2": {"name": "女祭司", "meaning": "倾听内心，探索潜意识"},
    "3": {"name": "女皇", "meaning": "收获季节，享受生活"},
    "4": {"name": "皇帝", "meaning": "建立秩序，承担责任"},
    "5": {"name": "教皇", "meaning": "寻求智慧，遵循正道"},
    "6": {"name": "恋人", "meaning": "重大决定，真爱降临"},
    "7": {"name": "战车", "meaning": "克服障碍，勇往直前"},
    "8": {"name": "力量", "meaning": "以柔克刚，征服恐惧"},
    "9": {"name": "隐士", "meaning": "寻找真我，静心思考"},
    "10": {"name": "命运之轮", "meaning": "时来运转，把握机会"},
    "11": {"name": "正义", "meaning": "种瓜得瓜，公正裁决"},
    "12": {"name": "倒吊人", "meaning": "以退为进，放下执念"},
    "13": {"name": "死神", "meaning": "旧的不去新的不来"},
    "14": {"name": "节制", "meaning": "中庸之道，适度为美"},
    "15": {"name": "恶魔", "meaning": "摆脱枷锁，看清真相"},
    "16": {"name": "塔", "meaning": "破茧而出，浴火重生"},
    "17": {"name": "星星", "meaning": "重燃希望，光明在前"},
    "18": {"name": "月亮", "meaning": "拨开迷雾，直面恐惧"},
    "19": {"name": "太阳", "meaning": "前途光明，万事如意"},
    "20": {"name": "审判", "meaning": "既往不咎，重新开始"},
    "21": {"name": "世界", "meaning": "大功告成，人生圆满"},
    "W1": {"name": "权杖Ace", "meaning": "新项目的开始"},
    "W2": {"name": "权杖二", "meaning": "规划未来"},
    "W3": {"name": "权杖三", "meaning": "拓展视野"},
    "W4": {"name": "权杖四", "meaning": "享受成果"},
    "W5": {"name": "权杖五", "meaning": "竞争中求胜"},
    "W6": {"name": "权杖六", "meaning": "获得成功"},
    "C1": {"name": "圣杯Ace", "meaning": "爱与情感的萌芽"},
    "C2": {"name": "圣杯二", "meaning": "美好的关系"},
    "C3": {"name": "圣杯三", "meaning": "欢庆时刻"},
    "C4": {"name": "圣杯四", "meaning": "走出阴霾"},
    "C5": {"name": "圣杯五", "meaning": "接纳失去"},
    "S1": {"name": "宝剑Ace", "meaning": "清晰的思想"},
    "S2": {"name": "宝剑二", "meaning": "需要决断"},
    "S3": {"name": "宝剑三", "meaning": "伤心难过"},
    "P1": {"name": "星币Ace", "meaning": "财务新开始"},
    "P2": {"name": "星币二", "meaning": "灵活应对"},
    "P3": {"name": "星币三", "meaning": "协作成功"},
}


def draw_cards(count: int = 3) -> list:
    """抽取指定数量的牌"""
    keys = list(TAROT_CARDS.keys())
    cards = []
    for _ in range(count):
        key = random.choice(keys)
        card = TAROT_CARDS[key].copy()
        card["key"] = key
        card["orientation"] = "逆位" if random.random() < 0.15 else "正位"
        cards.append(card)
    return cards


async def main(params: dict) -> dict:
    """入口函数"""
    if not isinstance(params, dict):
        return {"tarot_data": json.dumps({"error": "params不是字典"}, ensure_ascii=False)}
    
    try:
        query = params.get("query", "")
        cards = draw_cards(3)
        
        result = {
            "cards": [
                {
                    "position": ["过去", "现在", "未来"][i],
                    "name": c["name"],
                    "orientation": c["orientation"],
                    "meaning": f"{'【逆位】' if c['orientation']=='逆位' else ''}{c['meaning']}"
                }
                for i, c in enumerate(cards)
            ],
            "spread": "三张牌阵",
            "question": query
        }
        return {"tarot_data": json.dumps(result, ensure_ascii=False)}
    except Exception as e:
        return {"tarot_data": json.dumps({"error": str(e)}, ensure_ascii=False)}


if __name__ == "__main__":
    import asyncio
    for q in ["事业如何？", "感情运势"]:
        r = asyncio.run(main({"query": q}))
        d = json.loads(r["tarot_data"])
        print(f"问题: {q}")
        for c in d["cards"]:
            print(f"  {c['position']}: {c['name']}({c['orientation']})")
