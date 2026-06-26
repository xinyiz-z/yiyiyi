import pandas as pd
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')
plt.rcParams['font.sans-serif'] = ['SimHei', 'Arial Unicode MS', 'DejaVu Sans']
plt.rcParams['axes.unicode_minus'] = False

# 读取数据
df = pd.read_excel('测试数据.xlsx', sheet_name='Sheet1', header=None, skiprows=2)
df.columns = ['填报企业简称', '客户名称', '项目性质', '国家', '部委', '省', '市', '区', 
              '合同甲方名称', '项目名称', '项目所属分类', '二级分类', '业务板块', 
              '中标日期', '中标金额', '备注', '内部机构号', '合同编号']
df['中标日期'] = pd.to_datetime(df['中标日期'])
df['中标金额'] = pd.to_numeric(df['中标金额'], errors='coerce')

# 创建图表
fig, axes = plt.subplots(2, 2, figsize=(14, 10))
fig.suptitle('销售数据运营分析报告', fontsize=16, fontweight='bold')

# 1. 区域销售TOP10柱状图
ax1 = axes[0, 0]
regional = df.groupby('省')['中标金额'].sum().sort_values(ascending=False).head(10)
regional.plot(kind='barh', ax=ax1, color='steelblue')
ax1.set_title('区域销售TOP10')
ax1.set_xlabel('金额(万元)')

# 2. 行业分布饼图
ax2 = axes[0, 1]
industry = df.groupby('二级分类')['中标金额'].sum().sort_values(ascending=False).head(8)
industry.plot(kind='pie', ax=ax2, autopct='%1.1f%%')
ax2.set_title('行业分布TOP8')
ax2.set_ylabel('')

# 3. 项目金额分布
ax3 = axes[1, 0]
amounts = df['中标金额']
bins = [0, 10, 30, 50, 100, 500]
labels = ['<10万', '10-30万', '30-50万', '50-100万', '>100万']
df['金额区间'] = pd.cut(amounts, bins=bins, labels=labels)
dist = df['金额区间'].value_counts().sort_index()
dist.plot(kind='bar', ax=ax3, color='coral')
ax3.set_title('项目金额分布')
ax3.set_xlabel('金额区间')
ax3.set_ylabel('项目数')
for i, v in enumerate(dist):
    ax3.text(i, v + 0.5, str(v), ha='center')

# 4. TOP10客户
ax4 = axes[1, 1]
top10 = df.groupby('客户名称')['中标金额'].sum().sort_values(ascending=False).head(10)
top10.plot(kind='barh', ax=ax4, color='seagreen')
ax4.set_title('TOP10客户')
ax4.set_xlabel('累计金额(万元)')

plt.tight_layout()
plt.savefig('销售分析图表.png', dpi=150, bbox_inches='tight')
print('图表已保存: 销售分析图表.png')