-- =============================================
-- 达梦数据库 - 月度经营分析报表
-- 功能：按月输出成本周期经营分析报表，为管理层经营决策提供可视化数据支撑
-- 作者：数据运营团队
-- 创建时间：2026-06-26
-- =============================================

-- =============================================
-- 第一部分：月度综合经营分析报表
-- =============================================

-- 1.1 月度整体经营概览
-- =============================================
CREATE OR REPLACE VIEW v_monthly_overview AS
SELECT
    DATE_FORMAT(bid_date, '%Y-%m') AS report_month,
    -- 项目统计
    COUNT(*) AS total_projects,
    COUNT(CASE WHEN bid_amount >= 100 THEN 1 END) AS large_projects,
    COUNT(CASE WHEN bid_amount >= 50 AND bid_amount < 100 THEN 1 END) AS medium_projects,
    COUNT(CASE WHEN bid_amount < 50 THEN 1 END) AS small_projects,
    -- 金额统计
    SUM(bid_amount) AS total_bid_amount,
    AVG(bid_amount) AS avg_bid_amount,
    MAX(bid_amount) AS max_bid_amount,
    MIN(bid_amount) AS min_bid_amount,
    -- 成本统计
    COALESCE(SUM(sci.cost_amount), 0) AS total_cost,
    SUM(bid_amount) - COALESCE(SUM(sci.cost_amount), 0) AS total_profit,
    CASE
        WHEN SUM(bid_amount) > 0 THEN
            ROUND((SUM(bid_amount) - COALESCE(SUM(sci.cost_amount), 0)) / SUM(bid_amount) * 100, 2)
        ELSE 0
    END AS profit_margin,
    -- 回款统计
    COALESCE(SUM(spi2.actual_amount), 0) AS total_payment,
    CASE
        WHEN SUM(bid_amount) > 0 THEN
            ROUND(COALESCE(SUM(spi2.actual_amount), 0) / SUM(bid_amount) * 100, 2)
        ELSE 0
    END AS payment_rate,
    -- 平均回款周期
    AVG(DATEDIFF(DAY, spi.bid_date, spi2.actual_date)) AS avg_payment_cycle,
    -- 签约转化率
    CASE
        WHEN COUNT(*) > 0 THEN
            ROUND(COUNT(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 END) * 100.0 / COUNT(*), 2)
        ELSE 0
    END AS conversion_rate,
    -- 新客户占比
    CASE
        WHEN COUNT(*) > 0 THEN
            ROUND(COUNT(CASE WHEN spi.customer_name NOT IN (SELECT customer_name FROM sales_project_info WHERE bid_date < DATE '2024-01-01') THEN 1 END) * 100.0 / COUNT(*), 2)
        ELSE 0
    END AS new_customer_rate
FROM sales_project_info spi
LEFT JOIN sales_cost_info sci ON spi.contract_no = sci.contract_no AND sci.cost_date BETWEEN DATE_FORMAT(spi.bid_date, '%Y-%m-01') AND LAST_DAY(spi.bid_date)
LEFT JOIN sales_payment_info spi2 ON spi.contract_no = spi2.contract_no AND spi2.actual_date BETWEEN DATE_FORMAT(spi.bid_date, '%Y-%m-01') AND LAST_DAY(spi.bid_date)
LEFT JOIN sales_process_tracking spt ON spi.contract_no = spt.contract_no
WHERE spi.is_valid = 1
GROUP BY DATE_FORMAT(bid_date, '%Y-%m')
ORDER BY report_month DESC;

COMMENT ON VIEW v_monthly_overview IS '月度整体经营概览视图';

-- 1.2 月度区域经营分析报表
-- =============================================
CREATE OR REPLACE VIEW v_monthly_regional_report AS
SELECT
    DATE_FORMAT(spi.bid_date, '%Y-%m') AS report_month,
    spi.province AS region,
    -- 项目数量及金额
    COUNT(DISTINCT spi.contract_no) AS project_count,
    SUM(spi.bid_amount) AS total_amount,
    AVG(spi.bid_amount) AS avg_amount,
    -- 成本分析
    COALESCE(SUM(sci.cost_amount), 0) AS total_cost,
    SUM(spi.bid_amount) - COALESCE(SUM(sci.cost_amount), 0) AS profit,
    CASE
        WHEN SUM(spi.bid_amount) > 0 THEN
            ROUND((SUM(spi.bid_amount) - COALESCE(SUM(sci.cost_amount), 0)) / SUM(spi.bid_amount) * 100, 2)
        ELSE 0
    END AS profit_margin,
    -- 回款分析
    COALESCE(SUM(spi2.actual_amount), 0) AS total_payment,
    CASE
        WHEN SUM(spi.bid_amount) > 0 THEN
            ROUND(COALESCE(SUM(spi2.actual_amount), 0) / SUM(spi.bid_amount) * 100, 2)
        ELSE 0
    END AS payment_rate,
    AVG(DATEDIFF(DAY, spi.bid_date, spi2.actual_date)) AS avg_payment_cycle,
    -- 转化分析
    CASE
        WHEN COUNT(DISTINCT spi.contract_no) > 0 THEN
            ROUND(COUNT(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 END) * 100.0 / COUNT(DISTINCT spi.contract_no), 2)
        ELSE 0
    END AS conversion_rate,
    -- 同比分析（去年同期）
    LAG(SUM(spi.bid_amount)) OVER (PARTITION BY spi.province, MONTH(spi.bid_date) ORDER BY YEAR(spi.bid_date)) AS last_year_amount,
    CASE
        WHEN LAG(SUM(spi.bid_amount)) OVER (PARTITION BY spi.province, MONTH(spi.bid_date) ORDER BY YEAR(spi.bid_date)) > 0 THEN
            ROUND((SUM(spi.bid_amount) - LAG(SUM(spi.bid_amount)) OVER (PARTITION BY spi.province, MONTH(spi.bid_date) ORDER BY YEAR(spi.bid_date))) /
                  LAG(SUM(spi.bid_amount)) OVER (PARTITION BY spi.province, MONTH(spi.bid_date) ORDER BY YEAR(spi.bid_date)) * 100, 2)
        ELSE NULL
    END AS year_growth_rate,
    -- 区域排名
    ROW_NUMBER() OVER (PARTITION BY DATE_FORMAT(spi.bid_date, '%Y-%m') ORDER BY SUM(spi.bid_amount) DESC) AS amount_rank,
    ROW_NUMBER() OVER (PARTITION BY DATE_FORMAT(spi.bid_date, '%Y-%m') ORDER BY CASE WHEN SUM(spi.bid_amount) > 0 THEN ROUND((SUM(spi.bid_amount) - COALESCE(SUM(sci.cost_amount), 0)) / SUM(spi.bid_amount) * 100, 2) ELSE 0 END DESC) AS profit_rank
FROM sales_project_info spi
LEFT JOIN sales_cost_info sci ON spi.contract_no = sci.contract_no
LEFT JOIN sales_payment_info spi2 ON spi.contract_no = spi2.contract_no
LEFT JOIN sales_process_tracking spt ON spi.contract_no = spt.contract_no
WHERE spi.is_valid = 1
GROUP BY DATE_FORMAT(spi.bid_date, '%Y-%m'), spi.province, YEAR(spi.bid_date), MONTH(spi.bid_date)
ORDER BY report_month DESC, total_amount DESC;

COMMENT ON VIEW v_monthly_regional_report IS '月度区域经营分析报表视图';

-- 1.3 月度行业经营分析报表
-- =============================================
CREATE OR REPLACE VIEW v_monthly_industry_report AS
SELECT
    DATE_FORMAT(spi.bid_date, '%Y-%m') AS report_month,
    spi.project_category AS industry,
    spi.secondary_category AS sub_industry,
    -- 项目统计
    COUNT(DISTINCT spi.contract_no) AS project_count,
    COUNT(DISTINCT spi.customer_name) AS customer_count,
    -- 金额统计
    SUM(spi.bid_amount) AS total_amount,
    AVG(spi.bid_amount) AS avg_amount,
    -- 占比分析
    ROUND(SUM(spi.bid_amount) * 100.0 / (SELECT SUM(bid_amount) FROM sales_project_info WHERE DATE_FORMAT(bid_date, '%Y-%m') = DATE_FORMAT(spi.bid_date, '%Y-%m') AND is_valid = 1), 2) AS amount_percentage,
    -- 成本分析
    COALESCE(SUM(sci.cost_amount), 0) AS total_cost,
    CASE
        WHEN SUM(spi.bid_amount) > 0 THEN
            ROUND((SUM(spi.bid_amount) - COALESCE(SUM(sci.cost_amount), 0)) / SUM(spi.bid_amount) * 100, 2)
        ELSE 0
    END AS profit_margin,
    -- 转化分析
    CASE
        WHEN COUNT(DISTINCT spi.contract_no) > 0 THEN
            ROUND(COUNT(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 END) * 100.0 / COUNT(DISTINCT spi.contract_no), 2)
        ELSE 0
    END AS conversion_rate,
    -- 行业潜力评估
    CASE
        WHEN SUM(spi.bid_amount) >= 500 AND COUNT(DISTINCT spi.customer_name) >= 10 THEN '核心行业'
        WHEN SUM(spi.bid_amount) >= 200 AND COUNT(DISTINCT spi.customer_name) >= 5 THEN '潜力行业'
        ELSE '一般行业'
    END AS industry_potential,
    -- 排名
    ROW_NUMBER() OVER (PARTITION BY DATE_FORMAT(spi.bid_date, '%Y-%m') ORDER BY SUM(spi.bid_amount) DESC) AS industry_rank
FROM sales_project_info spi
LEFT JOIN sales_cost_info sci ON spi.contract_no = sci.contract_no
LEFT JOIN sales_process_tracking spt ON spi.contract_no = spt.contract_no
WHERE spi.is_valid = 1
GROUP BY DATE_FORMAT(spi.bid_date, '%Y-%m'), spi.project_category, spi.secondary_category
ORDER BY report_month DESC, total_amount DESC;

COMMENT ON VIEW v_monthly_industry_report IS '月度行业经营分析报表视图';

-- =============================================
-- 第二部分：成本周期分析报表
-- =============================================

-- 2.1 月度成本构成分析
-- =============================================
CREATE OR REPLACE VIEW v_monthly_cost_structure AS
SELECT
    DATE_FORMAT(sci.cost_date, '%Y-%m') AS report_month,
    sci.cost_type,
    -- 成本金额统计
    SUM(sci.cost_amount) AS total_cost,
    AVG(sci.cost_amount) AS avg_cost,
    MAX(sci.cost_amount) AS max_cost,
    MIN(sci.cost_amount) AS min_cost,
    -- 项目数量统计
    COUNT(DISTINCT sci.contract_no) AS project_count,
    -- 成本占比
    ROUND(SUM(sci.cost_amount) * 100.0 / (SELECT SUM(cost_amount) FROM sales_cost_info WHERE DATE_FORMAT(cost_date, '%Y-%m') = DATE_FORMAT(sci.cost_date, '%Y-%m')), 2) AS cost_percentage,
    -- 成本效率
    SUM(spi.bid_amount) AS total_bid_amount,
    CASE
        WHEN SUM(sci.cost_amount) > 0 THEN
            ROUND(SUM(spi.bid_amount) / SUM(sci.cost_amount), 2)
        ELSE 0
    END AS cost_efficiency_ratio,
    -- 同比分析
    LAG(SUM(sci.cost_amount)) OVER (PARTITION BY sci.cost_type, MONTH(sci.cost_date) ORDER BY YEAR(sci.cost_date)) AS last_year_cost,
    CASE
        WHEN LAG(SUM(sci.cost_amount)) OVER (PARTITION BY sci.cost_type, MONTH(sci.cost_date) ORDER BY YEAR(sci.cost_date)) > 0 THEN
            ROUND((SUM(sci.cost_amount) - LAG(SUM(sci.cost_amount)) OVER (PARTITION BY sci.cost_type, MONTH(sci.cost_date) ORDER BY YEAR(sci.cost_date))) /
                  LAG(SUM(sci.cost_amount)) OVER (PARTITION BY sci.cost_type, MONTH(sci.cost_date) ORDER BY YEAR(sci.cost_date)) * 100, 2)
        ELSE NULL
    END AS year_growth_rate
FROM sales_cost_info sci
LEFT JOIN sales_project_info spi ON sci.contract_no = spi.contract_no
WHERE spi.is_valid = 1
GROUP BY DATE_FORMAT(sci.cost_date, '%Y-%m'), sci.cost_type, YEAR(sci.cost_date), MONTH(sci.cost_date)
ORDER BY report_month DESC, total_cost DESC;

COMMENT ON VIEW v_monthly_cost_structure IS '月度成本构成分析视图';

-- 2.2 月度成本效率趋势分析
-- =============================================
CREATE OR REPLACE VIEW v_monthly_cost_efficiency_trend AS
SELECT
    report_month,
    total_projects,
    total_bid_amount,
    total_cost,
    total_profit,
    profit_margin,
    -- 成本效率指标
    CASE
        WHEN total_cost > 0 THEN
            ROUND(total_bid_amount / total_cost, 2)
        ELSE 0
    END AS cost_efficiency,
    -- 单项目平均成本
    CASE
        WHEN total_projects > 0 THEN
            ROUND(total_cost / total_projects, 2)
        ELSE 0
    END AS avg_project_cost,
    -- 成本增长趋势
    LAG(total_cost) OVER (ORDER BY report_month) AS last_month_cost,
    CASE
        WHEN LAG(total_cost) OVER (ORDER BY report_month) > 0 THEN
            ROUND((total_cost - LAG(total_cost) OVER (ORDER BY report_month)) / LAG(total_cost) OVER (ORDER BY report_month) * 100, 2)
        ELSE NULL
    END AS cost_growth_rate,
    -- 效率改善趋势
    CASE
        WHEN profit_margin > LAG(profit_margin) OVER (ORDER BY report_month) THEN '效率提升'
        WHEN profit_margin < LAG(profit_margin) OVER (ORDER BY report_month) THEN '效率下降'
        ELSE '效率稳定'
    END AS efficiency_trend
FROM v_monthly_overview
ORDER BY report_month DESC;

COMMENT ON VIEW v_monthly_cost_efficiency_trend IS '月度成本效率趋势分析视图';

-- 2.3 项目成本周期分析（按项目周期分类）
-- =============================================
CREATE OR REPLACE VIEW v_project_cycle_cost_analysis AS
SELECT
    DATE_FORMAT(spi.bid_date, '%Y-%m') AS report_month,
    -- 项目周期分类
    CASE
        WHEN DATEDIFF(DAY, spt.project_start_date, spt.project_end_date) <= 30 THEN '短期项目（≤30天）'
        WHEN DATEDIFF(DAY, spt.project_start_date, spt.project_end_date) <= 90 THEN '中期项目（31-90天）'
        WHEN DATEDIFF(DAY, spt.project_start_date, spt.project_end_date) <= 180 THEN '长期项目（91-180天）'
        ELSE '超长期项目（>180天）'
    END AS project_cycle_type,
    -- 统计指标
    COUNT(DISTINCT spi.contract_no) AS project_count,
    SUM(spi.bid_amount) AS total_bid_amount,
    COALESCE(SUM(sci.cost_amount), 0) AS total_cost,
    SUM(spi.bid_amount) - COALESCE(SUM(sci.cost_amount), 0) AS profit,
    CASE
        WHEN SUM(spi.bid_amount) > 0 THEN
            ROUND((SUM(spi.bid_amount) - COALESCE(SUM(sci.cost_amount), 0)) / SUM(spi.bid_amount) * 100, 2)
        ELSE 0
    END AS profit_margin,
    -- 日均成本
    CASE
        WHEN SUM(DATEDIFF(DAY, spt.project_start_date, spt.project_end_date)) > 0 THEN
            ROUND(COALESCE(SUM(sci.cost_amount), 0) / SUM(DATEDIFF(DAY, spt.project_start_date, spt.project_end_date)), 2)
        ELSE 0
    END AS avg_daily_cost,
    -- 成本效率排名
    ROW_NUMBER() OVER (PARTITION BY DATE_FORMAT(spi.bid_date, '%Y-%m') ORDER BY CASE WHEN SUM(spi.bid_amount) > 0 THEN ROUND((SUM(spi.bid_amount) - COALESCE(SUM(sci.cost_amount), 0)) / SUM(spi.bid_amount) * 100, 2) ELSE 0 END DESC) AS efficiency_rank
FROM sales_project_info spi
INNER JOIN sales_process_tracking spt ON spi.contract_no = spt.contract_no
LEFT JOIN sales_cost_info sci ON spi.contract_no = sci.contract_no
WHERE spi.is_valid = 1 AND spt.project_end_date IS NOT NULL
GROUP BY DATE_FORMAT(spi.bid_date, '%Y-%m'),
         CASE
            WHEN DATEDIFF(DAY, spt.project_start_date, spt.project_end_date) <= 30 THEN '短期项目（≤30天）'
            WHEN DATEDIFF(DAY, spt.project_start_date, spt.project_end_date) <= 90 THEN '中期项目（31-90天）'
            WHEN DATEDIFF(DAY, spt.project_start_date, spt.project_end_date) <= 180 THEN '长期项目（91-180天）'
            ELSE '超长期项目（>180天）'
         END
ORDER BY report_month DESC, profit_margin DESC;

COMMENT ON VIEW v_project_cycle_cost_analysis IS '项目成本周期分析视图';

-- =============================================
-- 第三部分：回款周期分析报表
-- =============================================

-- 3.1 月度回款情况分析
-- =============================================
CREATE OR REPLACE VIEW v_monthly_payment_analysis AS
SELECT
    DATE_FORMAT(spi2.actual_date, '%Y-%m') AS report_month,
    -- 回款阶段统计
    COUNT(DISTINCT CASE WHEN spi2.payment_stage = '预付款' THEN spi.contract_no END) AS advance_payment_count,
    SUM(CASE WHEN spi2.payment_stage = '预付款' THEN spi2.actual_amount ELSE 0 END) AS advance_payment_amount,
    COUNT(DISTINCT CASE WHEN spi2.payment_stage = '进度款' THEN spi.contract_no END) AS progress_payment_count,
    SUM(CASE WHEN spi2.payment_stage = '进度款' THEN spi2.actual_amount ELSE 0 END) AS progress_payment_amount,
    COUNT(DISTINCT CASE WHEN spi2.payment_stage = '尾款' THEN spi.contract_no END) AS final_payment_count,
    SUM(CASE WHEN spi2.payment_stage = '尾款' THEN spi2.actual_amount ELSE 0 END) AS final_payment_amount,
    -- 总回款统计
    COUNT(DISTINCT spi.contract_no) AS project_count,
    SUM(spi2.actual_amount) AS total_payment,
    AVG(spi2.actual_amount) AS avg_payment,
    -- 回款率统计
    SUM(spi.bid_amount) AS total_bid_amount,
    CASE
        WHEN SUM(spi.bid_amount) > 0 THEN
            ROUND(SUM(spi2.actual_amount) / SUM(spi.bid_amount) * 100, 2)
        ELSE 0
    END AS overall_payment_rate,
    -- 回款周期统计
    AVG(DATEDIFF(DAY, spi.bid_date, spi2.actual_date)) AS avg_payment_cycle,
    MIN(DATEDIFF(DAY, spi.bid_date, spi2.actual_date)) AS min_payment_cycle,
    MAX(DATEDIFF(DAY, spi.bid_date, spi2.actual_date)) AS max_payment_cycle,
    -- 超期回款统计
    COUNT(CASE WHEN DATEDIFF(DAY, spi.bid_date, spi2.actual_date) > 90 THEN 1 END) AS overdue_count,
    SUM(CASE WHEN DATEDIFF(DAY, spi.bid_date, spi2.actual_date) > 90 THEN spi2.actual_amount ELSE 0 END) AS overdue_amount,
    -- 同比分析
    LAG(SUM(spi2.actual_amount)) OVER (ORDER BY DATE_FORMAT(spi2.actual_date, '%Y-%m')) AS last_month_payment,
    CASE
        WHEN LAG(SUM(spi2.actual_amount)) OVER (ORDER BY DATE_FORMAT(spi2.actual_date, '%Y-%m')) > 0 THEN
            ROUND((SUM(spi2.actual_amount) - LAG(SUM(spi2.actual_amount)) OVER (ORDER BY DATE_FORMAT(spi2.actual_date, '%Y-%m'))) /
                  LAG(SUM(spi2.actual_amount)) OVER (ORDER BY DATE_FORMAT(spi2.actual_date, '%Y-%m')) * 100, 2)
        ELSE NULL
    END AS month_growth_rate
FROM sales_project_info spi
INNER JOIN sales_payment_info spi2 ON spi.contract_no = spi2.contract_no
WHERE spi.is_valid = 1 AND spi2.actual_date IS NOT NULL
GROUP BY DATE_FORMAT(spi2.actual_date, '%Y-%m')
ORDER BY report_month DESC;

COMMENT ON VIEW v_monthly_payment_analysis IS '月度回款情况分析视图';

-- 3.2 区域回款周期对比分析
-- =============================================
CREATE OR REPLACE VIEW v_regional_payment_cycle_comparison AS
SELECT
    DATE_FORMAT(spi2.actual_date, '%Y-%m') AS report_month,
    spi.province AS region,
    -- 回款金额统计
    SUM(spi2.actual_amount) AS total_payment,
    COUNT(DISTINCT spi.contract_no) AS project_count,
    AVG(spi2.actual_amount) AS avg_payment,
    -- 回款周期统计
    AVG(DATEDIFF(DAY, spi.bid_date, spi2.actual_date)) AS avg_payment_cycle,
    -- 回款率统计
    SUM(spi.bid_amount) AS total_bid_amount,
    CASE
        WHEN SUM(spi.bid_amount) > 0 THEN
            ROUND(SUM(spi2.actual_amount) / SUM(spi.bid_amount) * 100, 2)
        ELSE 0
    END AS payment_rate,
    -- 超期回款统计
    COUNT(CASE WHEN DATEDIFF(DAY, spi.bid_date, spi2.actual_date) > 90 THEN 1 END) AS overdue_count,
    CASE
        WHEN COUNT(DISTINCT spi.contract_no) > 0 THEN
            ROUND(COUNT(CASE WHEN DATEDIFF(DAY, spi.bid_date, spi2.actual_date) > 90 THEN 1 END) * 100.0 / COUNT(DISTINCT spi.contract_no), 2)
        ELSE 0
    END AS overdue_rate,
    -- 回款效率评分
    CASE
        WHEN AVG(DATEDIFF(DAY, spi.bid_date, spi2.actual_date)) <= 60 THEN '高效'
        WHEN AVG(DATEDIFF(DAY, spi.bid_date, spi2.actual_date)) <= 90 THEN '正常'
        WHEN AVG(DATEDIFF(DAY, spi.bid_date, spi2.actual_date)) <= 120 THEN '偏慢'
        ELSE '缓慢'
    END AS payment_efficiency,
    -- 区域排名
    ROW_NUMBER() OVER (PARTITION BY DATE_FORMAT(spi2.actual_date, '%Y-%m') ORDER BY AVG(DATEDIFF(DAY, spi.bid_date, spi2.actual_date)) ASC) AS cycle_rank,
    ROW_NUMBER() OVER (PARTITION BY DATE_FORMAT(spi2.actual_date, '%Y-%m') ORDER BY SUM(spi2.actual_amount) DESC) AS amount_rank
FROM sales_project_info spi
INNER JOIN sales_payment_info spi2 ON spi.contract_no = spi2.contract_no
WHERE spi.is_valid = 1 AND spi2.actual_date IS NOT NULL
GROUP BY DATE_FORMAT(spi2.actual_date, '%Y-%m'), spi.province
ORDER BY report_month DESC, avg_payment_cycle DESC;

COMMENT ON VIEW v_regional_payment_cycle_comparison IS '区域回款周期对比分析视图';

-- 3.3 未回款项目预警分析
-- =============================================
CREATE OR REPLACE VIEW v_unpaid_project_alert AS
SELECT
    spi.contract_no,
    spi.project_name,
    spi.customer_name,
    spi.province AS region,
    spi.bid_date,
    spi.bid_amount,
    -- 已回款金额
    COALESCE(SUM(spi2.actual_amount), 0) AS paid_amount,
    spi.bid_amount - COALESCE(SUM(spi2.actual_amount), 0) AS unpaid_amount,
    -- 超期天数
    DATEDIFF(DAY, spi.bid_date, CURRENT_DATE) AS overdue_days,
    -- 回款进度
    CASE
        WHEN spi.bid_amount > 0 THEN
            ROUND(COALESCE(SUM(spi2.actual_amount), 0) / spi.bid_amount * 100, 2)
        ELSE 0
    END AS payment_progress,
    -- 预警等级
    CASE
        WHEN DATEDIFF(DAY, spi.bid_date, CURRENT_DATE) > 180 AND COALESCE(SUM(spi2.actual_amount), 0) < spi.bid_amount * 0.5 THEN '红色预警'
        WHEN DATEDIFF(DAY, spi.bid_date, CURRENT_DATE) > 120 AND COALESCE(SUM(spi2.actual_amount), 0) < spi.bid_amount * 0.7 THEN '橙色预警'
        WHEN DATEDIFF(DAY, spi.bid_date, CURRENT_DATE) > 90 AND COALESCE(SUM(spi2.actual_amount), 0) < spi.bid_amount * 0.8 THEN '黄色预警'
        ELSE '正常'
    END AS alert_level,
    -- 预计损失金额
    CASE
        WHEN DATEDIFF(DAY, spi.bid_date, CURRENT_DATE) > 180 THEN
            ROUND((spi.bid_amount - COALESCE(SUM(spi2.actual_amount), 0)) * 0.3, 2)
        ELSE 0
    END AS estimated_loss
FROM sales_project_info spi
LEFT JOIN sales_payment_info spi2 ON spi.contract_no = spi2.contract_no
WHERE spi.is_valid = 1
  AND spi.bid_date <= CURRENT_DATE
  AND COALESCE(SUM(spi2.actual_amount), 0) < spi.bid_amount
GROUP BY spi.contract_no, spi.project_name, spi.customer_name, spi.province, spi.bid_date, spi.bid_amount
HAVING DATEDIFF(DAY, spi.bid_date, CURRENT_DATE) > 60
ORDER BY overdue_days DESC, unpaid_amount DESC;

COMMENT ON VIEW v_unpaid_project_alert IS '未回款项目预警分析视图';

-- =============================================
-- 第四部分：经营决策支持报表
-- =============================================

-- 4.1 月度经营决策关键指标
-- =============================================
CREATE OR REPLACE VIEW v_monthly_decision_key_indicators AS
SELECT
    mo.report_month,
    -- 财务指标
    mo.total_bid_amount AS sales_volume,
    mo.total_profit AS gross_profit,
    mo.profit_margin AS profit_margin,
    mo.total_payment AS cash_flow,
    mo.payment_rate AS cash_collection_rate,
    -- 运营指标
    mo.avg_payment_cycle AS payment_cycle,
    mo.conversion_rate AS conversion_rate,
    mo.total_projects AS project_volume,
    -- 成本指标
    mo.total_cost AS total_cost,
    CASE
        WHEN mo.total_projects > 0 THEN
            ROUND(mo.total_cost / mo.total_projects, 2)
        ELSE 0
    END AS avg_cost_per_project,
    -- 效率指标
    CASE
        WHEN mo.total_cost > 0 THEN
            ROUND(mo.total_bid_amount / mo.total_cost, 2)
        ELSE 0
    END AS cost_efficiency,
    -- 环比增长率
    LAG(mo.total_bid_amount) OVER (ORDER BY mo.report_month) AS last_month_sales,
    CASE
        WHEN LAG(mo.total_bid_amount) OVER (ORDER BY mo.report_month) > 0 THEN
            ROUND((mo.total_bid_amount - LAG(mo.total_bid_amount) OVER (ORDER BY mo.report_month)) /
                  LAG(mo.total_bid_amount) OVER (ORDER BY mo.report_month) * 100, 2)
        ELSE NULL
    END AS sales_growth_rate,
    -- 经营健康度评分
    CASE
        WHEN mo.profit_margin >= 25 AND mo.payment_rate >= 70 AND mo.conversion_rate >= 35 THEN '优秀'
        WHEN mo.profit_margin >= 20 AND mo.payment_rate >= 60 AND mo.conversion_rate >= 30 THEN '良好'
        WHEN mo.profit_margin >= 15 AND mo.payment_rate >= 50 AND mo.conversion_rate >= 25 THEN '一般'
        ELSE '待改进'
    END AS business_health_level,
    -- 经营建议
    CASE
        WHEN mo.profit_margin < 15 THEN '建议优化成本结构，提升利润率'
        WHEN mo.payment_rate < 60 THEN '建议加强回款管理，缩短回款周期'
        WHEN mo.conversion_rate < 25 THEN '建议提升销售技能，提高转化率'
        WHEN mo.avg_payment_cycle > 90 THEN '建议优化回款流程，加快资金回收'
        ELSE '经营状况良好，建议继续保持'
    END AS business_suggestion
FROM v_monthly_overview mo
ORDER BY mo.report_month DESC;

COMMENT ON VIEW v_monthly_decision_key_indicators IS '月度经营决策关键指标视图';

-- 4.2 区域经营决策建议
-- =============================================
CREATE OR REPLACE VIEW v_regional_decision_recommendations AS
SELECT
    report_month,
    region,
    -- 优势分析
    CASE
        WHEN profit_rank <= 3 THEN '利润率高'
        WHEN amount_rank <= 3 THEN '销售规模大'
        ELSE '无明显优势'
    END AS strength,
    -- 问题分析
    CASE
        WHEN profit_margin < 15 THEN '利润率偏低'
        WHEN payment_rate < 60 THEN '回款率偏低'
        WHEN conversion_rate < 25 THEN '转化率偏低'
        WHEN avg_payment_cycle > 120 THEN '回款周期过长'
        ELSE '无明显问题'
    END AS weakness,
    -- 改进建议
    CASE
        WHEN profit_margin < 15 THEN '建议：优化成本控制，提升项目利润率'
        WHEN payment_rate < 60 THEN '建议：加强客户回款跟进，完善回款激励机制'
        WHEN conversion_rate < 25 THEN '建议：加强销售培训，优化客户跟进策略'
        WHEN avg_payment_cycle > 120 THEN '建议：缩短项目周期，加快回款流程'
        ELSE '建议：继续保持现有经营策略'
    END AS improvement_recommendation,
    -- 资源配置建议
    CASE
        WHEN total_amount >= 500 THEN '建议增加资源投入，扩大市场份额'
        WHEN total_amount >= 200 AND profit_margin >= 20 THEN '建议维持现有投入，优化资源配置'
        ELSE '建议控制投入成本，聚焦重点客户'
    END AS resource_allocation_suggestion,
    -- 重点跟进事项
    CASE
        WHEN year_growth_rate < 0 THEN '重点关注：同比增长下滑，需分析原因'
        WHEN year_growth_rate > 50 THEN '重点关注：快速增长，需确保服务质量'
        ELSE '正常运营'
    END AS focus_item
FROM v_monthly_regional_report;

COMMENT ON VIEW v_regional_decision_recommendations IS '区域经营决策建议视图';

-- 4.3 月度经营总结报告生成
-- =============================================
CREATE OR REPLACE PROCEDURE sp_generate_monthly_report(
    IN p_year INT,
    IN p_month INT
)
AS
    v_report_month VARCHAR(7);
    v_total_projects INTEGER;
    v_total_amount DECIMAL(18,2);
    v_total_profit DECIMAL(18,2);
    v_profit_margin DECIMAL(5,2);
    v_payment_rate DECIMAL(5,2);
    v_conversion_rate DECIMAL(5,2);
BEGIN
    v_report_month := p_year || '-' || LPAD(p_month, 2, '0');

    -- 获取关键数据
    SELECT
        total_projects, total_bid_amount, total_profit, profit_margin, payment_rate, conversion_rate
    INTO v_total_projects, v_total_amount, v_total_profit, v_profit_margin, v_payment_rate, v_conversion_rate
    FROM v_monthly_overview
    WHERE report_month = v_report_month;

    -- 输出月度经营总结
    DBMS_OUTPUT.PUT_LINE('========== ' || v_report_month || ' 月度经营分析报告 ==========');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('一、整体经营概况');
    DBMS_OUTPUT.PUT_LINE('  项目总数：' || v_total_projects || ' 个');
    DBMS_OUTPUT.PUT_LINE('  中标总额：' || v_total_amount || ' 万元');
    DBMS_OUTPUT.PUT_LINE('  利润总额：' || v_total_profit || ' 万元');
    DBMS_OUTPUT.PUT_LINE('  利润率：' || v_profit_margin || '%');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('二、回款情况分析');
    DBMS_OUTPUT.PUT_LINE('  回款率：' || v_payment_rate || '%');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('三、转化效率分析');
    DBMS_OUTPUT.PUT_LINE('  转化率：' || v_conversion_rate || '%');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('四、经营建议');
    DBMS_OUTPUT.PUT_LINE('  建议：根据各项指标情况，优化经营策略，提升整体效益');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('========================================');
END;
/

-- =============================================
-- 第五部分：报表导出模板
-- =============================================

-- 5.1 经营分析报表导出视图（CSV格式）
-- =============================================
CREATE OR REPLACE VIEW v_report_export_template AS
SELECT
    mo.report_month AS '报告月份',
    mo.total_projects AS '项目总数',
    mo.total_bid_amount AS '中标总额（万元）',
    mo.total_cost AS '总成本（万元）',
    mo.total_profit AS '利润总额（万元）',
    mo.profit_margin AS '利润率（%）',
    mo.total_payment AS '回款总额（万元）',
    mo.payment_rate AS '回款率（%）',
    mo.avg_payment_cycle AS '平均回款周期（天）',
    mo.conversion_rate AS '转化率（%）',
    mo.new_customer_rate AS '新客户占比（%）',
    CASE
        WHEN mo.profit_margin >= 25 THEN '优秀'
        WHEN mo.profit_margin >= 20 THEN '良好'
        WHEN mo.profit_margin >= 15 THEN '一般'
        ELSE '待改进'
    END AS '经营状况评级'
FROM v_monthly_overview mo
ORDER BY mo.report_month DESC;

COMMENT ON VIEW v_report_export_template IS '经营分析报表导出模板视图';

-- 5.2 区域经营分析报表导出视图
-- =============================================
CREATE OR REPLACE VIEW v_regional_report_export_template AS
SELECT
    mrr.report_month AS '报告月份',
    mrr.region AS '区域',
    mrr.project_count AS '项目数量',
    mrr.total_amount AS '中标金额（万元）',
    mrr.total_cost AS '成本（万元）',
    mrr.profit AS '利润（万元）',
    mrr.profit_margin AS '利润率（%）',
    mrr.total_payment AS '回款（万元）',
    mrr.payment_rate AS '回款率（%）',
    mrr.avg_payment_cycle AS '回款周期（天）',
    mrr.conversion_rate AS '转化率（%）',
    mrr.year_growth_rate AS '同比增长（%）',
    mrr.amount_rank AS '金额排名',
    mrr.profit_rank AS '利润率排名'
FROM v_monthly_regional_report mrr
ORDER BY mrr.report_month DESC, mrr.total_amount DESC;

COMMENT ON VIEW v_regional_report_export_template IS '区域经营分析报表导出模板视图';

-- =============================================
-- 测试查询
-- =============================================

-- 测试月度整体经营概览
SELECT * FROM v_monthly_overview;

-- 测试月度区域经营分析
SELECT * FROM v_monthly_regional_report LIMIT 10;

-- 测试月度成本构成分析
SELECT * FROM v_monthly_cost_structure;

-- 测试月度回款情况分析
SELECT * FROM v_monthly_payment_analysis;

-- 测试月度经营决策关键指标
SELECT * FROM v_monthly_decision_key_indicators;

-- 测试未回款项目预警
SELECT * FROM v_unpaid_project_alert;