# 短链平台 - Microservices Demo (Java)

基于 **Spring Cloud Alibaba** 的短链生成与跳转微服务。

> ✅ **已验证**：`mvn clean install` 编译通过，**20 个单元测试全部通过**（Base62 × 7 + ShortCodeGenerator × 5 + UrlValidator × 8）。

## 项目结构

```
short-link-platform/
├── pom.xml                           # 父 POM（统一版本管理）
├── short-link-common/                # 公共模块
│   └── src/main/java/com/shortlink/common/
│       ├── result/                   # 统一返回 Result / ResultCode
│       ├── exception/                # BizException / GlobalExceptionHandler
│       └── util/                     # Base62Util / ShortCodeGenerator / UrlValidator
│
├── short-link-generate/              # 短链生成服务（写流量，端口 9001）
│   ├── src/main/java/com/shortlink/generate/
│   │   ├── controller/               # POST /api/v1/short-link/generate
│   │   ├── service/                  # 生成核心逻辑（幂等、缓存、碰撞重试）
│   │   ├── mapper/                   # MyBatis-Plus DAO
│   │   ├── entity/                   # ShortLink 实体
│   │   ├── dto/                      # GenerateRequest / GenerateResponse
│   │   └── config/                   # MyBatis-Plus、Redis 配置
│   └── src/main/resources/
│       ├── application.yml
│       ├── mapper/ShortLinkMapper.xml
│       └── db/schema.sql             # 建表脚本
│
└── short-link-redirect/              # 短链跳转服务（读流量，端口 9002）
    └── src/main/java/com/shortlink/redirect/
        ├── controller/               # GET /s/{shortCode}  302 跳转
        ├── service/                  # 缓存查询 + Feign 回源 + 异步计数
        ├── feign/                    # OpenFeign 调用 generate 服务
        ├── dto/                      # 缓存 DTO / Feign 响应
        └── config/                   # Redis / Feign 配置
```

## 技术栈

| 组件                | 版本 / 选型                                |
| ------------------- | ------------------------------------------ |
| JDK                 | 17                                         |
| Spring Boot         | 3.2.5                                      |
| Spring Cloud        | 2023.0.3                                   |
| Spring Cloud Alibaba| 2023.0.1.0（Nacos Discovery + Config）     |
| MyBatis-Plus        | 3.5.7                                      |
| MySQL               | 8.0+                                       |
| Redis               | Lettuce Client                             |
| OpenFeign           | Spring Cloud OpenFeign                     |
| 服务注册/配置中心   | Nacos 2.x                                  |
| 工具库              | Hutool 5.8 / Guava 33 / Lombok 1.18        |

## 短码生成算法

**SHA-256 + Base62 + 碰撞重试**

```
longUrl + "#" + salt
       ↓
   SHA-256
       ↓
  取前 8 字节 → long
       ↓
   Base62 编码
       ↓
  截取前 7 位
```

- **空间**：7 位 Base62 = 62^7 ≈ **3.5 万亿**，1 亿条数据碰撞概率 ≈ 5.4 × 10⁻¹¹
- **碰撞处理**：salt 自增（0~4）共 5 次重试
- **最终兜底**：DB `uniq_short_code` 唯一约束 + 业务捕获 `DuplicateKeyException`
- **幂等性**：长链 SHA-256 → `uniq_url_hash` 唯一约束 + Redis 缓存，同一长链始终返回同一短码

## 微服务交互

```
            ┌─────────────────────────────┐
            │      Client Browser         │
            └──────────────┬──────────────┘
                           │ GET /s/{code}
                           ▼
            ┌─────────────────────────────┐
            │  short-link-redirect :9002  │ ← 高 QPS 跳转入口
            └──────────────┬──────────────┘
                           │ 1) Redis 查缓存
                           │ 2) miss → Feign 回源
                           ▼
            ┌─────────────────────────────┐
            │  short-link-generate :9001  │ ← 短链生成 / 元数据查询
            └──────────────┬──────────────┘
                           │
                  ┌────────┴────────┐
                  ▼                 ▼
            ┌──────────┐      ┌──────────┐
            │  MySQL   │      │  Redis   │
            └──────────┘      └──────────┘
```

**读写分离设计要点**：
- `generate` 承担"写"流量（生成、查询元数据），独立 MySQL 连接池（HikariCP 50）
- `redirect` 承担"读"流量（跳转），大 Tomcat 线程池（800），独立 Redis 连接池（500）
- 两服务通过 **Nacos** 做服务发现 + 配置中心，通过 **OpenFeign** 跨服务调用
- `redirect` 不直连 MySQL（冷启动更快、故障域隔离），缓存 miss 时回源 generate

## 一键启动（Windows 推荐）

项目根目录提供 3 个 PowerShell 脚本，自动完成"启动中间件 → 部署 jar → 端到端测试 → 收尾"全流程：

| 脚本 | 作用 |
| --- | --- |
| `start-all.ps1` | 自检 → 启 MySQL → 初始化 schema.sql → 启 Redis → 启/下载 Nacos → 后台启 generate & redirect → 端到端冒烟测试 |
| `stop-all.ps1`  | 按端口反查 PID，干净停 generate / redirect / Nacos（保留 MySQL & Redis） |
| `status-all.ps1` | 查 Windows 服务状态 + Java 微服务端口 + 磁盘占用 |

### 使用步骤

```powershell
# 1. 右键 PowerShell → 以管理员身份运行（必须！脚本要 Start-Service 启 MySQL/Redis）
# 2. cd 到项目根目录
cd 'E:\zxy\简历\项目\短链平台 - Microservices Demo'

# 3. 一键启动（约 1-2 分钟，含 Nacos 下载）
.\start-all.ps1
```

启动完成会看到类似：

```
========== 短链平台一键启动 ==========
 OK  管理员权限
 OK  Java 已就绪
 OK  可执行 jar 已打包

--- [1/5] 启动 MySQL ---
 OK  MySQL Running
--- [2/5] 初始化数据库 ---
 OK  数据库表已就绪
--- [3/5] 启动 Redis ---
 OK  Redis Running
--- [4/5] 启动 Nacos ---
 OK  Nacos 8848 已就绪
--- [5/5] 启动 generate + redirect ---
 OK  generate 9001 已就绪
 OK  redirect 9002 已就绪

========== 端到端验证 ==========
[生成短链] 响应: { ... shortCode: "aB3xY9z" ... }
  HTTP 302  Location: https://www.example.com/test/path?query=1

*** 全部跑通！***
```

### 配置自定义（按需修改脚本）

`start-all.ps1` 顶部 `# ---------- 配置 ----------` 段可改：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `$MysqlService` | `MYSQL80` | Windows 服务名 |
| `$RedisService` | `rediszt3` | Windows 服务名 |
| `$MysqlExe` | `C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe` | mysql 客户端路径 |
| `$NacosDir` | `C:\nacos\nacos` | Nacos 安装目录（首次自动下载） |
| `$NacosVersion` | `2.3.2` | Nacos 版本 |
| `$MysqlUser` / `$MysqlPass` | `root` / `root` | MySQL 凭证（请按本地修改） |
| `$GeneratePort` / `$RedirectPort` | `9001` / `9002` | 微服务端口 |

### 常见问题

- **端口被占用** → `netstat -ano | findstr :9001` 找占用 PID，`Stop-Process -Id <PID>`
- **Nacos 注册失败** → 确认 `application.yml` 中 `spring.cloud.nacos.discovery.server-addr` 是 `127.0.0.1:8848`
- **管理员权限缺失** → 脚本会检测并直接退出，重开管理员 PowerShell 重跑

---

## 快速启动

### 1. 启动基础中间件

确保本地已启动：
- **MySQL 8.x** （端口 3306）
- **Redis 7.x** （端口 6379）
- **Nacos 2.x** （端口 8848，用户名/密码 nacos/nacos）

### 2. 初始化数据库

```bash
mysql -uroot -p < short-link-generate/src/main/resources/db/schema.sql
```

### 3. 构建并启动

```bash
# 编译所有模块
mvn clean install -DskipTests

# 启动 generate 服务
cd short-link-generate && mvn spring-boot:run

# 另起终端，启动 redirect 服务
cd short-link-redirect && mvn spring-boot:run
```

### 4. 调用测试

```bash
# 生成短链
curl -X POST http://localhost:9001/api/v1/short-link/generate \
     -H "Content-Type: application/json" \
     -d '{"longUrl":"https://www.example.com/very/long/path"}'

# 返回示例
# {"code":0,"message":"success","data":{"shortCode":"aB3xY9z","shortUrl":"http://s.local/aB3xY9z",...}}

# 访问短链（302 跳转）
curl -i http://localhost:9002/s/aB3xY9z
```

## 核心特性

| 特性                  | 实现                                                       |
| --------------------- | ---------------------------------------------------------- |
| 幂等生成              | 长链 SHA-256 → `uniq_url_hash` + Redis 缓存                |
| 碰撞重试              | salt 自增，最多 5 次；DB unique 索引兜底                   |
| 高 QPS 跳转           | Redis 主缓存 → Feign 快速回源 → 异步点击计数               |
| 读写分离              | generate / redirect 独立部署，独立扩缩容                   |
| 服务发现              | Nacos Discovery                                            |
| 统一异常处理          | `GlobalExceptionHandler` 抽到 common 模块                  |
| 统一返回结构          | `Result<T>` 抽到 common 模块                               |
| 逻辑删除 + 乐观锁     | MyBatis-Plus `@TableLogic` + `@Version`                    |
| 自动化字段填充        | MyBatis-Plus `MetaObjectHandler`（createdTime/updatedTime）|
| 参数校验              | Jakarta Validation + `MethodArgumentNotValidException`     |

## 后续可扩展

- [ ] Spring Cloud Gateway 统一网关（限流、鉴权、灰度）
- [ ] Sentinel 熔断限流（防止雪崩、缓存穿透/击穿/雪崩专项）
- [ ] 布隆过滤器（拦截不存在的短码，保护下游）
- [ ] Kafka/RocketMQ 异步解耦（点击日志、统计、通知）
- [ ] 短链管理后台（CRUD、批量生成、域名管理、数据看板）
- [ ] 分布式发号器（Leaf / Snowflake 取代纯哈希方案）
- [ ] 多级缓存（本地 Caffeine + Redis，预热热点短码）
