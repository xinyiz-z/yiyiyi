-- =============================================
-- 达梦数据库 - 销售过程分析指标体系
-- 功能：搭建完整销售过程分析指标体系，定位各区域获客、转化短板
-- 作者：数据运营团队
-- 创建时间：2026-06-26
-- =============================================

-- =============================================
-- 第一部分：获客能力指标
-- =============================================

-- 1.1 区域获客能力分析
-- =============================================
CREATE OR REPLACE VIEW v_regional_customer_acquisition AS
SELECT
    province AS region,
    -- 线索数量
    COUNT(DISTINCT CASE WHEN spt.lead_date IS NOT NULL THEN spi.contract_no END) AS total_leads,
    -- 新客户数量（首次合作）
    COUNT(DISTINCT CASE WHEN spi.customer_name NOT IN (SELECT customer_name FROM sales_project_info WHERE bid_date < DATE '2024-01-01') THEN spi.contract_no END) AS new_customers,
    -- 老客户数量（二次及以上合作）
    COUNT(DISTINCT CASE WHEN spi.customer_name IN (SELECT customer_name FROM sales_project_info WHERE bid_date < DATE '2024-01-01') THEN spi.contract_no END) AS repeat_customers,
    -- 获客成本（平均每个线索的成本）
    CASE
        WHEN COUNT(DISTINCT CASE WHEN spt.lead_date IS NOT NULL THEN spi.contract_no END) > 0 THEN
            ROUND(COALESCE(SUM(sci.cost_amount), 0) / COUNT(DISTINCT CASE WHEN spt.lead_date IS NOT NULL THEN spi.contract_no END), 2)
        ELSE 0
    END AS avg_acquisition_cost,
    -- 获客渠道分布
    COUNT(DISTINCT CASE WHEN spt.lead_source = '官网' THEN spi.contract_no END) AS website_leads,
    COUNT(DISTINCT CASE WHEN spt.lead_source = '展会' THEN spi.contract_no END) AS exhibition_leads,
    COUNT(DISTINCT CASE WHEN spt.lead_source = '电话营销' THEN spi.contract_no END) AS telemarketing_leads,
    COUNT(DISTINCT CASE WHEN spt.lead_source = '渠道合作' THEN spi.contract_no END) AS partner_leads,
    -- 客户覆盖行业
    COUNT(DISTINCT spi.project_category) AS industry_coverage,
    -- 获客评分（综合评价）
    CASE
        WHEN COUNT(DISTINCT CASE WHEN spt.lead_date IS NOT NULL THEN spi.contract_no END) >= 50 AND
             COUNT(DISTINCT CASE WHEN spi.customer_name NOT IN (SELECT customer_name FROM sales_project_info WHERE bid_date < DATE '2024-01-01') THEN spi.contract_no END) >= 30 THEN '优秀'
        WHEN COUNT(DISTINCT CASE WHEN spt.lead_date IS NOT NULL THEN spi.contract_no END) >= 30 THEN '良好'
        WHEN COUNT(DISTINCT CASE WHEN spt.lead_date IS NOT NULL THEN spi.contract_no END) >= 20 THEN '一般'
        ELSE '待改进'
    END AS acquisition_grade
FROM sales_project_info spi
LEFT JOIN sales_process_tracking spt ON spi.contract_no = spt.contract_no
LEFT JOIN sales_cost_info sci ON spi.contract_no = sci.contract_no
WHERE spi.is_valid = 1
GROUP BY province
ORDER BY total_leads DESC;

COMMENT ON VIEW v_regional_customer_acquisition IS '区域获客能力分析视图';

-- 1.2 行业获客分布分析
-- =============================================
CREATE OR REPLACE VIEW v_industry_customer_distribution AS
SELECT
    project_category AS industry,
    secondary_category AS sub_industry,
    COUNT(DISTINCT customer_name) AS customer_count,
    COUNT(DISTINCT contract_no) AS project_count,
    SUM(bid_amount) AS total_amount,
    AVG(bid_amount) AS avg_project_amount,
    -- TOP客户占比
    SUM(CASE WHEN bid_amount >= 100 THEN bid_amount ELSE 0 END) AS top_project_amount,
    CASE
        WHEN SUM(bid_amount) > 0 THEN
            ROUND(SUM(CASE WHEN bid_amount >= 100 THEN bid_amount ELSE 0 END) / SUM(bid_amount) * 100, 2)
        ELSE 0
    END AS top_project_ratio,
    -- 行业潜力评估
    CASE
        WHEN COUNT(DISTINCT customer_name) >= 10 AND SUM(bid_amount) >= 500 THEN '重点行业'
        WHEN COUNT(DISTINCT customer_name) >= 5 THEN '潜力行业'
        ELSE '一般行业'
    END AS industry_potential
FROM sales_project_info
WHERE is_valid = 1
GROUP BY project_category, secondary_category
ORDER BY total_amount DESC;

COMMENT ON VIEW v_industry_customer_distribution IS '行业获客分布分析视图';

-- 1.3 客户价值分层分析
-- =============================================
CREATE OR REPLACE VIEW v_customer_value_segmentation AS
SELECT
    customer_name,
    COUNT(*) AS project_count,
    SUM(bid_amount) AS total_amount,
    AVG(bid_amount) AS avg_amount,
    MAX(bid_amount) AS max_amount,
    MIN(bid_date) AS first_cooperation,
    MAX(bid_date) AS latest_cooperation,
    DATEDIFF(MONTH, MIN(bid_date), MAX(bid_date)) AS cooperation_duration,
    -- 客户活跃度（最近合作时间）
    CASE
        WHEN DATEDIFF(DAY, MAX(bid_date), CURRENT_DATE) <= 90 THEN '活跃'
        WHEN DATEDIFF(DAY, MAX(bid_date), CURRENT_DATE) <= 180 THEN '稳定'
        WHEN DATEDIFF(DAY, MAX(bid_date), CURRENT_DATE) <= 365 THEN '潜在流失'
        ELSE '已流失'
    END AS activity_status,
    -- 客户价值分层
    CASE
        WHEN SUM(bid_amount) >= 500 AND COUNT(*) >= 5 THEN '战略客户'
        WHEN SUM(bid_amount) >= 200 AND COUNT(*) >= 3 THEN '重点客户'
        WHEN SUM(bid_amount) >= 50 THEN '一般客户'
        ELSE '小型客户'
    END AS customer_level
FROM sales_project_info
WHERE is_valid = 1
GROUP BY customer_name
ORDER BY total_amount DESC;

COMMENT ON VIEW v_customer_value_segmentation IS '客户价值分层分析视图';

-- =============================================
-- 第二部分：转化能力指标
-- =============================================

-- 2.1 区域转化能力对比
-- =============================================
CREATE OR REPLACE VIEW v_regional_conversion_ability AS
SELECT
    province AS region,
    -- 线索到商机转化率
    COUNT(CASE WHEN spt.conversion_status = '线索' THEN 1 END) AS lead_count,
    COUNT(CASE WHEN spt.conversion_status = '商机' THEN 1 END) AS opportunity_count,
    CASE
        WHEN COUNT(CASE WHEN spt.conversion_status = '线索' THEN 1 END) > 0 THEN
            ROUND(COUNT(CASE WHEN spt.conversion_status = '商机' THEN 1 END) * 100.0 /
                  COUNT(CASE WHEN spt.conversion_status = '线索' THEN 1 END), 2)
        ELSE 0
    END AS lead_to_opportunity_rate,
    -- 商机到中标转化率
    COUNT(CASE WHEN spt.conversion_status = '中标' THEN 1 END) AS bid_won_count,
    CASE
        WHEN COUNT(CASE WHEN spt.conversion_status = '商机' THEN 1 END) > 0 THEN
            ROUND(COUNT(CASE WHEN spt.conversion_status = '中标' THEN 1 END) * 100.0 /
                  COUNT(CASE WHEN spt.conversion_status = '商机' THEN 1 END), 2)
        ELSE 0
    END AS opportunity_to_bid_rate,
    -- 中标到签约转化率
    COUNT(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 END) AS signed_count,
    CASE
        WHEN COUNT(CASE WHEN spt.conversion_status = '中标' THEN 1 END) > 0 THEN
            ROUND(COUNT(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 END) * 100.0 /
                  COUNT(CASE WHEN spt.conversion_status = '中标' THEN 1 END), 2)
        ELSE 0
    END AS bid_to_sign_rate,
    -- 整体转化率
    CASE
        WHEN COUNT(CASE WHEN spt.conversion_status = '线索' THEN 1 END) > 0 THEN
            ROUND(COUNT(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 END) * 100.0 /
                  COUNT(CASE WHEN spt.conversion_status = '线索' THEN 1 END), 2)
        ELSE 0
    END AS overall_conversion_rate,
    -- 平均转化周期
    AVG(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN DATEDIFF(DAY, spt.lead_date, spt.contract_sign_date) END) AS avg_conversion_days,
    -- 转化能力评分
    CASE
        WHEN COUNT(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 END) * 100.0 / COUNT(CASE WHEN spt.conversion_status = '线索' THEN 1 END) >= 40 THEN '优秀'
        WHEN COUNT(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 END) * 100.0 / COUNT(CASE WHEN spt.conversion_status = '线索' THEN 1 END) >= 30 THEN '良好'
        WHEN COUNT(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 END) * 100.0 / COUNT(CASE WHEN spt.conversion_status = '线索' THEN 1 END) >= 20 THEN '一般'
        ELSE '待改进'
    END AS conversion_grade
FROM sales_project_info spi
INNER JOIN sales_process_tracking spt ON spi.contract_no = spt.contract_no
WHERE spi.is_valid = 1
GROUP BY province
ORDER BY overall_conversion_rate DESC;

COMMENT ON VIEW v_regional_conversion_ability IS '区域转化能力对比视图';

-- 2.2 行业转化效率分析
-- =============================================
CREATE OR REPLACE VIEW v_industry_conversion_efficiency AS
SELECT
    project_category AS industry,
    secondary_category AS sub_industry,
    -- 线索数量
    COUNT(CASE WHEN spt.conversion_status = '线索' THEN 1 END) AS lead_count,
    -- 签约数量
    COUNT(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 END) AS signed_count,
    -- 转化率
    CASE
        WHEN COUNT(CASE WHEN spt.conversion_status = '线索' THEN 1 END) > 0 THEN
            ROUND(COUNT(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 END) * 100.0 /
                  COUNT(CASE WHEN spt.conversion_status = '线索' THEN 1 END), 2)
        ELSE 0
    END AS conversion_rate,
    -- 签约金额
    SUM(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN spi.bid_amount ELSE 0 END) AS signed_amount,
    -- 平均转化周期
    AVG(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN DATEDIFF(DAY, spt.lead_date, spt.contract_sign_date) END) AS avg_conversion_days,
    -- 行业转化难度评估
    CASE
        WHEN CASE WHEN COUNT(CASE WHEN spt.conversion_status = '线索' THEN 1 END) > 0 THEN
            ROUND(COUNT(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 END) * 100.0 /
                  COUNT(CASE WHEN spt.conversion_status = '线索' THEN 1 END), 2)
        ELSE 0 END >= 50 THEN '容易转化'
        WHEN CASE WHEN COUNT(CASE WHEN spt.conversion_status = '线索' THEN 1 END) > 0 THEN
            ROUND(COUNT(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 END) * 100.0 /
                  COUNT(CASE WHEN spt.conversion_status = '线索' THEN 1 END), 2)
        ELSE 0 END >= 30 THEN '中等难度'
        ELSE '转化困难'
    END AS conversion_difficulty
FROM sales_project_info spi
INNER JOIN sales_process_tracking spt ON spi.contract_no = spt.contract_no
WHERE spi.is_valid = 1
GROUP BY project_category, secondary_category
ORDER BY conversion_rate DESC;

COMMENT ON VIEW v_industry_conversion_efficiency IS '行业转化效率分析视图';

-- 2.3 销售阶段瓶颈分析
-- =============================================
CREATE OR REPLACE VIEW v_sales_stage_bottleneck AS
SELECT
    '线索阶段' AS stage_name,
    COUNT(CASE WHEN spt.conversion_status = '线索' THEN 1 END) AS current_count,
    COUNT(CASE WHEN spt.lead_date IS NOT NULL THEN 1 END) AS total_count,
    CASE
        WHEN COUNT(CASE WHEN spt.lead_date IS NOT NULL THEN 1 END) > 0 THEN
            ROUND(COUNT(CASE WHEN spt.conversion_status = '线索' THEN 1 END) * 100.0 /
                  COUNT(CASE WHEN spt.lead_date IS NOT NULL THEN 1 END), 2)
        ELSE 0
    END AS retention_rate,
    '线索积累阶段' AS bottleneck_description
FROM sales_process_tracking spt
UNION ALL
SELECT
    '商机阶段' AS stage_name,
    COUNT(CASE WHEN spt.conversion_status = '商机' THEN 1 END) AS current_count,
    COUNT(CASE WHEN spt.contact_date IS NOT NULL THEN 1 END) AS total_count,
    CASE
        WHEN COUNT(CASE WHEN spt.contact_date IS NOT NULL THEN 1 END) > 0 THEN
            ROUND(COUNT(CASE WHEN spt.conversion_status = '商机' THEN 1 END) * 100.0 /
                  COUNT(CASE WHEN spt.contact_date IS NOT NULL THEN 1 END), 2)
        ELSE 0
    END AS retention_rate,
    '需求挖掘阶段' AS bottleneck_description
FROM sales_process_tracking spt
UNION ALL
SELECT
    '方案阶段' AS stage_name,
    COUNT(CASE WHEN spt.proposal_date IS NOT NULL AND spt.negotiation_date IS NULL THEN 1 END) AS current_count,
    COUNT(CASE WHEN spt.proposal_date IS NOT NULL THEN 1 END) AS total_count,
    CASE
        WHEN COUNT(CASE WHEN spt.proposal_date IS NOT NULL THEN 1 END) > 0 THEN
            ROUND(COUNT(CASE WHEN spt.proposal_date IS NOT NULL AND spt.negotiation_date IS NULL THEN 1 END) * 100.0 /
                  COUNT(CASE WHEN spt.proposal_date IS NOT NULL THEN 1 END), 2)
        ELSE 0
    END AS retention_rate,
    '方案设计阶段' AS bottleneck_description
FROM sales_process_tracking spt
UNION ALL
SELECT
    '谈判阶段' AS stage_name,
    COUNT(CASE WHEN spt.negotiation_date IS NOT NULL AND spt.bid_date IS NULL THEN 1 END) AS current_count,
    COUNT(CASE WHEN spt.negotiation_date IS NOT NULL THEN 1 END) AS total_count,
    CASE
        WHEN COUNT(CASE WHEN spt.negotiation_date IS NOT NULL THEN 1 END) > 0 THEN
            ROUND(COUNT(CASE WHEN spt.negotiation_date IS NOT NULL AND spt.bid_date IS NULL THEN 1 END) * 100.0 /
                  COUNT(CASE WHEN spt.negotiation_date IS NOT NULL THEN 1 END), 2)
        ELSE 0
    END AS retention_rate,
    '商务谈判阶段' AS bottleneck_description
FROM sales_process_tracking spt;

COMMENT ON VIEW v_sales_stage_bottleneck IS '销售阶段瓶颈分析视图';

-- =============================================
-- 第三部分：运营效率指标
-- =============================================

-- 3.1 项目执行效率分析
-- =============================================
CREATE OR REPLACE VIEW v_project_execution_efficiency AS
SELECT
    spi.contract_no,
    spi.project_name,
    spi.province,
    spi.project_category,
    -- 项目生命周期（从线索到完成）
    DATEDIFF(DAY, spt.lead_date, spt.project_end_date) AS total_cycle_days,
    -- 签约到启动时长
    DATEDIFF(DAY, spt.contract_sign_date, spt.project_start_date) AS sign_to_start_days,
    -- 项目执行时长
    DATEDIFF(DAY, spt.project_start_date, spt.project_end_date) AS execution_days,
    -- 成本效率（单位时间成本）
    CASE
        WHEN DATEDIFF(DAY, spt.project_start_date, spt.project_end_date) > 0 THEN
            ROUND(COALESCE(SUM(sci.cost_amount), 0) / DATEDIFF(DAY, spt.project_start_date, spt.project_end_date), 2)
        ELSE 0
    END AS daily_cost,
    -- 回款效率
    CASE
        WHEN DATEDIFF(DAY, spt.contract_sign_date, spi2.actual_date) > 0 THEN
            ROUND(SUM(spi2.actual_amount) / DATEDIFF(DAY, spt.contract_sign_date, spi2.actual_date), 2)
        ELSE 0
    END AS daily_payment,
    -- 执行效率评分
    CASE
        WHEN DATEDIFF(DAY, spt.lead_date, spt.project_end_date) <= 180 AND
             CASE WHEN DATEDIFF(DAY, spt.project_start_date, spt.project_end_date) > 0 THEN
                 ROUND(COALESCE(SUM(sci.cost_amount), 0) / DATEDIFF(DAY, spt.project_start_date, spt.project_end_date), 2)
             ELSE 0 END <= spi.bid_amount / 90 THEN '高效'
        WHEN DATEDIFF(DAY, spt.lead_date, spt.project_end_date) <= 365 THEN '正常'
        ELSE '低效'
    END AS efficiency_grade
FROM sales_project_info spi
INNER JOIN sales_process_tracking spt ON spi.contract_no = spt.contract_no
LEFT JOIN sales_cost_info sci ON spi.contract_no = sci.contract_no
LEFT JOIN sales_payment_info spi2 ON spi.contract_no = spi2.contract_no
WHERE spi.is_valid = 1 AND spt.project_end_date IS NOT NULL
GROUP BY spi.contract_no, spi.project_name, spi.province, spi.project_category,
         spt.lead_date, spt.contract_sign_date, spt.project_start_date, spt.project_end_date, spi.bid_amount;

COMMENT ON VIEW v_project_execution_efficiency IS '项目执行效率分析视图';

-- 3.2 资源利用效率分析
-- =============================================
CREATE OR REPLACE VIEW v_resource_utilization AS
SELECT
    province AS region,
    business_segment,
    -- 项目数量
    COUNT(DISTINCT spi.contract_no) AS project_count,
    -- 总投入成本
    SUM(sci.cost_amount) AS total_cost,
    -- 人力成本占比
    SUM(CASE WHEN sci.cost_type = '人力成本' THEN sci.cost_amount ELSE 0 END) AS labor_cost,
    CASE
        WHEN SUM(sci.cost_amount) > 0 THEN
            ROUND(SUM(CASE WHEN sci.cost_type = '人力成本' THEN sci.cost_amount ELSE 0 END) / SUM(sci.cost_amount) * 100, 2)
        ELSE 0
    END AS labor_cost_ratio,
    -- 采购成本占比
    SUM(CASE WHEN sci.cost_type = '采购成本' THEN sci.cost_amount ELSE 0 END) AS purchase_cost,
    CASE
        WHEN SUM(sci.cost_amount) > 0 THEN
            ROUND(SUM(CASE WHEN sci.cost_type = '采购成本' THEN sci.cost_amount ELSE 0 END) / SUM(sci.cost_amount) * 100, 2)
        ELSE 0
    END AS purchase_cost_ratio,
    -- 平均项目成本
    AVG(sci.cost_amount) AS avg_project_cost,
    -- 成本效率（成本利润率）
    SUM(spi.bid_amount) AS total_bid_amount,
    CASE
        WHEN SUM(sci.cost_amount) > 0 THEN
            ROUND((SUM(spi.bid_amount) - SUM(sci.cost_amount)) / SUM(sci.cost_amount) * 100, 2)
        ELSE 0
    END AS cost_profit_ratio
FROM sales_project_info spi
INNER JOIN sales_cost_info sci ON spi.contract_no = sci.contract_no
WHERE spi.is_valid = 1
GROUP BY province, business_segment
ORDER BY cost_profit_ratio DESC;

COMMENT ON VIEW v_resource_utilization AS '资源利用效率分析视图';

-- 3.3 回款效率分析
-- =============================================
CREATE OR REPLACE VIEW v_payment_efficiency AS
SELECT
    province AS region,
    -- 项目总数
    COUNT(DISTINCT spi.contract_no) AS total_projects,
    -- 已回款项目数
    COUNT(DISTINCT CASE WHEN SUM(spi2.actual_amount) >= spi.bid_amount * 0.8 THEN spi.contract_no END) AS well_paid_projects,
    -- 回款率
    CASE
        WHEN COUNT(DISTINCT spi.contract_no) > 0 THEN
            ROUND(COUNT(DISTINCT CASE WHEN SUM(spi2.actual_amount) >= spi.bid_amount * 0.8 THEN spi.contract_no END) * 100.0 /
                  COUNT(DISTINCT spi.contract_no), 2)
        ELSE 0
    END AS payment_completion_rate,
    -- 平均回款周期
    AVG(DATEDIFF(DAY, spi.bid_date, spi2.actual_date)) AS avg_payment_cycle,
    -- 超期回款项目数（超过90天）
    COUNT(DISTINCT CASE WHEN DATEDIFF(DAY, spi.bid_date, spi2.actual_date) > 90 THEN spi.contract_no END) AS overdue_projects,
    -- 回款效率评分
    CASE
        WHEN AVG(DATEDIFF(DAY, spi.bid_date, spi2.actual_date)) <= 60 THEN '高效'
        WHEN AVG(DATEDIFF(DAY, spi.bid_date, spi2.actual_date)) <= 90 THEN '正常'
        ELSE '低效'
    END AS payment_efficiency_grade
FROM sales_project_info spi
INNER JOIN sales_payment_info spi2 ON spi.contract_no = spi2.contract_no
WHERE spi.is_valid = 1
GROUP BY province
ORDER BY avg_payment_cycle DESC;

COMMENT ON VIEW v_payment_efficiency IS '回款效率分析视图';

-- =============================================
-- 第四部分：短板识别与改进建议
-- =============================================

-- 4.1 区域短板诊断报告
-- =============================================
CREATE OR REPLACE VIEW v_regional_weakness_diagnosis AS
SELECT
    province AS region,
    -- 获客短板
    CASE
        WHEN (SELECT total_leads FROM v_regional_customer_acquisition WHERE region = spi.province) < 20 THEN '获客数量不足'
        WHEN (SELECT new_customers FROM v_regional_customer_acquisition WHERE region = spi.province) <
             (SELECT repeat_customers FROM v_regional_customer_acquisition WHERE region = spi.province) * 0.3 THEN '新客户拓展乏力'
        ELSE '获客正常'
    END AS acquisition_weakness,
    -- 转化短板
    CASE
        WHEN (SELECT overall_conversion_rate FROM v_regional_conversion_ability WHERE region = spi.province) < 20 THEN '整体转化率低'
        WHEN (SELECT opportunity_to_bid_rate FROM v_regional_conversion_ability WHERE region = spi.province) < 30 THEN '商机转化困难'
        WHEN (SELECT bid_to_sign_rate FROM v_regional_conversion_ability WHERE region = spi.province) < 50 THEN '中标签约率低'
        ELSE '转化正常'
    END AS conversion_weakness,
    -- 回款短板
    CASE
        WHEN (SELECT avg_payment_cycle FROM v_payment_efficiency WHERE region = spi.province) > 120 THEN '回款周期过长'
        WHEN (SELECT payment_completion_rate FROM v_payment_efficiency WHERE region = spi.province) < 50 THEN '回款完成率低'
        ELSE '回款正常'
    END AS payment_weakness,
    -- 成本短板
    CASE
        WHEN (SELECT cost_profit_ratio FROM v_resource_utilization WHERE region = spi.province) < 20 THEN '成本利润率低'
        WHEN (SELECT labor_cost_ratio FROM v_resource_utilization WHERE region = spi.province) > 70 THEN '人力成本占比过高'
        ELSE '成本正常'
    END AS cost_weakness,
    -- 综合短板评分
    CASE
        WHEN COUNT(CASE WHEN spi.bid_amount = 0 THEN 1 END) > COUNT(*) * 0.3 THEN '严重短板'
        WHEN COUNT(CASE WHEN spi.bid_amount = 0 THEN 1 END) > COUNT(*) * 0.2 THEN '中度短板'
        ELSE '轻度短板'
    END AS weakness_level,
    -- 改进建议
    CASE
        WHEN (SELECT total_leads FROM v_regional_customer_acquisition WHERE region = spi.province) < 20 THEN
            '建议加大市场推广力度，拓展获客渠道，提升线索数量'
        WHEN (SELECT overall_conversion_rate FROM v_regional_conversion_ability WHERE region = spi.province) < 20 THEN
            '建议加强销售培训，优化跟进流程，提升转化技能'
        WHEN (SELECT avg_payment_cycle FROM v_payment_efficiency WHERE region = spi.province) > 120 THEN
            '建议优化回款流程，加强客户沟通，缩短回款周期'
        ELSE '建议继续保持现有优势'
    END AS improvement_suggestion
FROM sales_project_info spi
WHERE is_valid = 1
GROUP BY province;

COMMENT ON VIEW v_regional_weakness_diagnosis IS '区域短板诊断报告视图';

-- 4.2 TOP改进优先级排序
-- =============================================
CREATE OR REPLACE VIEW v_improvement_priority AS
SELECT
    region,
    acquisition_weakness,
    conversion_weakness,
    payment_weakness,
    cost_weakness,
    -- 计算改进紧迫度评分（满分100）
    CASE
        WHEN acquisition_weakness != '获客正常' THEN 25
        ELSE 0
    END +
    CASE
        WHEN conversion_weakness != '转化正常' THEN 30
        ELSE 0
    END +
    CASE
        WHEN payment_weakness != '回款正常' THEN 20
        ELSE 0
    END +
    CASE
        WHEN cost_weakness != '成本正常' THEN 15
        ELSE 0
    END AS urgency_score,
    improvement_suggestion,
    CASE
        WHEN CASE
            WHEN acquisition_weakness != '获客正常' THEN 25
            ELSE 0
        END +
        CASE
            WHEN conversion_weakness != '转化正常' THEN 30
            ELSE 0
        END +
        CASE
            WHEN payment_weakness != '回款正常' THEN 20
            ELSE 0
        END +
        CASE
            WHEN cost_weakness != '成本正常' THEN 15
            ELSE 0
        END >= 60 THEN '高优先级'
        WHEN CASE
            WHEN acquisition_weakness != '获客正常' THEN 25
            ELSE 0
        END +
        CASE
            WHEN conversion_weakness != '转化正常' THEN 30
            ELSE 0
        END +
        CASE
            WHEN payment_weakness != '回款正常' THEN 20
            ELSE 0
        END +
        CASE
            WHEN cost_weakness != '成本正常' THEN 15
            ELSE 0
        END >= 30 THEN '中优先级'
        ELSE '低优先级'
    END AS priority_level
FROM v_regional_weakness_diagnosis
ORDER BY urgency_score DESC;

COMMENT ON VIEW v_improvement_priority IS 'TOP改进优先级排序视图';

-- =============================================
-- 第五部分：可视化数据支撑视图
-- =============================================

-- 5.1 区域销售漏斗可视化
-- =============================================
CREATE OR REPLACE VIEW v_sales_funnel_visualization AS
SELECT
    province AS region,
    '线索' AS stage,
    COUNT(CASE WHEN spt.conversion_status = '线索' THEN 1 END) AS count
FROM sales_project_info spi
INNER JOIN sales_process_tracking spt ON spi.contract_no = spt.contract_no
WHERE spi.is_valid = 1
GROUP BY province
UNION ALL
SELECT
    province AS region,
    '商机' AS stage,
    COUNT(CASE WHEN spt.conversion_status = '商机' THEN 1 END) AS count
FROM sales_project_info spi
INNER JOIN sales_process_tracking spt ON spi.contract_no = spt.contract_no
WHERE spi.is_valid = 1
GROUP BY province
UNION ALL
SELECT
    province AS region,
    '中标' AS stage,
    COUNT(CASE WHEN spt.conversion_status = '中标' THEN 1 END) AS count
FROM sales_project_info spi
INNER JOIN sales_process_tracking spt ON spi.contract_no = spt.contract_no
WHERE spi.is_valid = 1
GROUP BY province
UNION ALL
SELECT
    province AS region,
    '签约' AS stage,
    COUNT(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 END) AS count
FROM sales_project_info spi
INNER JOIN sales_process_tracking spt ON spi.contract_no = spt.contract_no
WHERE spi.is_valid = 1
GROUP BY province
ORDER BY region, stage;

COMMENT ON VIEW v_sales_funnel_visualization IS '区域销售漏斗可视化视图';

-- 5.2 月度趋势分析可视化
-- =============================================
CREATE OR REPLACE VIEW v_monthly_trend_visualization AS
SELECT
    DATE_FORMAT(bid_date, '%Y-%m') AS month,
    province AS region,
    COUNT(*) AS project_count,
    SUM(bid_amount) AS total_amount,
    SUM(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 ELSE 0 END) AS signed_count,
    AVG(bid_amount) AS avg_amount,
    -- 计算环比增长率
    LAG(SUM(bid_amount)) OVER (PARTITION BY province ORDER BY DATE_FORMAT(bid_date, '%Y-%m')) AS last_month_amount,
    CASE
        WHEN LAG(SUM(bid_amount)) OVER (PARTITION BY province ORDER BY DATE_FORMAT(bid_date, '%Y-%m')) > 0 THEN
            ROUND((SUM(bid_amount) - LAG(SUM(bid_amount)) OVER (PARTITION BY province ORDER BY DATE_FORMAT(bid_date, '%Y-%m'))) /
                  LAG(SUM(bid_amount)) OVER (PARTITION BY province ORDER BY DATE_FORMAT(bid_date, '%Y-%m')) * 100, 2)
        ELSE NULL
    END AS growth_rate
FROM sales_project_info spi
LEFT JOIN sales_process_tracking spt ON spi.contract_no = spt.contract_no
WHERE spi.is_valid = 1
GROUP BY DATE_FORMAT(bid_date, '%Y-%m'), province
ORDER BY month DESC, region;

COMMENT ON VIEW v_monthly_trend_visualization IS '月度趋势分析可视化视图';

-- 5.3 行业分布可视化
-- =============================================
CREATE OR REPLACE VIEW v_industry_distribution_visualization AS
SELECT
    project_category AS industry,
    secondary_category AS sub_industry,
    COUNT(*) AS project_count,
    SUM(bid_amount) AS total_amount,
    ROUND(SUM(bid_amount) * 100.0 / (SELECT SUM(bid_amount) FROM sales_project_info WHERE is_valid = 1), 2) AS amount_percentage,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM sales_project_info WHERE is_valid = 1), 2) AS count_percentage
FROM sales_project_info
WHERE is_valid = 1
GROUP BY project_category, secondary_category
ORDER BY total_amount DESC;

COMMENT ON VIEW v_industry_distribution_visualization IS '行业分布可视化视图';

-- =============================================
-- 测试查询
-- =============================================

-- 测试区域获客能力
SELECT * FROM v_regional_customer_acquisition;

-- 测试区域转化能力
SELECT * FROM v_regional_conversion_ability;

-- 测试区域短板诊断
SELECT * FROM v_regional_weakness_diagnosis;

-- 测试改进优先级
SELECT * FROM v_improvement_priority;