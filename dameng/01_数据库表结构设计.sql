-- =============================================
-- 达梦数据库 - 销售数据运营系统表结构设计
-- 功能：搭建标准化销售数据统计模板
-- 作者：数据运营团队
-- 创建时间：2026-06-26
-- =============================================

-- =============================================
-- 1. 主表：销售项目信息表
-- =============================================
DROP TABLE IF EXISTS sales_project_info;
CREATE TABLE sales_project_info (
    id BIGINT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    fill_enterprise VARCHAR(200),              -- 填报企业简称
    customer_name VARCHAR(500),                -- 客户名称（标准全称）
    project_nature VARCHAR(100),               -- 项目性质
    country VARCHAR(100),                      -- 国家
    ministry VARCHAR(200),                     -- 部委
    province VARCHAR(100),                     -- 省
    city VARCHAR(100),                         -- 市
    district VARCHAR(100),                     -- 区
    contract_party VARCHAR(500),               -- 合同甲方名称
    project_name VARCHAR(500),                 -- 项目名称
    project_category VARCHAR(100),             -- 项目所属分类
    secondary_category VARCHAR(200),           -- 二级分类
    business_segment VARCHAR(100),             -- 业务板块
    bid_date DATE,                             -- 中标日期
    bid_amount DECIMAL(18,2),                  -- 中标金额（万元）
    remark TEXT,                               -- 备注
    internal_org_no VARCHAR(100),              -- 内部机构号
    fill_unit VARCHAR(200),                    -- 填报人所属单位
    contract_no VARCHAR(200),                  -- 合同编号
    created_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_source VARCHAR(50),                   -- 数据来源
    is_valid TINYINT DEFAULT 1,               -- 数据有效性标识
    UNIQUE(contract_no)                        -- 合同编号唯一约束
);

-- 创建索引
CREATE INDEX idx_bid_date ON sales_project_info(bid_date);
CREATE INDEX idx_province ON sales_project_info(province);
CREATE INDEX idx_project_category ON sales_project_info(project_category);
CREATE INDEX idx_business_segment ON sales_project_info(business_segment);
CREATE INDEX idx_customer_name ON sales_project_info(customer_name);

COMMENT ON TABLE sales_project_info IS '销售项目信息主表';
COMMENT ON COLUMN sales_project_info.id IS '主键ID';
COMMENT ON COLUMN sales_project_info.fill_enterprise IS '填报企业简称';
COMMENT ON COLUMN sales_project_info.customer_name IS '客户名称（标准全称）';
COMMENT ON COLUMN sales_project_info.project_nature IS '项目性质';
COMMENT ON COLUMN sales_project_info.country IS '国家';
COMMENT ON COLUMN sales_project_info.ministry IS '部委';
COMMENT ON COLUMN sales_project_info.province IS '省份';
COMMENT ON COLUMN sales_project_info.city IS '城市';
COMMENT ON COLUMN sales_project_info.district IS '区县';
COMMENT ON COLUMN sales_project_info.contract_party IS '合同甲方名称';
COMMENT ON COLUMN sales_project_info.project_name IS '项目名称';
COMMENT ON COLUMN sales_project_info.project_category IS '项目所属分类';
COMMENT ON COLUMN sales_project_info.secondary_category IS '二级分类';
COMMENT ON COLUMN sales_project_info.business_segment IS '业务板块';
COMMENT ON COLUMN sales_project_info.bid_date IS '中标日期';
COMMENT ON COLUMN sales_project_info.bid_amount IS '中标金额（万元）';
COMMENT ON COLUMN sales_project_info.remark IS '备注';
COMMENT ON COLUMN sales_project_info.internal_org_no IS '内部机构号';
COMMENT ON COLUMN sales_project_info.fill_unit IS '填报人所属单位';
COMMENT ON COLUMN sales_project_info.contract_no IS '合同编号';
COMMENT ON COLUMN sales_project_info.created_time IS '创建时间';
COMMENT ON COLUMN sales_project_info.updated_time IS '更新时间';
COMMENT ON COLUMN sales_project_info.data_source IS '数据来源';
COMMENT ON COLUMN sales_project_info.is_valid IS '数据有效性标识';

-- =============================================
-- 2. 成本信息表
-- =============================================
DROP TABLE IF EXISTS sales_cost_info;
CREATE TABLE sales_cost_info (
    id BIGINT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    contract_no VARCHAR(200),                  -- 合同编号
    project_name VARCHAR(500),                 -- 项目名称
    cost_type VARCHAR(100),                    -- 成本类型（人力成本、采购成本、差旅成本、其他成本）
    cost_amount DECIMAL(18,2),                -- 成本金额（万元）
    cost_date DATE,                            -- 成本发生日期
    cost_description TEXT,                     -- 成本说明
    created_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (contract_no) REFERENCES sales_project_info(contract_no)
);

CREATE INDEX idx_cost_contract ON sales_cost_info(contract_no);
CREATE INDEX idx_cost_type ON sales_cost_info(cost_type);
CREATE INDEX idx_cost_date ON sales_cost_info(cost_date);

COMMENT ON TABLE sales_cost_info IS '销售成本信息表';

-- =============================================
-- 3. 回款信息表
-- =============================================
DROP TABLE IF EXISTS sales_payment_info;
CREATE TABLE sales_payment_info (
    id BIGINT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    contract_no VARCHAR(200),                  -- 合同编号
    project_name VARCHAR(500),                 -- 项目名称
    payment_stage VARCHAR(100),                -- 回款阶段（预付款、进度款、尾款）
    planned_amount DECIMAL(18,2),             -- 计划回款金额（万元）
    actual_amount DECIMAL(18,2),              -- 实际回款金额（万元）
    planned_date DATE,                        -- 计划回款日期
    actual_date DATE,                         -- 实际回款日期
    payment_status VARCHAR(50),                -- 回款状态（未回款、部分回款、已回款）
    created_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (contract_no) REFERENCES sales_project_info(contract_no)
);

CREATE INDEX idx_payment_contract ON sales_payment_info(contract_no);
CREATE INDEX idx_payment_status ON sales_payment_info(payment_status);
CREATE INDEX idx_payment_date ON sales_payment_info(planned_date, actual_date);

COMMENT ON TABLE sales_payment_info IS '销售回款信息表';

-- =============================================
-- 4. 销售过程跟踪表
-- =============================================
DROP TABLE IF EXISTS sales_process_tracking;
CREATE TABLE sales_process_tracking (
    id BIGINT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    contract_no VARCHAR(200),                  -- 合同编号
    project_name VARCHAR(500),                 -- 项目名称
    lead_source VARCHAR(100),                  -- 线索来源
    lead_date DATE,                            -- 线索录入日期
    contact_date DATE,                         -- 首次接触日期
    proposal_date DATE,                        -- 方案提交日期
    negotiation_date DATE,                     -- 商务谈判日期
    bid_date DATE,                             -- 投标/中标日期
    contract_sign_date DATE,                   -- 合同签订日期
    project_start_date DATE,                   -- 项目启动日期
    project_end_date DATE,                     -- 项目结束日期
    conversion_status VARCHAR(50),             -- 转化状态（线索、商机、中标、签约、完成）
    created_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (contract_no) REFERENCES sales_project_info(contract_no)
);

CREATE INDEX idx_tracking_contract ON sales_process_tracking(contract_no);
CREATE INDEX idx_conversion_status ON sales_process_tracking(conversion_status);
CREATE INDEX idx_lead_date ON sales_process_tracking(lead_date);

COMMENT ON TABLE sales_process_tracking IS '销售过程跟踪表';

-- =============================================
-- 5. 数据质量监控日志表
-- =============================================
DROP TABLE IF EXISTS data_quality_log;
CREATE TABLE data_quality_log (
    id BIGINT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    check_date DATE,                           -- 检查日期
    check_type VARCHAR(100),                   -- 检查类型（重复数据、缺失字段、异常数据等）
    table_name VARCHAR(100),                   -- 表名
    issue_count INTEGER,                       -- 问题数量
    issue_description TEXT,                    -- 问题描述
    issue_samples TEXT,                        -- 问题样例（JSON格式）
    status VARCHAR(50),                        -- 处理状态（待处理、已处理、已忽略）
    created_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_check_date ON data_quality_log(check_date);
CREATE INDEX idx_check_type ON data_quality_log(check_type);

COMMENT ON TABLE data_quality_log IS '数据质量监控日志表';

-- =============================================
-- 6. 月度经营分析结果表
-- =============================================
DROP TABLE IF EXISTS monthly_analysis_report;
CREATE TABLE monthly_analysis_report (
    id BIGINT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    report_month VARCHAR(7),                   -- 报告月份（YYYY-MM）
    region VARCHAR(100),                       -- 区域
    business_segment VARCHAR(100),             -- 业务板块
    total_projects INTEGER,                    -- 项目总数
    total_bid_amount DECIMAL(18,2),           -- 中标总金额
    total_cost DECIMAL(18,2),                  -- 总成本
    total_payment DECIMAL(18,2),               -- 总回款
    avg_payment_cycle DECIMAL(10,2),           -- 平均回款周期（天）
    conversion_rate DECIMAL(5,2),              -- 转化率（%）
    cost_profit_margin DECIMAL(5,2),          -- 成本利润率（%）
    created_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_report_month ON monthly_analysis_report(report_month);
CREATE INDEX idx_report_region ON monthly_analysis_report(region);

COMMENT ON TABLE monthly_analysis_report IS '月度经营分析结果表';

-- =============================================
-- 7. 区域维度字典表
-- =============================================
DROP TABLE IF EXISTS dim_region;
CREATE TABLE dim_region (
    id BIGINT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    region_code VARCHAR(50),                   -- 区域编码
    region_name VARCHAR(100),                  -- 区域名称
    province VARCHAR(100),                     -- 省份
    city VARCHAR(100),                         -- 城市
    parent_region VARCHAR(100),               -- 上级区域
    region_level INTEGER                       -- 区域级别（1-国家级，2-省级，3-市级）
);

COMMENT ON TABLE dim_region IS '区域维度字典表';

-- =============================================
-- 8. 业务板块字典表
-- =============================================
DROP TABLE IF EXISTS dim_business_segment;
CREATE TABLE dim_business_segment (
    id BIGINT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    segment_code VARCHAR(50),                  -- 板块编码
    segment_name VARCHAR(100),                 -- 板块名称
    parent_segment VARCHAR(100),               -- 上级板块
    description TEXT                           -- 描述
);

COMMENT ON TABLE dim_business_segment IS '业务板块字典表';

-- =============================================
-- 插入测试数据
-- =============================================
INSERT INTO sales_project_info (
    fill_enterprise, customer_name, project_nature, country, ministry, province, city, district,
    contract_party, project_name, project_category, secondary_category, business_segment,
    bid_date, bid_amount, remark, internal_org_no, fill_unit, contract_no
) VALUES (
    '达梦数据', '国家电投集团数字科技有限公司', '行业项目', '中国', NULL, '北京市', '北京市', '昌平区',
    '国家电投集团数字科技有限公司', '2025年二级单位自建系统改造及技术支持服务项目',
    '行业', '行业-电力', NULL, '2025-12-25', 52.00, NULL, NULL, NULL, 'WH202503202-2'
);