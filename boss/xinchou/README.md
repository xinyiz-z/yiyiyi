# BOSS直聘职位抓取工具

一个基于 DrissionPage 的 BOSS 直聘职位数据抓取工具，支持关键词搜索、公司搜索、多城市抓取和断点续抓。

## 功能特性

- ✅ 支持按关键词搜索职位
- ✅ 支持按公司名称搜索职位
- ✅ 支持多城市切换抓取
- ✅ 断点续抓（自动保存已抓取数据）
- ✅ 可选抓取职位详情描述
- ✅ 数据导出为 CSV 格式

## 依赖安装

```bash
pip install DrissionPage
```

## 使用方法

### 1. 基本使用（交互模式）

```bash
python Boss_job.py
```

按提示依次输入：
- 城市名称或代码（默认：全国）
- 搜索方式（关键词搜索 / 公司名称搜索）
- 关键词或公司名称

### 2. 命令行参数

```bash
# 按关键词搜索
python Boss_job.py --keyword "计算机" --city "北京"

# 按公司名称搜索
python Boss_job.py --company "阿里巴巴" --city "杭州"

# 抓取职位详情描述（会增加抓取时间）
python Boss_job.py --keyword "Java" --fetch-description
```

### 可用参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--keyword` | 岗位关键词 | 计算机 |
| `--company` | 公司名称（与关键词二选一） | None |
| `--city` | 城市名称或城市代码 | 全国 |
| `--output-prefix` | 输出文件前缀 | 自动生成 |
| `--packet-timeout` | 接口超时时间（秒） | 8 |
| `--scroll-pause` | 下拉等待时间（秒） | 1.5-2.0 |
| `--max-empty-scrolls` | 连续空抓取上限 | 3 |
| `--max-scroll-rounds` | 最大下拉轮次（0=不限制） | 0 |
| `--fetch-description` | 是否抓取职位详情描述 | False |

## 输出文件

- `boss_jobs_<关键词/公司名>.csv` - 职位数据文件
- `boss_jobs_<关键词/公司名>.log` - 调试日志（仅出错时生成）

## 数据字段

| 字段 | 说明 |
|------|------|
| job_id | 职位ID |
| job_name | 职位名称 |
| salary | 薪资 |
| job_labels | 职位标签 |
| job_experience | 经验要求 |
| job_degree | 学历要求 |
| city_name | 城市名称 |
| area_district | 行政区 |
| business_district | 商圈 |
| brand_name | 公司名称 |
| brand_scale | 公司规模 |
| brand_stage | 融资阶段 |
| skills | 技能要求 |
| welfare_list | 福利列表 |
| boss_name | BOSS姓名 |
| boss_title | BOSS职位 |
| job_description | 职位详情描述 |

## 注意事项

1. 运行前需要在弹出的浏览器中完成登录和安全验证
2. 抓取频率不宜过快，建议使用默认等待时间
3. BOSS直聘对单个搜索词有数据量限制，通常为300条左右
4. 遵守网站服务协议，合理使用本工具

## 技术栈

- Python 3.8+
- DrissionPage（浏览器自动化）
- argparse（命令行参数解析）
- csv（数据导出）
