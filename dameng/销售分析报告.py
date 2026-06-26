import pandas as pd
import numpy as np
from datetime import datetime

# 读取Excel数据，跳过前两行（标题说明行），使用第2行作为列名
df = pd.read_excel('测试数据.xlsx', sheet_name='Sheet1', header=None, skiprows=2)

# 定义列名
df.columns = ['填报企业简称', '客户名称', '项目性质', '国家', '部委', '省', '市', '区', 
              '合同甲方名称', '项目名称', '项目所属分类', '二级分类', '业务板块', 
              '中标日期', '中标金额', '备注', '内部机构号', '合同编号']

# 转换日期和金额
df['中标日期'] = pd.to_datetime(df['中标日期'])
df['中标金额'] = pd.to_numeric(df['中标金额'], errors='coerce')

print("=" * 60)
print("销售数据运营分析报告")
print("=" * 60)

# 1. 基础数据概览
print("\n【一、基础数据概览】")
print(f"总项目数: {len(df)}")
total_amount = df['中标金额'].sum()
print(f"总中标金额: {total_amount:.2f} 万元")
print(f"平均中标金额: {df['中标金额'].mean():.2f} 万元")
print(f"最大中标金额: {df['中标金额'].max():.2f} 万元")
print(f"最小中标金额: {df['中标金额'].min():.2f} 万元")

# 2. 项目金额分布
print("\n【二、项目金额分布】")
amounts = df['中标金额']
large = len(df[amounts >= 100])
medium = len(df[(amounts >= 50) & (amounts < 100)])
small = len(df[amounts < 50])
print(f"大型项目(≥100万): {large} 个")
print(f"中型项目(50-100万): {medium} 个")
print(f"小型项目(<50万): {small} 个")

# 3. 区域分析
print("\n【三、区域销售分析】")
regional = df.groupby('省').agg({
    '中标金额': ['count', 'sum', 'mean']
}).round(2)
regional.columns = ['项目数', '总金额(万)', '平均金额(万)']
regional = regional.sort_values('总金额(万)', ascending=False)
print(regional.to_string())

# 4. 行业分布
print("\n【四、行业分布分析】")
industry = df.groupby('二级分类').agg({
    '中标金额': ['count', 'sum']
}).round(2)
industry.columns = ['项目数', '总金额(万)']
industry = industry.sort_values('总金额(万)', ascending=False)
print(industry.to_string())

# 5. 业务板块分析
print("\n【五、业务板块分析】")
seg = df.groupby('业务板块').agg({
    '中标金额': ['count', 'sum']
}).round(2)
seg.columns = ['项目数', '总金额(万)']
seg = seg.sort_values('总金额(万)', ascending=False)
print(seg.to_string())

# 6. 月度分布
print("\n【六、月度销售分布】")
df['月份'] = df['中标日期'].dt.strftime('%Y-%m')
monthly = df.groupby('月份').agg({
    '中标金额': ['count', 'sum']
}).round(2)
monthly.columns = ['项目数', '总金额(万)']
monthly = monthly.sort_index()
print(monthly.to_string())

# 7. 客户分析
print("\n【七、客户分析】")
customer_counts = df['客户名称'].value_counts()
print(f"总客户数: {len(customer_counts)}")
repeat = len(customer_counts[customer_counts > 1])
print(f"重复采购客户数: {repeat}")
print("\nTOP10客户:")
top_customers = df.groupby('客户名称').agg({
    '中标金额': 'sum'
}).sort_values('中标金额', ascending=False).head(10)
print(top_customers.to_string())

# 8. 甲方分析
print("\n【八、合同甲方TOP10】")
top_parties = df.groupby('合同甲方名称').agg({
    '中标金额': 'sum'
}).sort_values('中标金额', ascending=False).head(10)
print(top_parties.to_string())

print("\n" + "=" * 60)
print("报告生成时间:", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
print("=" * 60)