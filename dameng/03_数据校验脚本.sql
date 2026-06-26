-- =============================================
-- 达梦数据库 - 自动化数据校验脚本
-- 功能：识别重复数据、缺失字段、跨区域数据同步延迟、指标计算偏差等异常问题
-- 作者：数据运营团队
-- 创建时间：2026-06-26
-- =============================================

-- =============================================
-- 第一部分：重复数据检测
-- =============================================

-- 1.1 检测完全重复的记录
-- =============================================
CREATE OR REPLACE VIEW v_duplicate_records AS
SELECT
    customer_name,
    project_name,
    contract_party,
    bid_date,
    bid_amount,
    COUNT(*) AS duplicate_count,
    MIN(id) AS first_record_id,
    MAX(id) AS last_record_id
FROM sales_project_info
WHERE is_valid = 1
GROUP BY customer_name, project_name, contract_party, bid_date, bid_amount
HAVING COUNT(*) > 1;

COMMENT ON VIEW v_duplicate_records IS '完全重复记录检测视图';

-- 1.2 检测合同编号重复
-- =============================================
CREATE OR REPLACE VIEW v_duplicate_contract_no AS
SELECT
    contract_no,
    COUNT(*) AS duplicate_count,
    LISTAGG(id, ',') AS record_ids,
    LISTAGG(project_name, ';') AS project_names
FROM sales_project_info
WHERE contract_no IS NOT NULL AND contract_no != ''
GROUP BY contract_no
HAVING COUNT(*) > 1;

COMMENT ON VIEW v_duplicate_contract_no IS '合同编号重复检测视图';

-- 1.3 检测同一客户同一时间段内的重复项目
-- =============================================
CREATE OR REPLACE VIEW v_customer_duplicate_projects AS
SELECT
    customer_name,
    COUNT(*) AS project_count,
    MIN(bid_date) AS earliest_date,
    MAX(bid_date) AS latest_date,
    LISTAGG(project_name, ';') AS project_names
FROM sales_project_info
WHERE is_valid = 1
  AND bid_date BETWEEN ADD_MONTHS(CURRENT_DATE, -6) AND CURRENT_DATE
GROUP BY customer_name
HAVING COUNT(*) > 3;  -- 同一客户半年内超过3个项目视为异常

COMMENT ON VIEW v_customer_duplicate_projects IS '客户项目重复检测视图';

-- =============================================
-- 第二部分：缺失字段检测
-- =============================================

-- 2.1 检测必填字段缺失情况
-- =============================================
CREATE OR REPLACE VIEW v_missing_required_fields AS
SELECT
    id,
    contract_no,
    project_name,
    CASE WHEN customer_name IS NULL OR customer_name = '' THEN '客户名称缺失' ELSE NULL END AS missing_customer,
    CASE WHEN project_name IS NULL OR project_name = '' THEN '项目名称缺失' ELSE NULL END AS missing_project,
    CASE WHEN contract_party IS NULL OR contract_party = '' THEN '合同甲方缺失' ELSE NULL END AS missing_contract_party,
    CASE WHEN bid_date IS NULL THEN '中标日期缺失' ELSE NULL END AS missing_bid_date,
    CASE WHEN bid_amount IS NULL OR bid_amount = 0 THEN '中标金额缺失' ELSE NULL END AS missing_bid_amount,
    CASE WHEN province IS NULL OR province = '' THEN '省份缺失' ELSE NULL END AS missing_province,
    CASE WHEN project_category IS NULL OR project_category = '' THEN '项目分类缺失' ELSE NULL END AS missing_category
FROM sales_project_info
WHERE is_valid = 1
  AND (
      customer_name IS NULL OR customer_name = ''
      OR project_name IS NULL OR project_name = ''
      OR contract_party IS NULL OR contract_party = ''
      OR bid_date IS NULL
      OR bid_amount IS NULL OR bid_amount = 0
      OR province IS NULL OR province = ''
      OR project_category IS NULL OR project_category = ''
  );

COMMENT ON VIEW v_missing_required_fields IS '必填字段缺失检测视图';

-- 2.2 按字段统计缺失率
-- =============================================
CREATE OR REPLACE VIEW v_field_missing_rate AS
SELECT
    COUNT(*) AS total_records,
    SUM(CASE WHEN customer_name IS NULL OR customer_name = '' THEN 1 ELSE 0 END) AS customer_missing_count,
    ROUND(SUM(CASE WHEN customer_name IS NULL OR customer_name = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS customer_missing_rate,
    SUM(CASE WHEN project_name IS NULL OR project_name = '' THEN 1 ELSE 0 END) AS project_missing_count,
    ROUND(SUM(CASE WHEN project_name IS NULL OR project_name = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS project_missing_rate,
    SUM(CASE WHEN contract_party IS NULL OR contract_party = '' THEN 1 ELSE 0 END) AS party_missing_count,
    ROUND(SUM(CASE WHEN contract_party IS NULL OR contract_party = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS party_missing_rate,
    SUM(CASE WHEN bid_date IS NULL THEN 1 ELSE 0 END) AS date_missing_count,
    ROUND(SUM(CASE WHEN bid_date IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS date_missing_rate,
    SUM(CASE WHEN bid_amount IS NULL OR bid_amount = 0 THEN 1 ELSE 0 END) AS amount_missing_count,
    ROUND(SUM(CASE WHEN bid_amount IS NULL OR bid_amount = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS amount_missing_rate,
    SUM(CASE WHEN province IS NULL OR province = '' THEN 1 ELSE 0 END) AS province_missing_count,
    ROUND(SUM(CASE WHEN province IS NULL OR province = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS province_missing_rate
FROM sales_project_info
WHERE is_valid = 1;

COMMENT ON VIEW v_field_missing_rate IS '字段缺失率统计视图';

-- =============================================
-- 第三部分：数据异常检测
-- =============================================

-- 3.1 金额异常检测（超出合理范围）
-- =============================================
CREATE OR REPLACE VIEW v_amount_anomaly AS
SELECT
    id,
    contract_no,
    project_name,
    bid_amount,
    CASE
        WHEN bid_amount < 1 THEN '金额过小异常'
        WHEN bid_amount > 1000 THEN '金额过大异常'
        WHEN bid_amount % 100 = 0 THEN '金额可能为估算值'
        ELSE '正常'
    END AS amount_status,
    '中标金额异常' AS anomaly_type
FROM sales_project_info
WHERE is_valid = 1
  AND (bid_amount < 1 OR bid_amount > 1000 OR bid_amount % 100 = 0);

COMMENT ON VIEW v_amount_anomaly IS '金额异常检测视图';

-- 3.2 时间异常检测
-- =============================================
CREATE OR REPLACE VIEW v_date_anomaly AS
SELECT
    id,
    contract_no,
    project_name,
    bid_date,
    CASE
        WHEN bid_date > CURRENT_DATE THEN '未来日期异常'
        WHEN bid_date < DATE '2020-01-01' THEN '历史日期异常'
        WHEN DATEDIFF(DAY, bid_date, CURRENT_DATE) > 365 THEN '超过一年未更新'
        ELSE '正常'
    END AS date_status,
    '时间异常' AS anomaly_type
FROM sales_project_info
WHERE is_valid = 1
  AND (bid_date > CURRENT_DATE OR bid_date < DATE '2020-01-01' OR DATEDIFF(DAY, bid_date, CURRENT_DATE) > 365);

COMMENT ON VIEW v_date_anomaly IS '时间异常检测视图';

-- 3.3 成本异常检测（成本超过中标金额）
-- =============================================
CREATE OR REPLACE VIEW v_cost_anomaly AS
SELECT
    spi.id,
    spi.contract_no,
    spi.project_name,
    spi.bid_amount,
    SUM(sci.cost_amount) AS total_cost,
    spi.bid_amount - SUM(sci.cost_amount) AS profit,
    CASE
        WHEN SUM(sci.cost_amount) > spi.bid_amount THEN '成本超支异常'
        WHEN SUM(sci.cost_amount) > spi.bid_amount * 0.9 THEN '成本占比过高'
        ELSE '正常'
    END AS cost_status,
    '成本异常' AS anomaly_type
FROM sales_project_info spi
INNER JOIN sales_cost_info sci ON spi.contract_no = sci.contract_no
WHERE spi.is_valid = 1
  AND SUM(sci.cost_amount) > spi.bid_amount * 0.8
GROUP BY spi.id, spi.contract_no, spi.project_name, spi.bid_amount;

COMMENT ON VIEW v_cost_anomaly IS '成本异常检测视图';

-- 3.4 回款异常检测
-- =============================================
CREATE OR REPLACE VIEW v_payment_anomaly AS
SELECT
    spi.contract_no,
    spi.project_name,
    spi.bid_amount,
    SUM(spi2.planned_amount) AS total_planned,
    SUM(spi2.actual_amount) AS total_actual,
    CASE
        WHEN SUM(spi2.planned_amount) > spi.bid_amount * 1.5 THEN '计划回款超标'
        WHEN SUM(spi2.actual_amount) > spi.bid_amount THEN '实际回款超标'
        WHEN DATEDIFF(DAY, spi2.planned_date, CURRENT_DATE) > 90 AND spi2.actual_amount = 0 THEN '回款延迟超90天'
        WHEN spi2.actual_date > spi2.planned_date + 30 THEN '回款延迟超30天'
        ELSE '正常'
    END AS payment_status,
    '回款异常' AS anomaly_type
FROM sales_project_info spi
INNER JOIN sales_payment_info spi2 ON spi.contract_no = spi2.contract_no
WHERE spi.is_valid = 1
GROUP BY spi.contract_no, spi.project_name, spi.bid_amount;

COMMENT ON VIEW v_payment_anomaly IS '回款异常检测视图';

-- =============================================
-- 第四部分：跨区域数据同步延迟检测
-- =============================================

-- 4.1 检测数据更新延迟（超过7天未更新的区域）
-- =============================================
CREATE OR REPLACE VIEW v_data_sync_delay AS
SELECT
    province AS region,
    MAX(updated_time) AS last_update_time,
    DATEDIFF(DAY, MAX(updated_time), CURRENT_TIMESTAMP) AS delay_days,
    COUNT(*) AS record_count,
    CASE
        WHEN DATEDIFF(DAY, MAX(updated_time), CURRENT_TIMESTAMP) > 30 THEN '严重延迟'
        WHEN DATEDIFF(DAY, MAX(updated_time), CURRENT_TIMESTAMP) > 14 THEN '中度延迟'
        WHEN DATEDIFF(DAY, MAX(updated_time), CURRENT_TIMESTAMP) > 7 THEN '轻度延迟'
        ELSE '正常'
    END AS delay_status
FROM sales_project_info
WHERE is_valid = 1
GROUP BY province
HAVING DATEDIFF(DAY, MAX(updated_time), CURRENT_TIMESTAMP) > 7;

COMMENT ON VIEW v_data_sync_delay IS '数据同步延迟检测视图';

-- 4.2 检测填报单位数据更新频率异常
-- =============================================
CREATE OR REPLACE VIEW v_fill_unit_frequency AS
SELECT
    fill_unit,
    COUNT(*) AS total_records,
    MAX(updated_time) AS last_update,
    MIN(updated_time) AS first_update,
    COUNT(DISTINCT DATE(updated_time)) AS update_days,
    CASE
        WHEN COUNT(*) > 10 AND COUNT(DISTINCT DATE(updated_time)) < 2 THEN '集中填报异常'
        WHEN DATEDIFF(DAY, MAX(updated_time), CURRENT_TIMESTAMP) > 30 THEN '长期未更新'
        ELSE '正常'
    END AS frequency_status
FROM sales_project_info
WHERE is_valid = 1 AND fill_unit IS NOT NULL
GROUP BY fill_unit;

COMMENT ON VIEW v_fill_unit_frequency IS '填报单位频率异常检测视图';

-- =============================================
-- 第五部分：指标计算偏差检测
-- =============================================

-- 5.1 检测利润率偏差异常
-- =============================================
CREATE OR REPLACE VIEW v_profit_margin_deviation AS
SELECT
    contract_no,
    project_name,
    province,
    bid_amount,
    total_cost,
    gross_profit_margin,
    avg_margin_by_region
FROM (
    SELECT
        spi.contract_no,
        spi.project_name,
        spi.province,
        spi.bid_amount,
        SUM(sci.cost_amount) AS total_cost,
        ROUND((spi.bid_amount - SUM(sci.cost_amount)) / spi.bid_amount * 100, 2) AS gross_profit_margin,
        AVG((spi2.bid_amount - SUM(sci2.cost_amount)) / spi2.bid_amount * 100) OVER (PARTITION BY spi.province) AS avg_margin_by_region
    FROM sales_project_info spi
    LEFT JOIN sales_cost_info sci ON spi.contract_no = sci.contract_no
    WHERE spi.is_valid = 1
    GROUP BY spi.contract_no, spi.project_name, spi.province, spi.bid_amount
) t
WHERE ABS(gross_profit_margin - avg_margin_by_region) > 20;  -- 利润率偏离区域平均水平超过20%

COMMENT ON VIEW v_profit_margin_deviation IS '利润率偏差异常检测视图';

-- 5.2 检测转化率计算偏差
-- =============================================
CREATE OR REPLACE VIEW v_conversion_rate_deviation AS
SELECT
    month,
    region,
    conversion_rate,
    avg_conversion_rate,
    ABS(conversion_rate - avg_conversion_rate) AS deviation,
    CASE
        WHEN ABS(conversion_rate - avg_conversion_rate) > 30 THEN '严重偏差'
        WHEN ABS(conversion_rate - avg_conversion_rate) > 15 THEN '中度偏差'
        ELSE '轻度偏差'
    END AS deviation_level
FROM (
    SELECT
        DATE_FORMAT(lead_date, '%Y-%m') AS month,
        spi.province AS region,
        ROUND(COUNT(CASE WHEN spt.conversion_status IN ('签约', '完成') THEN 1 END) * 100.0 /
              COUNT(DISTINCT spt.contract_no), 2) AS conversion_rate,
        AVG(COUNT(CASE WHEN spt2.conversion_status IN ('签约', '完成') THEN 1 END) * 100.0 /
            COUNT(DISTINCT spt2.contract_no)) OVER (PARTITION BY DATE_FORMAT(lead_date, '%Y-%m')) AS avg_conversion_rate
    FROM sales_project_info spi
    INNER JOIN sales_process_tracking spt ON spi.contract_no = spt.contract_no
    WHERE spi.is_valid = 1
    GROUP BY DATE_FORMAT(lead_date, '%Y-%m'), spi.province
) t;

COMMENT ON VIEW v_conversion_rate_deviation IS '转化率偏差检测视图';

-- =============================================
-- 第六部分：综合数据质量检查视图
-- =============================================

-- 6.1 数据质量综合评分
-- =============================================
CREATE OR REPLACE VIEW v_data_quality_score AS
SELECT
    DATE_FORMAT(CURRENT_DATE, '%Y-%m-%d') AS check_date,
    (SELECT COUNT(*) FROM v_duplicate_records) AS duplicate_count,
    (SELECT COUNT(*) FROM v_missing_required_fields) AS missing_count,
    (SELECT COUNT(*) FROM v_amount_anomaly WHERE amount_status != '正常') AS amount_anomaly_count,
    (SELECT COUNT(*) FROM v_date_anomaly WHERE date_status != '正常') AS date_anomaly_count,
    (SELECT COUNT(*) FROM v_cost_anomaly WHERE cost_status != '正常') AS cost_anomaly_count,
    (SELECT COUNT(*) FROM v_payment_anomaly WHERE payment_status != '正常') AS payment_anomaly_count,
    (SELECT COUNT(*) FROM v_data_sync_delay) AS sync_delay_count,
    -- 计算质量评分（满分100）
    100 - (
        (SELECT COUNT(*) FROM v_duplicate_records) * 5 +
        (SELECT COUNT(*) FROM v_missing_required_fields) * 3 +
        (SELECT COUNT(*) FROM v_amount_anomaly WHERE amount_status != '正常') * 2 +
        (SELECT COUNT(*) FROM v_date_anomaly WHERE date_status != '正常') * 1 +
        (SELECT COUNT(*) FROM v_data_sync_delay) * 2
    ) AS quality_score,
    CASE
        WHEN 100 - (
            (SELECT COUNT(*) FROM v_duplicate_records) * 5 +
            (SELECT COUNT(*) FROM v_missing_required_fields) * 3 +
            (SELECT COUNT(*) FROM v_amount_anomaly WHERE amount_status != '正常') * 2 +
            (SELECT COUNT(*) FROM v_date_anomaly WHERE date_status != '正常') * 1 +
            (SELECT COUNT(*) FROM v_data_sync_delay) * 2
        ) >= 90 THEN '优秀'
        WHEN 100 - (
            (SELECT COUNT(*) FROM v_duplicate_records) * 5 +
            (SELECT COUNT(*) FROM v_missing_required_fields) * 3 +
            (SELECT COUNT(*) FROM v_amount_anomaly WHERE amount_status != '正常') * 2 +
            (SELECT COUNT(*) FROM v_date_anomaly WHERE date_status != '正常') * 1 +
            (SELECT COUNT(*) FROM v_data_sync_delay) * 2
        ) >= 80 THEN '良好'
        WHEN 100 - (
            (SELECT COUNT(*) FROM v_duplicate_records) * 5 +
            (SELECT COUNT(*) FROM v_missing_required_fields) * 3 +
            (SELECT COUNT(*) FROM v_amount_anomaly WHERE amount_status != '正常') * 2 +
            (SELECT COUNT(*) FROM v_date_anomaly WHERE date_status != '正常') * 1 +
            (SELECT COUNT(*) FROM v_data_sync_delay) * 2
        ) >= 70 THEN '一般'
        ELSE '待改进'
    END AS quality_level;

COMMENT ON VIEW v_data_quality_score IS '数据质量综合评分视图';

-- =============================================
-- 第七部分：数据质量监控存储过程
-- =============================================

-- 7.1 存储过程：自动执行数据质量检查
-- =============================================
CREATE OR REPLACE PROCEDURE sp_data_quality_check()
AS
    v_duplicate_count INTEGER;
    v_missing_count INTEGER;
    v_anomaly_count INTEGER;
    v_sync_delay_count INTEGER;
    v_quality_score INTEGER;
BEGIN
    -- 统计重复数据数量
    SELECT COUNT(*) INTO v_duplicate_count FROM v_duplicate_records;

    -- 统计缺失字段数量
    SELECT COUNT(*) INTO v_missing_count FROM v_missing_required_fields;

    -- 统计异常数据数量
    SELECT COUNT(*) INTO v_anomaly_count
    FROM (
        SELECT * FROM v_amount_anomaly WHERE amount_status != '正常'
        UNION ALL
        SELECT * FROM v_date_anomaly WHERE date_status != '正常'
        UNION ALL
        SELECT * FROM v_cost_anomaly WHERE cost_status != '正常'
    );

    -- 统计同步延迟数量
    SELECT COUNT(*) INTO v_sync_delay_count FROM v_data_sync_delay;

    -- 计算质量评分
    v_quality_score := 100 - (v_duplicate_count * 5 + v_missing_count * 3 + v_anomaly_count * 2 + v_sync_delay_count * 2);

    -- 记录到质量监控日志
    INSERT INTO data_quality_log (
        check_date, check_type, table_name, issue_count, issue_description, status
    )
    VALUES (
        CURRENT_DATE, '重复数据', 'sales_project_info', v_duplicate_count,
        '发现 ' || v_duplicate_count || ' 条重复数据记录', '待处理'
    );

    INSERT INTO data_quality_log (
        check_date, check_type, table_name, issue_count, issue_description, status
    )
    VALUES (
        CURRENT_DATE, '缺失字段', 'sales_project_info', v_missing_count,
        '发现 ' || v_missing_count || ' 条必填字段缺失记录', '待处理'
    );

    INSERT INTO data_quality_log (
        check_date, check_type, table_name, issue_count, issue_description, status
    )
    VALUES (
        CURRENT_DATE, '数据异常', 'sales_project_info', v_anomaly_count,
        '发现 ' || v_anomaly_count || ' 条数据异常记录', '待处理'
    );

    INSERT INTO data_quality_log (
        check_date, check_type, table_name, issue_count, issue_description, status
    )
    VALUES (
        CURRENT_DATE, '同步延迟', 'sales_project_info', v_sync_delay_count,
        '发现 ' || v_sync_delay_count || ' 个区域数据同步延迟', '待处理'
    );

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('数据质量检查完成，总体评分：' || v_quality_score);
END;
/

-- 7.2 存储过程：自动修复数据质量问题
-- =============================================
CREATE OR REPLACE PROCEDURE sp_fix_data_quality_issues()
AS
BEGIN
    -- 1. 修复重复数据：保留最早记录，标记其他为无效
    UPDATE sales_project_info
    SET is_valid = 0, remark = CONCAT(remark, '; 自动标记为重复数据，于', CURRENT_DATE, '处理')
    WHERE id IN (
        SELECT id FROM (
            SELECT id, ROW_NUMBER() OVER (PARTITION BY customer_name, project_name, contract_party, bid_date, bid_amount ORDER BY id DESC) AS rn
            FROM sales_project_info
            WHERE is_valid = 1
        ) t WHERE rn > 1
    );

    -- 2. 修复金额异常：将异常金额标记到备注
    UPDATE sales_project_info
    SET remark = CONCAT(remark, ';金额异常：原金额', bid_amount, '万元')
    WHERE id IN (SELECT id FROM v_amount_anomaly WHERE amount_status != '正常');

    -- 3. 修复时间异常：将未来日期调整为当前日期
    UPDATE sales_project_info
    SET bid_date = CURRENT_DATE, remark = CONCAT(remark, ';时间异常修复：原日期', bid_date)
    WHERE bid_date > CURRENT_DATE;

    -- 4. 更新质量日志状态
    UPDATE data_quality_log
    SET status = '已处理'
    WHERE check_date = CURRENT_DATE AND status = '待处理';

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('数据质量问题自动修复完成');
END;
/

-- =============================================
-- 第八部分：数据填报规范校验
-- =============================================

-- 8.1 校验客户名称规范性
-- =============================================
CREATE OR REPLACE VIEW v_customer_name_validation AS
SELECT
    id,
    customer_name,
    CASE
        WHEN LENGTH(customer_name) < 5 THEN '客户名称过短'
        WHEN customer_name LIKE '%公司%' OR customer_name LIKE '%集团%' THEN '正常'
        WHEN customer_name NOT REGEXP '^[a-zA-Z0-9\u4e00-\u9fa5]+$' THEN '包含特殊字符'
        ELSE '需要核实'
    END AS name_status
FROM sales_project_info
WHERE is_valid = 1;

COMMENT ON VIEW v_customer_name_validation IS '客户名称规范性校验视图';

-- 8.2 校验项目分类规范性
-- =============================================
CREATE OR REPLACE VIEW v_category_validation AS
SELECT
    id,
    project_category,
    secondary_category,
    CASE
        WHEN project_category IN ('政府', '行业', '企业') THEN '正常'
        ELSE '分类不规范'
    END AS category_status,
    CASE
        WHEN secondary_category LIKE project_category || '%' THEN '正常'
        WHEN secondary_category IS NULL THEN '二级分类缺失'
        ELSE '分类层级不匹配'
    END AS secondary_status
FROM sales_project_info
WHERE is_valid = 1;

COMMENT ON VIEW v_category_validation IS '项目分类规范性校验视图';

-- 8.3 校验地区信息完整性
-- =============================================
CREATE OR REPLACE VIEW v_region_validation AS
SELECT
    id,
    country,
    province,
    city,
    district,
    CASE
        WHEN country = '中国' AND province IS NULL THEN '国内项目省份缺失'
        WHEN province IS NOT NULL AND city IS NULL THEN '城市信息缺失'
        WHEN city IS NOT NULL AND district IS NULL THEN '区县信息缺失'
        ELSE '正常'
    END AS region_status
FROM sales_project_info
WHERE is_valid = 1;

COMMENT ON VIEW v_region_validation IS '地区信息完整性校验视图';

-- =============================================
-- 第九部分：定时执行数据质量检查
-- =============================================

-- 创建定时任务：每天自动执行数据质量检查
/*
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name => 'JOB_DATA_QUALITY_CHECK',
        job_type => 'STORED_PROCEDURE',
        job_action => 'sp_data_quality_check',
        start_date => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=9; BYMINUTE=0; BYSECOND=0',
        enabled => TRUE,
        comments => '每天上午9点自动执行数据质量检查'
    );
END;
/
*/

-- =============================================
-- 测试查询
-- =============================================

-- 测试重复数据检测
SELECT * FROM v_duplicate_records;

-- 测试缺失字段检测
SELECT * FROM v_missing_required_fields LIMIT 5;

-- 测试数据异常检测
SELECT * FROM v_amount_anomaly WHERE amount_status != '正常';

-- 测试数据质量评分
SELECT * FROM v_data_quality_score;