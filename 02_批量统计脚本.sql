-- =============================================
-- 达梦数据库 - 批量SQL统计脚本
-- 功能：自动化完成销售全流程成本、回款周期、签单转化数据计算
-- 作者：数据运营团队
-- 创建时间：2026-06-26
-- =============================================

-- =============================================
-- 第一部分：成本统计相关
-- =============================================

-- 1.1 按项目统计总成本
-- =============================================
CREATE OR REPLACE VIEW v_project_cost_summary AS
SELECT
    spi.contract_no,
    spi.project_name,
    spi.customer_name,
    spi.province,
    spi.project_category,
    spi.business_segment,
    spi.bid_amount,
    COALESCE(SUM(sci.cost_amount), 0) AS total_cost,
    spi.bid_amount - COALESCE(SUM(sci.cost_amount), 0) AS gross_profit,
    CASE
        WHEN spi.bid_amount > 0 THEN
            ROUND((spi.bid_amount - COALESCE(SUM(sci.cost_amount), 0)) / spi.bid_amount * 100, 2)
        ELSE 0
    END AS gross_profit_margin
FROM sales_project_info spi
LEFT JOIN sales_cost_info sci ON spi.contract_no = sci.contract_no
WHERE spi.is_valid = 1
GROUP BY spi.contract_no, spi.project_name, spi.customer_name, spi.province,
         spi.project_category, spi.business_segment, spi.bid_amount;

COMMENT ON VIEW v_project_cost_summary IS '项目成本汇总视图';

-- 1.2 按成本类型统计成本分布
-- =============================================
CREATE OR REPLACE VIEW v_cost_type_distribution AS
SELECT
    spi.project_category,
    spi.business_segment,
    sci.cost_type,
    COUNT(DISTINCT spi.contract_no) AS project_count,
    SUM(sci.cost_amount) AS total_cost,
    AVG(sci.cost_amount) AS avg_cost,
    MAX(sci.cost_amount) AS max_cost,
    MIN(sci.cost_amount) AS min_cost
FROM sales_project_info spi
INNER JOIN sales_cost_info sci ON spi.contract_no = sci.contract_no
WHERE spi.is_valid = 1
GROUP BY spi.project_category, spi.business_segment, sci.cost_type;

COMMENT ON VIEW v_cost_type_distribution IS '成本类型分布视图';

-- 1.3 按区域统计成本
-- =============================================
CREATE OR REPLACE VIEW v_regional_cost_statistics AS
SELECT
    spi.province AS region,
    COUNT(DISTINCT spi.contract_no) AS project_count,
    SUM(spi.bid_amount) AS total_bid_amount,
    COALESCE(SUM(sci.cost_amount), 0) AS total_cost,
    SUM(spi.bid_amount) - COALESCE(SUM(sci.cost_amount), 0) AS total_profit,
    CASE
        WHEN SUM(spi.bid_amount) > 0 THEN
            ROUND((SUM(spi.bid_amount) - COALESCE(SUM(sci.cost_amount), 0)) / SUM(spi.bid_amount) * 100, 2)
        ELSE 0
    END AS profit_margin
FROM sales_project_info spi
LEFT JOIN sales_cost_info sci ON spi.contract_no = sci.contract_no
WHERE spi.is_valid = 1
GROUP BY spi.province
ORDER BY total_bid_amount DESC;

COMMENT ON VIEW v_regional_cost_statistics IS '区域成本统计视图';

-- =============================================
-- 第二部分：回款周期统计相关
-- =============================================

-- 2.1 项目回款周期分析
-- =============================================
CREATE OR REPLACE VIEW v_payment_cycle_analysis AS
SELECT
    spi.contract_no,
    spi.project_name,
    spi.customer_name,
    spi.bid_date,
    spi.bid_amount,
    SUM(spi.planned_amount) AS total_planned_payment,
    SUM(spi.actual_amount) AS total_actual_payment,
    CASE
        WHEN SUM(spi.actual_amount) > 0 THEN
            ROUND(SUM(spi.actual_amount) / spi.bid_amount * 100, 2)
        ELSE 0
    END AS payment_rate,
    -- 计算回款周期（从中标到实际回款的平均天数）
    AVG(DATEDIFF(DAY, spi.bid_date, spi.actual_date)) AS avg_payment_cycle_days,
    -- 最短回款周期
    MIN(DATEDIFF(DAY, spi.bid_date, spi.actual_date)) AS min_payment_cycle_days,
    -- 最长回款周期
    MAX(DATEDIFF(DAY, spi.bid_date, spi.actual_date)) AS max_payment_cycle_days
FROM sales_project_info spi
INNER JOIN sales_payment_info spi ON spi.contract_no = spi.contract_no
WHERE spi.is_valid = 1
GROUP BY spi.contract_no, spi.project_name, spi.customer_name, spi.bid_date, spi.bid_amount;

COMMENT ON VIEW v_payment_cycle_analysis IS '项目回款周期分析视图';

-- 2.2 按区域统计平均回款周期
-- =============================================
CREATE OR REPLACE VIEW v_regional_payment_cycle AS
SELECT
    spi.province AS region,
    COUNT(DISTINCT spi.contract_no) AS project_count,
    AVG(pc.avg_payment_cycle_days) AS avg_payment_cycle,
    AVG(pc.payment_rate) AS avg_payment_rate,
    SUM(pc.total_actual_payment) AS total_payment
FROM sales_project_info spi
INNER JOIN sales_payment_info spi ON spi.contract_no = spi.contract_no
LEFT JOIN (
    SELECT
        contract_no,
        AVG(DATEDIFF(DAY, (SELECT bid_date FROM sales_project_info WHERE contract_no = sales_payment_info.contract_no), actual_date)) AS avg_payment_cycle_days,
        SUM(actual_amount) / NULLIF((SELECT bid_amount FROM sales_project_info WHERE contract_no = sales_payment_info.contract_no), 0) * 100 AS payment_rate,
        SUM(actual_amount) AS total_actual_payment
    FROM sales_payment_info
    WHERE actual_date IS NOT NULL
    GROUP BY contract_no
) pc ON spi.contract_no = pc.contract_no
WHERE spi.is_valid = 1
GROUP BY spi.province
ORDER BY avg_payment_cycle DESC;

COMMENT ON VIEW v_regional_payment_cycle IS '区域回款周期统计视图';

-- 2.3 回款阶段统计
-- =============================================
CREATE OR REPLACE VIEW v_payment_stage_statistics AS
SELECT
    payment_stage,
    COUNT(DISTINCT contract_no) AS project_count,
    SUM(planned_amount) AS total_planned,
    SUM(actual_amount) AS total_actual,
    CASE
        WHEN SUM(planned_amount) > 0 THEN
            ROUND(SUM(actual_amount) / SUM(planned_amount) * 100, 2)
        ELSE 0
    END AS completion_rate,
    -- 计算平均延迟天数
    AVG(DATEDIFF(DAY, planned_date, actual_date)) AS avg_delay_days
FROM sales_payment_info
WHERE actual_date IS NOT NULL
GROUP BY payment_stage;

COMMENT ON VIEW v_payment_stage_statistics IS '回款阶段统计视图';

-- =============================================
-- 第三部分：签单转化统计相关
-- =============================================

-- 3.1 销售漏斗转化分析
-- =============================================
CREATE OR REPLACE VIEW v_sales_funnel_conversion AS
SELECT
    DATE_FORMAT(lead_date, '%Y-%m') AS month,
    COUNT(CASE WHEN conversion_status = '线索' THEN 1 END) AS lead_count,
    COUNT(CASE WHEN conversion_status = '商机' THEN 1 END) AS opportunity_count,
    COUNT(CASE WHEN conversion_status = '中标' THEN 1 END) AS bid_won_count,
    COUNT(CASE WHEN conversion_status = '签约' THEN 1 END) AS contract_signed_count,
    COUNT(CASE WHEN conversion_status = '完成' THEN 1 END) AS completed_count,
    -- 线索到商机转化率
    CASE
        WHEN COUNT(CASE WHEN conversion_status = '线索' THEN 1 END) > 0 THEN
            ROUND(COUNT(CASE WHEN conversion_status = '商机' THEN 1 END) * 100.0 / COUNT(CASE WHEN conversion_status = '线索' THEN 1 END), 2)
        ELSE 0
    END AS lead_to_opportunity_rate,
    -- 商机到中标转化率
    CASE
        WHEN COUNT(CASE WHEN conversion_status = '商机' THEN 1 END) > 0 THEN
            ROUND(COUNT(CASE WHEN conversion_status = '中标' THEN 1 END) * 100.0 / COUNT(CASE WHEN conversion_status = '商机' THEN 1 END), 2)
        ELSE 0
    END AS opportunity_to_bid_rate,
    -- 中标到签约转化率
    CASE
        WHEN COUNT(CASE WHEN conversion_status = '中标' THEN 1 END) > 0 THEN
            ROUND(COUNT(CASE WHEN conversion_status = '签约' THEN 1 END) * 100.0 / COUNT(CASE WHEN conversion_status = '中标' THEN 1 END), 2)
        ELSE 0
    END AS bid_to_contract_rate,
    -- 整体转化率
    CASE
        WHEN COUNT(CASE WHEN conversion_status = '线索' THEN 1 END) > 0 THEN
            ROUND(COUNT(CASE WHEN conversion_status = '签约' THEN 1 END) * 100.0 / COUNT(CASE WHEN conversion_status = '线索' THEN 1 END), 2)
        ELSE 0
    END AS overall_conversion_rate
FROM sales_process_tracking
WHERE lead_date IS NOT NULL
GROUP BY DATE_FORMAT(lead_date, '%Y-%m')
ORDER BY month DESC;

COMMENT ON VIEW v_sales_funnel_conversion IS '销售漏斗转化分析视图';

-- 3.2 各阶段平均停留时长
-- =============================================
CREATE OR REPLACE VIEW v_stage_duration_analysis AS
SELECT
    contract_no,
    project_name,
    -- 线索到接触的时长
    DATEDIFF(DAY, lead_date, contact_date) AS lead_to_contact_days,
    -- 接触到方案的时长
    DATEDIFF(DAY, contact_date, proposal_date) AS contact_to_proposal_days,
    -- 方案到谈判的时长
    DATEDIFF(DAY, proposal_date, negotiation_date) AS proposal_to_negotiation_days,
    -- 谈判到中标的时长
    DATEDIFF(DAY, negotiation_date, bid_date) AS negotiation_to_bid_days,
    -- 中标到签约的时长
    DATEDIFF(DAY, bid_date, contract_sign_date) AS bid_to_contract_days,
    -- 签约到项目启动的时长
    DATEDIFF(DAY, contract_sign_date, project_start_date) AS contract_to_start_days,
    -- 整体周期
    DATEDIFF(DAY, lead_date, contract_sign_date) AS total_cycle_days
FROM sales_process_tracking
WHERE lead_date IS NOT NULL AND contract_sign_date IS NOT NULL;

COMMENT ON VIEW v_stage_duration_analysis IS '各阶段停留时长分析视图';

-- 3.3 按区域/行业统计转化率
-- =============================================
CREATE OR REPLACE VIEW v_conversion_by_region AS
SELECT
    spi.province AS region,
    spi.project_category,
    COUNT(DISTINCT spt.contract_no) AS total_leads,
    COUNT(CASE WHEN spt.conversion_status IN ('中标', '签约', '完成') THEN 1 END) AS won_count,
    COUNT(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 END) AS signed_count,
    CASE
        WHEN COUNT(DISTINCT spt.contract_no) > 0 THEN
            ROUND(COUNT(CASE WHEN spt.conversion_status IN ('中标', '签约', '完成') THEN 1 END) * 100.0 / COUNT(DISTINCT spt.contract_no), 2)
        ELSE 0
    END AS win_rate,
    CASE
        WHEN COUNT(DISTINCT spt.contract_no) > 0 THEN
            ROUND(COUNT(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 END) * 100.0 / COUNT(DISTINCT spt.contract_no), 2)
        ELSE 0
    END AS sign_rate,
    SUM(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN spi.bid_amount ELSE 0 END) AS total_signed_amount
FROM sales_project_info spi
INNER JOIN sales_process_tracking spt ON spi.contract_no = spt.contract_no
WHERE spi.is_valid = 1
GROUP BY spi.province, spi.project_category
ORDER BY sign_rate DESC;

COMMENT ON VIEW v_conversion_by_region IS '区域/行业转化率统计视图';

-- =============================================
-- 第四部分：综合分析统计
-- =============================================

-- 4.1 项目综合运营指标
-- =============================================
CREATE OR REPLACE VIEW v_project_comprehensive_metrics AS
SELECT
    spi.contract_no,
    spi.project_name,
    spi.customer_name,
    spi.province,
    spi.project_category,
    spi.bid_amount,
    -- 成本指标
    pcs.total_cost,
    pcs.gross_profit,
    pcs.gross_profit_margin,
    -- 回款指标
    pca.total_actual_payment,
    pca.payment_rate,
    pca.avg_payment_cycle_days,
    -- 转化指标
    sda.total_cycle_days,
    spt.conversion_status,
    -- 综合评分（基于成本利润率、回款率、周期）
    CASE
        WHEN pcs.gross_profit_margin >= 30 AND pca.payment_rate >= 80 THEN '优秀'
        WHEN pcs.gross_profit_margin >= 20 AND pca.payment_rate >= 60 THEN '良好'
        WHEN pcs.gross_profit_margin >= 10 AND pca.payment_rate >= 40 THEN '一般'
        ELSE '待改进'
    END AS project_grade
FROM sales_project_info spi
LEFT JOIN v_project_cost_summary pcs ON spi.contract_no = pcs.contract_no
LEFT JOIN v_payment_cycle_analysis pca ON spi.contract_no = pca.contract_no
LEFT JOIN v_stage_duration_analysis sda ON spi.contract_no = sda.contract_no
LEFT JOIN sales_process_tracking spt ON spi.contract_no = spt.contract_no
WHERE spi.is_valid = 1;

COMMENT ON VIEW v_project_comprehensive_metrics IS '项目综合运营指标视图';

-- 4.2 重点项目识别（高价值项目）
-- =============================================
CREATE OR REPLACE VIEW v_key_projects AS
SELECT
    contract_no,
    project_name,
    customer_name,
    province,
    bid_amount,
    gross_profit,
    gross_profit_margin,
    total_actual_payment,
    payment_rate,
    project_grade,
    CASE
        WHEN bid_amount >= 100 AND gross_profit_margin >= 25 AND payment_rate >= 70 THEN '战略项目'
        WHEN bid_amount >= 50 AND gross_profit_margin >= 20 AND payment_rate >= 60 THEN '重点跟进'
        WHEN bid_amount >= 20 THEN '常规项目'
        ELSE '小型项目'
    END AS project_level
FROM v_project_comprehensive_metrics
WHERE is_valid = 1
ORDER BY bid_amount DESC, gross_profit_margin DESC;

COMMENT ON VIEW v_key_projects IS '重点项目识别视图';

-- =============================================
-- 第五部分：存储过程 - 批量统计计算
-- =============================================

-- 5.1 存储过程：计算月度综合统计
-- =============================================
CREATE OR REPLACE PROCEDURE sp_calculate_monthly_statistics(
    IN p_year INT,
    IN p_month INT
)
AS
    v_start_date DATE;
    v_end_date DATE;
    v_report_month VARCHAR(7);
BEGIN
    -- 构建日期范围
    v_start_date := TO_DATE(p_year || '-' || LPAD(p_month, 2, '0') || '-01', 'YYYY-MM-DD');
    v_end_date := LAST_DAY(v_start_date);
    v_report_month := p_year || '-' || LPAD(p_month, 2, '0');

    -- 删除已存在的当月数据
    DELETE FROM monthly_analysis_report WHERE report_month = v_report_month;

    -- 插入新的月度统计数据
    INSERT INTO monthly_analysis_report (
        report_month, region, business_segment, total_projects, total_bid_amount,
        total_cost, total_payment, avg_payment_cycle, conversion_rate, cost_profit_margin
    )
    SELECT
        v_report_month,
        spi.province AS region,
        spi.business_segment,
        COUNT(DISTINCT spi.contract_no) AS total_projects,
        SUM(spi.bid_amount) AS total_bid_amount,
        COALESCE(SUM(sci.cost_amount), 0) AS total_cost,
        COALESCE(SUM(spi2.actual_amount), 0) AS total_payment,
        -- 计算平均回款周期
        AVG(DATEDIFF(DAY, spi.bid_date, spi2.actual_date)) AS avg_payment_cycle,
        -- 计算转化率
        CASE
            WHEN COUNT(DISTINCT spt.contract_no) > 0 THEN
                ROUND(COUNT(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 END) * 100.0 /
                      COUNT(DISTINCT spt.contract_no), 2)
            ELSE 0
        END AS conversion_rate,
        -- 计算成本利润率
        CASE
            WHEN SUM(spi.bid_amount) > 0 THEN
                ROUND((SUM(spi.bid_amount) - COALESCE(SUM(sci.cost_amount), 0)) / SUM(spi.bid_amount) * 100, 2)
            ELSE 0
        END AS cost_profit_margin
    FROM sales_project_info spi
    LEFT JOIN sales_cost_info sci ON spi.contract_no = sci.contract_no AND sci.cost_date BETWEEN v_start_date AND v_end_date
    LEFT JOIN sales_payment_info spi2 ON spi.contract_no = spi2.contract_no AND spi2.actual_date BETWEEN v_start_date AND v_end_date
    LEFT JOIN sales_process_tracking spt ON spi.contract_no = spt.contract_no
    WHERE spi.bid_date BETWEEN v_start_date AND v_end_date
      AND spi.is_valid = 1
    GROUP BY spi.province, spi.business_segment;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('月度统计数据计算完成：' || v_report_month);
END;
/

-- 5.2 存储过程：自动计算所有未计算月份
-- =============================================
CREATE OR REPLACE PROCEDURE sp_auto_calculate_statistics()
AS
BEGIN
    -- 自动计算过去12个月的统计数据
    FOR i IN 0..11 LOOP
        DECLARE
            v_calc_date DATE;
            v_year INT;
            v_month INT;
        BEGIN
            v_calc_date := ADD_MONTHS(CURRENT_DATE, -i);
            v_year := YEAR(v_calc_date);
            v_month := MONTH(v_calc_date);

            -- 调用月度统计存储过程
            sp_calculate_monthly_statistics(v_year, v_month);
        END;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('所有月份统计数据计算完成');
END;
/

-- =============================================
-- 第六部分：定时任务配置
-- =============================================

-- 创建定时任务：每月1号自动计算上月统计
-- 注意：达梦数据库的定时任务语法可能有所不同，以下为示例
/*
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name => 'JOB_MONTHLY_STATISTICS',
        job_type => 'STORED_PROCEDURE',
        job_action => 'sp_auto_calculate_statistics',
        start_date => SYSTIMESTAMP,
        repeat_interval => 'FREQ=MONTHLY; BYMONTHDAY=1; BYHOUR=2; BYMINUTE=0; BYSECOND=0',
        enabled => TRUE,
        comments => '每月1号凌晨2点自动计算月度统计数据'
    );
END;
/
*/

-- =============================================
-- 测试查询
-- =============================================

-- 测试项目成本汇总
SELECT * FROM v_project_cost_summary LIMIT 5;

-- 测试回款周期分析
SELECT * FROM v_payment_cycle_analysis LIMIT 5;

-- 测试销售漏斗转化
SELECT * FROM v_sales_funnel_conversion LIMIT 5;

-- 测试项目综合指标
SELECT * FROM v_project_comprehensive_metrics LIMIT 5;