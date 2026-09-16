import requests
import pandas as pd
import matplotlib.pyplot as plt
import json
import time
import uuid
import hashlib
import re
from datetime import datetime
from typing import Dict, List, Tuple, Optional

plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'DejaVu Sans']
plt.rcParams['axes.unicode_minus'] = False

COZE_BASE_URL = "https://api.coze.cn"
COZE_CHAT_ENDPOINT = f"{COZE_BASE_URL}/v3/chat"
COZE_RETRIEVE_ENDPOINT = f"{COZE_BASE_URL}/v3/chat/retrieve"
TOKEN = "pat_e42yhOjJUrcPWycwV8vs8n0yMeVCiudD42mYT3O0ANYchwffJ5z02DxovzB0z2qE"
BOT_ID = "7526214680554258466"

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}

def generate_user_id() -> str:
    return hashlib.md5(str(uuid.uuid4()).encode()).hexdigest()[:16]

class CozeAPIError(Exception):
    def __init__(self, code: int, message: str, details: Dict = None):
        self.code = code
        self.message = message
        self.details = details or {}
        super().__init__(f"Coze API Error {code}: {message}")

def parse_coze_response(response: requests.Response) -> Tuple[Dict, int]:
    try:
        content_type = response.headers.get('Content-Type', '')
        if not response.text.strip():
            raise ValueError("Empty response body")
        
        if 'application/json' in content_type:
            result = response.json()
        else:
            try:
                result = json.loads(response.text)
            except json.JSONDecodeError:
                raise ValueError(f"Non-JSON response: {response.text[:500]}")
        
        code = result.get('code', response.status_code)
        if code != 0:
            msg = result.get('msg', result.get('message', 'Unknown error'))
            raise CozeAPIError(code, msg, result)
        
        return result, response.status_code
    
    except json.JSONDecodeError as e:
        raise ValueError(f"JSON parse error: {str(e)} | Response: {response.text[:500]}")
    except requests.exceptions.RequestException as e:
        raise ConnectionError(f"HTTP request failed: {str(e)}")

def chat_api_sync(question: str, user_id: str = None, timeout: int = 30) -> Tuple[Dict, int]:
    user_id = user_id or generate_user_id()
    
    payload = {
        "bot_id": BOT_ID,
        "user_id": user_id,
        "stream": False,
        "msgs": [
            {
                "role": "user",
                "content": question,
                "content_type": "text"
            }
        ]
    }
    
    try:
        response = requests.post(COZE_CHAT_ENDPOINT, json=payload, headers=HEADERS, timeout=timeout)
        return parse_coze_response(response)
    except CozeAPIError as e:
        return {"error": {"code": e.code, "message": e.message}, "answer": "", "plugin_data": []}, 200
    except ValueError as e:
        return {"error": {"code": -1, "message": str(e)}, "answer": "", "plugin_data": []}, 200
    except ConnectionError as e:
        return {"error": {"code": -2, "message": str(e)}, "answer": "", "plugin_data": []}, 503
    except Exception as e:
        return {"error": {"code": -3, "message": str(e)}, "answer": "", "plugin_data": []}, 500

def chat_api_stream(question: str, user_id: str = None, timeout: int = 60) -> Tuple[Dict, int]:
    user_id = user_id or generate_user_id()
    
    payload = {
        "bot_id": BOT_ID,
        "user_id": user_id,
        "stream": True,
        "msgs": [
            {
                "role": "user",
                "content": question,
                "content_type": "text"
            }
        ]
    }
    
    try:
        response = requests.post(COZE_CHAT_ENDPOINT, json=payload, headers=HEADERS, 
                                timeout=timeout, stream=True)
        response.raise_for_status()
        
        full_answer = ""
        plugin_data = []
        chat_id = None
        
        for line in response.iter_lines():
            if line:
                line_str = line.decode('utf-8').strip()
                if line_str.startswith('data: '):
                    data_str = line_str[6:]
                    try:
                        chunk = json.loads(data_str)
                        if chunk.get('event') == 'chat.completed':
                            full_answer = chunk.get('answer', '')
                            plugin_data = chunk.get('plugin_data', [])
                            chat_id = chunk.get('chat_id')
                        elif chunk.get('event') == 'delta':
                            delta = chunk.get('delta', '')
                            full_answer += delta
                    except json.JSONDecodeError:
                        pass
        
        return {
            "answer": full_answer,
            "plugin_data": plugin_data,
            "chat_id": chat_id
        }, 200
        
    except requests.exceptions.RequestException as e:
        return {"error": {"code": -2, "message": str(e)}, "answer": "", "plugin_data": []}, 503
    except Exception as e:
        return {"error": {"code": -3, "message": str(e)}, "answer": "", "plugin_data": []}, 500

def retrieve_chat(chat_id: str) -> Tuple[Dict, int]:
    try:
        response = requests.get(f"{COZE_RETRIEVE_ENDPOINT}?chat_id={chat_id}", headers=HEADERS)
        return parse_coze_response(response)
    except CozeAPIError as e:
        return {"error": {"code": e.code, "message": e.message}}, 200
    except Exception as e:
        return {"error": {"code": -3, "message": str(e)}}, 500

def analyze_response(response: Dict, std_answer: str = "") -> Dict:
    metrics = {
        "has_error": False,
        "error_code": None,
        "error_message": None,
        "recall_flag": False,
        "hallucination": False,
        "format_correct": True,
        "consistency_score": 0.0,
        "fact_accuracy": 0.0,
        "response_length": 0,
        "has_plugin_data": False,
        "plugin_call_count": 0,
        "is_refusal": False,
        "is_gibberish": False
    }
    
    if "error" in response:
        metrics["has_error"] = True
        metrics["error_code"] = response["error"]["code"]
        metrics["error_message"] = response["error"]["message"]
        return metrics
    
    answer = response.get("answer", "")
    metrics["response_length"] = len(answer)
    
    plugin_data = response.get("plugin_data", [])
    if isinstance(plugin_data, list) and len(plugin_data) > 0:
        metrics["has_plugin_data"] = True
        metrics["plugin_call_count"] = len(plugin_data)
        metrics["recall_flag"] = True
    
    refusal_keywords = ["无法", "不能", "抱歉", "拒绝", "暂无数据", "暂无相关", "不支持"]
    if any(kw in answer for kw in refusal_keywords):
        metrics["is_refusal"] = True
    
    if len(answer) > 0 and len(set(answer)) < 10:
        metrics["is_gibberish"] = True
    
    if metrics["has_plugin_data"]:
        facts_from_plugin = []
        for plugin in plugin_data:
            if isinstance(plugin, dict):
                facts_from_plugin.append(str(plugin.values()))
        
        if facts_from_plugin and answer:
            fact_found = sum(1 for fact in facts_from_plugin if fact in answer)
            metrics["fact_accuracy"] = min(fact_found / len(facts_from_plugin), 1.0)
        else:
            metrics["fact_accuracy"] = 0.0
    else:
        if std_answer and answer:
            common_chars = len(set(answer) & set(std_answer))
            metrics["fact_accuracy"] = common_chars / max(len(answer), len(std_answer), 1)
        
        if not metrics["is_refusal"] and not std_answer:
            metrics["hallucination"] = True
    
    format_errors = [
        "```json", "```xml", "```html", 
        "未完成", "正在思考", "加载中",
        "\n\n\n\n\n", "===="
    ]
    if any(error in answer for error in format_errors):
        metrics["format_correct"] = False
    
    return metrics

def load_test_cases(filepath: str = "03_全量测试用例.xlsx") -> pd.DataFrame:
    try:
        df = pd.read_excel(filepath)
        return df
    except Exception as e:
        print(f"Failed to load test cases: {e}")
        return pd.DataFrame()

def load_adversarial_samples(filepath: str = "adversarial_samples.json") -> Dict:
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        return {}
    except Exception as e:
        print(f"Failed to load adversarial samples: {e}")
        return {}

def run_test_case(row: pd.Series, user_id: str = None) -> Dict:
    case_id = row.get("用例 ID", "")
    test_module = row.get("测试模块", "")
    test_type = row.get("测试类型", "")
    operation = row.get("操作步骤", "")
    expected = row.get("预期结果", "")
    
    question = operation.split("输入")[-1].strip() if "输入" in operation else operation.strip()
    
    start_time = time.time()
    response, status_code = chat_api_sync(question, user_id)
    duration = time.time() - start_time
    
    metrics = analyze_response(response, expected)
    
    result = {
        "用例ID": case_id,
        "测试模块": test_module,
        "测试类型": test_type,
        "问题": question,
        "接口状态码": status_code,
        "响应耗时(s)": round(duration, 2),
        "是否成功": not metrics["has_error"],
        "是否成功召回": metrics["recall_flag"],
        "是否出现幻觉": metrics["hallucination"],
        "格式是否正确": metrics["format_correct"],
        "是否拒绝回答": metrics["is_refusal"],
        "是否乱码": metrics["is_gibberish"],
        "事实准确率": round(metrics["fact_accuracy"], 2),
        "AI回答": response.get("answer", "")[:500],
        "错误码": metrics["error_code"],
        "错误信息": metrics["error_message"],
        "插件调用次数": metrics["plugin_call_count"],
        "测试时间": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    }
    
    return result

def run_adversarial_test(adversarial_samples: Dict, user_id: str = None) -> List[Dict]:
    results = []
    
    for category, samples in adversarial_samples.items():
        for sample in samples:
            question = sample.get("question", "")
            expected_behavior = sample.get("expected_behavior", "")
            
            start_time = time.time()
            response, status_code = chat_api_sync(question, user_id)
            duration = time.time() - start_time
            
            metrics = analyze_response(response)
            
            passed = False
            if "拒绝" in expected_behavior and metrics["is_refusal"]:
                passed = True
            elif "不编造" in expected_behavior and not metrics["hallucination"]:
                passed = True
            elif "提示错误" in expected_behavior and metrics["has_error"]:
                passed = True
            elif "正常" in expected_behavior and not metrics["has_error"]:
                passed = True
            
            results.append({
                "用例ID": f"ADV-{category[:3]}-{len(results)+1:03d}",
                "测试模块": "对抗测试",
                "测试类型": category,
                "问题": question[:100],
                "接口状态码": status_code,
                "响应耗时(s)": round(duration, 2),
                "是否通过": passed,
                "是否出现幻觉": metrics["hallucination"],
                "是否拒绝回答": metrics["is_refusal"],
                "事实准确率": round(metrics["fact_accuracy"], 2),
                "AI回答": response.get("answer", "")[:500],
                "预期行为": expected_behavior,
                "测试时间": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            })
    
    return results

def generate_report(all_results: List[Dict], adversarial_results: List[Dict] = None):
    all_df = pd.DataFrame(all_results)
    
    if adversarial_results:
        adv_df = pd.DataFrame(adversarial_results)
        all_df = pd.concat([all_df, adv_df], ignore_index=True)
    
    total_cases = len(all_df)
    success_cases = len(all_df[all_df["是否成功"] | all_df.get("是否通过", False)])
    failure_cases = total_cases - success_cases
    
    recall_rate = all_df["是否成功召回"].mean() if "是否成功召回" in all_df.columns else 0
    hallucination_rate = all_df["是否出现幻觉"].mean() if "是否出现幻觉" in all_df.columns else 0
    format_error_rate = 1 - all_df["格式是否正确"].mean() if "格式是否正确" in all_df.columns else 0
    avg_fact_accuracy = all_df["事实准确率"].mean() if "事实准确率" in all_df.columns else 0
    avg_duration = all_df["响应耗时(s)"].mean() if "响应耗时(s)" in all_df.columns else 0
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    report_filename = f"自动化评测报告_{timestamp}.xlsx"
    all_df.to_excel(report_filename, index=False)
    print(f"测试报告已保存: {report_filename}")
    
    summary = {
        "测试时间": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "总用例数": total_cases,
        "成功用例数": success_cases,
        "失败用例数": failure_cases,
        "成功率": f"{success_cases/total_cases*100:.2f}%",
        "检索召回率": f"{recall_rate*100:.2f}%",
        "幻觉率": f"{hallucination_rate*100:.2f}%",
        "格式错误率": f"{format_error_rate*100:.2f}%",
        "平均事实准确率": f"{avg_fact_accuracy*100:.2f}%",
        "平均响应耗时": f"{avg_duration:.2f}s"
    }
    
    print("\n" + "="*60)
    print("              智能体自动化评测报告")
    print("="*60)
    for key, value in summary.items():
        print(f"{key:<12}: {value}")
    print("="*60 + "\n")
    
    by_module = all_df.groupby("测试模块").agg({
        "是否成功": "mean",
        "是否成功召回": "mean",
        "是否出现幻觉": "mean",
        "事实准确率": "mean"
    }).round(2)
    print("按模块统计:")
    print(by_module)
    print()
    
    by_type = all_df.groupby("测试类型").agg({
        "是否成功": "mean",
        "是否成功召回": "mean",
        "是否出现幻觉": "mean",
        "事实准确率": "mean"
    }).round(2)
    print("按类型统计:")
    print(by_type)
    
    success_col = all_df["是否成功"].fillna(False)
    failure_df = all_df[~success_col]
    if not failure_df.empty:
        print("\n失败用例详情:")
        for _, row in failure_df.iterrows():
            error_msg = row.get('错误信息', '') if pd.notna(row.get('错误信息', '')) else ''
            print(f"  {row['用例ID']} - {row['测试模块']} - {error_msg}")
    
    return all_df, summary

def plot_metrics(all_df: pd.DataFrame):
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    
    if "是否成功召回" in all_df.columns:
        recall_data = all_df["是否成功召回"].value_counts()
        axes[0, 0].pie(recall_data, labels=["成功召回", "未召回"], autopct='%1.1f%%', colors=['#4CAF50', '#FF9800'])
        axes[0, 0].set_title("检索召回率")
    
    if "是否出现幻觉" in all_df.columns:
        hallucination_data = all_df["是否出现幻觉"].value_counts()
        axes[0, 1].pie(hallucination_data, labels=["无幻觉", "有幻觉"], autopct='%1.1f%%', colors=['#2196F3', '#F44336'])
        axes[0, 1].set_title("幻觉率")
    
    if "格式是否正确" in all_df.columns:
        format_data = all_df["格式是否正确"].value_counts()
        axes[1, 0].pie(format_data, labels=["格式正确", "格式错误"], autopct='%1.1f%%', colors=['#8BC34A', '#FF5722'])
        axes[1, 0].set_title("格式正确率")
    
    if "测试模块" in all_df.columns and "是否成功" in all_df.columns:
        module_success = all_df.groupby("测试模块")["是否成功"].mean() * 100
        axes[1, 1].bar(module_success.index, module_success.values, color=['#607D8B', '#9C27B0', '#00BCD4', '#FFC107'])
        axes[1, 1].set_title("各模块成功率")
        axes[1, 1].tick_params(axis='x', rotation=45)
        axes[1, 1].set_ylim(0, 100)
    
    plt.tight_layout()
    plt.savefig(f"评测指标看板_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png", dpi=150, bbox_inches='tight')
    print("\n指标看板已保存")

def auto_test():
    print("="*60)
    print("        智能体自动化评测系统启动")
    print("="*60 + "\n")
    
    user_id = generate_user_id()
    print(f"测试用户ID: {user_id}")
    
    print("\n[步骤1/4] 加载测试用例...")
    df = load_test_cases()
    if df.empty:
        print("警告: 未加载到测试用例")
        return
    
    print(f"已加载 {len(df)} 条测试用例")
    
    print("\n[步骤2/4] 执行标准测试用例...")
    all_results = []
    for idx, row in df.iterrows():
        print(f"  执行用例 {idx+1}/{len(df)}: {row['用例 ID']}")
        try:
            result = run_test_case(row, user_id)
            all_results.append(result)
        except Exception as e:
            print(f"    执行失败: {e}")
            all_results.append({
                "用例ID": row.get("用例 ID", ""),
                "测试模块": row.get("测试模块", ""),
                "测试类型": row.get("测试类型", ""),
                "问题": "",
                "接口状态码": -1,
                "是否成功": False,
                "AI回答": f"测试执行异常: {e}",
                "测试时间": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            })
    
    print("\n[步骤3/4] 执行对抗测试用例...")
    adversarial_samples = load_adversarial_samples()
    adversarial_results = []
    if adversarial_samples:
        adversarial_results = run_adversarial_test(adversarial_samples, user_id)
        print(f"已执行 {len(adversarial_results)} 条对抗测试用例")
    else:
        print("警告: 未加载到对抗测试样本")
    
    print("\n[步骤4/4] 生成评测报告...")
    all_df, summary = generate_report(all_results, adversarial_results)
    plot_metrics(all_df)
    
    print("\n评测完成!")
    return all_df, summary

def batch_stress_test(question: str = "测算今天运势", count: int = 10):
    print(f"\n[压力测试] 连续调用 {count} 次...")
    results = []
    for i in range(count):
        start_time = time.time()
        response, status_code = chat_api_sync(question)
        duration = time.time() - start_time
        
        success = not response.get("error")
        results.append({
            "次数": i+1,
            "状态码": status_code,
            "耗时(s)": round(duration, 2),
            "成功": success,
            "错误信息": response.get("error", {}).get("message", "") if not success else ""
        })
        
        status = "✓" if success else "✗"
        print(f"  [{status}] 第{i+1}次: {duration:.2f}s")
    
    df = pd.DataFrame(results)
    success_rate = df["成功"].mean() * 100
    avg_duration = df["耗时(s)"].mean()
    
    print(f"\n压力测试结果:")
    print(f"  成功率: {success_rate:.2f}%")
    print(f"  平均耗时: {avg_duration:.2f}s")
    print(f"  最大耗时: {df['耗时(s)'].max():.2f}s")
    print(f"  最小耗时: {df['耗时(s)'].min():.2f}s")
    
    df.to_excel(f"压力测试报告_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx", index=False)
    return df

if __name__ == "__main__":
    auto_test()
    batch_stress_test(count=5)