# 机构经纪智能体 - 本地化实施方案

## 一、方案概述

基于当前员工端交互原型（卡片式人机交互界面），本方案明确本地化部署的技术架构、数据流和模型对接标准。

---

## 二、架构分层

```
┌─────────────────────────────────────────────────────────────┐
│                    员工端交互层（本地部署）                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  引入客户    │  │  账户开立    │  │  交易服务    │         │
│  │  （潜客挖掘） │  │ （高净值开户）│  │ （系统配置） │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│  ┌─────────────┐  ┌─────────────────────────────────────┐  │
│  │  客户服务    │  │           业绩看板                   │  │
│  │ （舆情/回访）│  │      （数据可视化/分析）              │  │
│  └─────────────┘  └─────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              智能体编排层（本地/混合部署）                     │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Agent Orchestrator                     │   │
│  │         （任务分解、路由、上下文管理）                │   │
│  └─────────────────────────────────────────────────────┘   │
│                         │                                   │
│         ┌───────────────┼───────────────┐                  │
│         ▼               ▼               ▼                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ 业务Agent   │  │ 工具Agent   │  │ 记忆Agent   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌──────────────────────────┐    ┌──────────────────────────┐
│   本地模型层（私有部署）   │    │  公司自动驾驶基础大模型   │
│  ┌────────────────────┐  │    │  ┌────────────────────┐  │
│  │ 本地推理引擎        │  │    │  │ 统一语料接口        │  │
│  │ (LLaMA/Qwen等)     │  │    │  │ 关系网络服务        │  │
│  └────────────────────┘  │    │  │ 身份权限服务        │  │
│                          │    │  └────────────────────┘  │
└──────────────────────────┘    └──────────────────────────┘
```

---

## 三、本地与公司基础大模型的相互调用

### 3.1 双向语料反哺机制

```
┌─────────────────────────────────────────────────────────────────┐
│                      语料双向流动架构                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌──────────────┐         查询/检索          ┌──────────────┐  │
│   │              │ ─────────────────────────▶ │   公司自动驾驶 │  │
│   │   本地工作台  │                            │   大模型语料中心│  │
│   │   (员工端)   │ ◀───────────────────────── │              │  │
│   │              │      语料更新/反馈         └──────────────┘  │
│   └──────┬───────┘                                            │
│          │                                                      │
│          ▼ 语料沉淀                                             │
│   ┌──────────────┐                                            │
│   │ 本地语料库   │ ◀── 机构经纪业务规则                        │
│   │              │ ◀── 客户账户信息（脱敏）                     │
│   │              │ ◀── 员工行为信息                            │
│   │              │ ◀── 业务操作日志                            │
│   └──────┬───────┘                                            │
│          │                                                      │
│          ▼ 反哺更新                                             │
│   ┌──────────────┐         新增/更新语料        ┌──────────────┐│
│   │ 语料加工引擎  │ ───────────────────────────▶ │ 公司语料中心  ││
│   │ (清洗/标注)  │                              │ (审核/入库)  ││
│   └──────────────┘                              └──────────────┘│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 3.1.1 语料分类与流向

| 语料类型 | 本地内容 | 流向公司 | 反哺内容 | 更新频率 |
|---------|---------|---------|---------|---------|
| **业务规则语料** | 机构经纪业务流程、合规要求 | ✓ 初始化同步 | 新业务规则沉淀 | 实时 |
| **客户账户信息** | 客户档案、交易偏好、服务历史 | ✗ 不上传（脱敏后上传行为模式） | 客户服务最佳实践 | 日批量 |
| **员工行为信息** | 展业操作、话术使用、成交记录 | ✓ 脱敏后上传 | 高效展业模式 | 日批量 |
| **问答语料** | 客户咨询、员工回复、解决方案 | ✓ 质量筛选后上传 | 标准问答对 | 实时 |
| **案例语料** | 成功案例、失败教训、处理流程 | ✓ 标注后上传 | 案例库扩充 | 周批量 |

#### 3.1.2 语料反哺API

```yaml
# 本地向公司语料中心反哺新语料

paths:
  /api/v1/corpus/feedback:
    post:
      summary: 语料反馈上传
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                corpus_type:
                  type: string
                  enum: [business_rule, qa_pair, case_study, best_practice]
                content:
                  type: object
                  properties:
                    title: string
                    content: string
                    source: string
                    employee_id: string
                    timestamp: string
                    quality_score: number
                metadata:
                  type: object
                  properties:
                    customer_id: string  # 可选，脱敏
                    business_line: string
                    tags: array
      responses:
        200:
          description: 语料接收成功，进入审核流程
          content:
            application/json:
              schema:
                type: object
                properties:
                  corpus_id: string
                  status: string  # pending_review
                  estimated_review_time: string

  /api/v1/corpus/updates:
    get:
      summary: 获取公司语料中心更新
      parameters:
        - name: last_sync_time
          in: query
          required: true
          schema:
            type: string
            format: date-time
      responses:
        200:
          description: 语料更新列表
          content:
            application/json:
              schema:
                type: object
                properties:
                  updates:
                    type: array
                    items:
                      type: object
                      properties:
                        corpus_id: string
                        type: string
                        action: string  # add/update/delete
                        content: object
                        effective_time: string
```

### 3.2 调用内容清单

| 调用方向 | 调用内容 | 数据类型 | 频率 | 说明 |
|---------|---------|---------|------|------|
| **本地 → 公司** | 客户身份验证 | 身份ID | 每次会话 | 统一身份打通 |
| **本地 → 公司** | 客户画像查询 | 客户ID | 实时 | 获取关系网络数据 |
| **本地 → 公司** | 历史交易记录 | 账户ID | 按需 | 风控/服务参考 |
| **本地 → 公司** | 舆情/监管数据 | 客户名称 | 定时同步 | 客户服务用 |
| **本地 → 公司** | 语料反馈上传 | 语料JSON | 实时/批量 | 反哺语料中心 |
| **公司 → 本地** | 任务派发 | 任务JSON | 实时 | 公司级调度 |
| **公司 → 本地** | 考核指标 | KPI数据 | 日/周 | AI驱动考核 |
| **公司 → 本地** | 知识更新 | 知识条目 | 定时 | 知识库同步 |
| **公司 → 本地** | 语料更新 | 语料增量 | 实时推送 | 知识库更新 |

### 3.3 API接口标准

```yaml
# 本地调用公司基础大模型接口示例
openapi: 3.0.0
info:
  title: 公司自动驾驶大模型接口
  version: 1.0.0

paths:
  /api/v1/identity/verify:
    post:
      summary: 身份验证
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                user_id: string
                token: string
      responses:
        200:
          description: 验证成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  user_profile: object
                  permissions: array
                  org_info: object

  /api/v1/customer/profile:
    get:
      summary: 获取客户画像
      parameters:
        - name: customer_id
          in: query
          required: true
          schema:
            type: string
      responses:
        200:
          description: 客户画像数据
          content:
            application/json:
              schema:
                type: object
                properties:
                  basic_info: object
                  relationship_network: object
                  transaction_history: array
                  risk_profile: object

  /api/v1/knowledge/query:
    post:
      summary: 知识库查询
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                query: string
                context: object
      responses:
        200:
          description: 知识检索结果
          content:
            application/json:
              schema:
                type: object
                properties:
                  answer: string
                  sources: array
                  confidence: number
```

---

## 四、语料数据分层

### 4.1 外网调用语料（公有云）

| 语料类型 | 来源 | 用途 | 更新频率 |
|---------|------|------|---------|
| **公开舆情** | 财经媒体、社交平台 | 客户服务-舆情监控 | 实时流式 |
| **行业报告** | 券商研报、智库 | 市场分析、话术生成 | 日更新 |
| **监管公告** | 证监会、交易所 | 合规检查、风险预警 | 实时推送 |
| **公开财报** | 上市公司披露 | 客户分析、资质评估 | 季度更新 |
| **宏观经济** | 国家统计局、央行 | 市场研判、客户沟通 | 月度更新 |

**外网调用原则：**
- 只获取公开信息，不涉及客户隐私
- 通过公司统一出口，统一脱敏处理
- 缓存策略：热点数据本地缓存24小时

### 4.2 本地语料（私有部署）

| 语料类型 | 内容 | 量级 | 存储方式 |
|---------|------|------|---------|
| **客户私有数据** | 客户档案、交易记录、沟通历史 | TB级 | 本地加密数据库 |
| **公司内部制度** | 业务流程、合规要求、产品手册 | GB级 | 向量数据库 |
| **员工操作记录** | 展业日志、操作轨迹、业绩数据 | GB级 | 时序数据库 |
| **知识库** | 话术模板、FAQ、最佳实践 | MB级 | 文档数据库 |
| **模型缓存** | 推理结果、Embedding向量 | GB级 | 内存+SSD缓存 |

**本地语料管理：**
```
本地语料库结构：
├── customer_data/          # 客户私有数据（加密）
│   ├── profiles/           # 客户画像
│   ├── transactions/       # 交易记录
│   └── communications/     # 沟通历史
├── knowledge_base/         # 知识库
│   ├── products/           # 产品资料
│   ├── processes/          # 业务流程
│   └── templates/          # 话术模板
├── internal_docs/          # 内部文档
│   ├── compliance/         # 合规文件
│   ├── policies/           # 制度规范
│   └── training/           # 培训资料
└── model_cache/            # 模型缓存
    ├── embeddings/         # 向量缓存
    └── inference/          # 推理缓存
```

---

## 五、大语言模型标准化对接

### 5.1 对接架构

```
┌─────────────────────────────────────────────────────────┐
│                  公司指定基础大模型                        │
│           （统一API网关 / 私有化部署）                     │
│  ┌─────────────────┐  ┌─────────────────┐              │
│  │  统一语料接口    │  │  推理服务接口    │              │
│  │  (RAG服务)      │  │  (LLM推理)      │              │
│  └─────────────────┘  └─────────────────┘              │
└─────────────────────────────────────────────────────────┘
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
    ┌──────────────┐ ┌──────────┐ ┌──────────────┐
    │  标准适配层   │ │ 安全网关  │ │ 负载均衡层    │
    │ (协议转换)   │ │ (脱敏/审计)│ │ (流量分发)   │
    └──────────────┘ └──────────┘ └──────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   本地智能体系统                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │              模型调用客户端                      │   │
│  │  • 统一SDK封装                                 │   │
│  │  • 本地缓存层                                  │   │
│  │  • 失败重试机制                                │   │
│  │  • 成本监控                                    │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### 5.2 标准化接口定义

```python
# 公司基础大模型标准接口
class CompanyFoundationModelClient:
    """公司自动驾驶基础大模型客户端"""
    
    def __init__(self, api_endpoint, auth_token):
        self.endpoint = api_endpoint
        self.token = auth_token
        self.cache = LocalCache()
    
    def chat_completion(self, messages, context=None, tools=None):
        """
        标准对话接口
        
        Args:
            messages: 对话历史 [{role, content}]
            context: 业务上下文 {customer_id, session_id, ...}
            tools: 可调用的工具列表
            
        Returns:
            {
                "content": "模型回复",
                "tool_calls": [...],
                "usage": {"prompt_tokens": 100, "completion_tokens": 50},
                "sources": ["引用来源"]
            }
        """
        # 调用公司统一API
        pass
    
    def retrieve_knowledge(self, query, filters=None, top_k=5):
        """
        知识库检索（RAG）
        
        Args:
            query: 查询内容
            filters: 过滤条件 {doc_type, date_range, ...}
            top_k: 返回结果数
            
        Returns:
            {
                "results": [
                    {"content": "", "source": "", "score": 0.95}
                ],
                "total": 100
            }
        """
        pass
    
    def embed_text(self, texts):
        """文本向量化"""
        pass
    
    def analyze_sentiment(self, text):
        """情感分析"""
        pass

# 本地智能体调用示例
class BrokerageAgent:
    """机构经纪智能体"""
    
    def __init__(self):
        self.model = CompanyFoundationModelClient(
            api_endpoint="https://company-llm.internal/api/v1",
            auth_token="${COMPANY_LLM_TOKEN}"
        )
        self.local_kb = LocalKnowledgeBase()
    
    def handle_customer_inquiry(self, customer_id, query):
        """处理客户咨询"""
        # 1. 从公司基础模型获取客户画像
        customer_profile = self.model.retrieve_customer_profile(customer_id)
        
        # 2. 本地知识库检索
        local_context = self.local_kb.search(query, customer_id)
        
        # 3. 构建提示词
        messages = [
            {"role": "system", "content": self.get_system_prompt()},
            {"role": "user", "content": f"客户画像：{customer_profile}\n查询：{query}"}
        ]
        
        # 4. 调用公司基础模型
        response = self.model.chat_completion(
            messages=messages,
            context={"customer_id": customer_id, "business_line": "brokerage"},
            tools=["query_account", "generate_report"]
        )
        
        return response
```

### 5.3 配置参数

```yaml
# config.yaml - 大模型对接配置

company_foundation_model:
  # 基础配置
  api_endpoint: "https://company-llm.internal/api/v1"
  auth_type: "bearer_token"
  timeout: 30
  max_retries: 3
  
  # 模型参数
  default_model: "company-llm-v1"
  temperature: 0.7
  max_tokens: 4096
  top_p: 0.95
  
  # 本地缓存
  cache:
    enabled: true
    ttl: 3600  # 1小时
    max_size: "10GB"
  
  # 成本监控
  cost_tracking:
    enabled: true
    alert_threshold: 1000  # 日限额

local_deployment:
  # 本地推理引擎（可选，用于离线场景）
  local_inference:
    enabled: false
    model_path: "/models/local-llm"
    device: "cuda"
  
  # 数据存储
  storage:
    customer_data: "/data/customer"
    knowledge_base: "/data/knowledge"
    cache: "/data/cache"
  
  # 安全策略
  security:
    data_encryption: true
    access_control: true
    audit_log: true
```

---

## 六、数据安全与合规

### 6.1 数据分级

| 数据级别 | 内容 | 存储位置 | 访问控制 |
|---------|------|---------|---------|
| L1-公开 | 产品资料、业务流程 | 本地+云端 | 全员可读 |
| L2-内部 | 制度规范、操作手册 | 本地 | 员工可读 |
| L3-敏感 | 客户档案、交易数据 | 本地加密 | 授权访问 |
| L4-机密 | 核心算法、风控规则 | 本地隔离 | 最小权限 |

### 6.2 传输安全

- 所有调用公司基础模型的接口使用HTTPS/TLS 1.3
- 敏感数据字段端到端加密（AES-256-GCM）
- API调用双向认证（mTLS）

### 6.3 审计日志

```json
{
  "timestamp": "2024-03-04T10:30:00Z",
  "user_id": "employee_001",
  "action": "model_query",
  "request": {
    "endpoint": "/api/v1/chat/completion",
    "customer_id": "C2024030401",
    "query_hash": "sha256:abc123..."
  },
  "response": {
    "status": "success",
    "tokens_used": 150,
    "response_hash": "sha256:def456..."
  },
  "compliance": {
    "data_classification": "L3",
    "encryption": true,
    "retention_days": 365
  }
}
```

---

## 七、部署清单

### 7.1 硬件要求

| 组件 | 最低配置 | 推荐配置 | 说明 |
|------|---------|---------|------|
| 应用服务器 | 4C8G | 8C16G | 运行智能体系统 |
| 缓存服务器 | 4C8G | 8C16G | Redis/Memcached |
| 数据库服务器 | 8C16G | 16C32G | PostgreSQL + 向量库 |
| GPU服务器（可选） | 1xA10 | 2xA100 | 本地推理加速 |

### 7.2 软件依赖

```bash
# 基础环境
- Docker 24.0+
- Kubernetes 1.28+（可选）
- Python 3.11+
- Node.js 18+

# 中间件
- PostgreSQL 15+（主数据）
- Milvus/PGVector（向量库）
- Redis 7+（缓存）
- MinIO（对象存储）

# 安全组件
- HashiCorp Vault（密钥管理）
- Kong/AWS API Gateway（API网关）
```

---

## 八、实施路线图

```
Phase 1（1-2周）：基础环境搭建
├── 本地服务器部署
├── 与公司基础模型网络打通
├── 基础数据同步
└── 安全策略配置

Phase 2（2-4周）：核心功能上线
├── 引入客户模块（潜客挖掘）
├── 账户开立模块（高净值开户）
├── 公司基础模型对接测试
└── 内部试用

Phase 3（4-6周）：功能完善
├── 交易服务模块
├── 客户服务模块
├── 业绩看板
└── 全面推广

Phase 4（6-8周）：优化迭代
├── 性能优化
├── 用户反馈收集
├── 功能迭代
└── 知识库完善
```

---

## 九、提示词工程体系

### 9.1 提示词分层架构

```
┌─────────────────────────────────────────────────────────────────┐
│                      提示词工程体系                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                 系统提示词 (System Prompt)                │  │
│  │  • 角色定义：机构经纪智能助手                              │  │
│  │  • 能力边界：客户开发、账户管理、交易服务、客户关怀          │  │
│  │  • 合规约束：证券行业合规要求、数据安全规范                  │  │
│  │  • 输出格式：卡片式交互、步骤化引导、数据可视化              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                 业务提示词 (Business Prompt)              │  │
│  │  • 引入客户：线索收集、资质评估、分配跟进话术               │  │
│  │  • 账户开立：高净值开户流程、材料审核标准、风险评估话术      │  │
│  │  • 交易服务：系统配置指导、异常处理流程、成交分析解读        │  │
│  │  • 客户服务：舆情应对、回访话术、投诉处理、满意度管理        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                 交互提示词 (Interaction Prompt)           │  │
│  │  • 意图识别：理解员工输入，匹配业务场景                      │  │
│  │  • 上下文管理：维护对话状态，追踪任务进度                    │  │
│  │  • 个性化适配：根据员工角色、客户类型调整话术               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 9.2 系统提示词（核心）

```yaml
# system_prompt.yaml
version: "1.0"
description: 机构经纪智能助手系统提示词

system_prompt: |
  你是【机构经纪智能助手】，专门服务于证券公司机构经纪业务线的员工。
  
  ## 你的身份定位
  - **名称**：机构经纪智能助手
  - **角色**：业务支持专家 + 客户开发助手 + 合规风控顾问
  - **服务对象**：机构经纪业务线客户经理、业务支持人员
  - **工作场景**：客户开发、账户管理、交易服务、客户关怀、业绩分析
  
  ## 核心能力
  1. **客户开发支持**
     - 发现潜在线索：扫描邮件、活动、招标等多渠道
     - AI资质评估：多维度评估客户匹配度
     - 智能分配：推荐最适合的客户经理
     - 跟进提醒：自动设置回访计划
  
  2. **账户管理服务**
     - 高净值开户：指导客户完成开户全流程
     - 资料审核：AI辅助审核开户材料
     - 权限配置：交易系统权限设置
     - 进度跟踪：实时展示开户进度
  
  3. **交易服务支持**
     - 系统配置：算法交易参数配置
     - 异常监控：实时预警异常交易
     - 成交分析：交易成本归因分析
     - 技术支持：解答交易相关问题
  
  4. **客户关怀服务**
     - 舆情监控：实时监测客户相关舆情
     - 定期回访：智能提醒并辅助回访
     - 投诉处理：指导客户投诉处理流程
     - 满意度管理：收集并分析客户反馈
  
  5. **业绩分析展示**
     - 数据可视化：展示个人/团队业绩
     - 智能洞察：AI分析业务机会
     - 目标跟踪：实时追踪KPI完成情况
     - 预测分析：预测成交概率和时点
  
  ## 交互规范
  - **语言风格**：简洁明了，避免专业术语堆砌，新人也能理解
  - **交互形式**：卡片式界面，每个任务清晰展示步骤和状态
  - **智能预判**：主动预判用户需求，提前准备相关信息
  - **自然语言**：支持口语化输入，理解多种表达方式
  
  ## 合规要求（必须遵守）
  - ✅ 严格遵守证券行业监管规定，不得违规承诺收益
  - ✅ 客户敏感信息（姓名、电话、资产等）必须脱敏显示
  - ✅ 投资建议必须提示风险，不得诱导交易
  - ✅ 所有操作记录完整审计日志，可追溯可审计
  - ✅ 客户隐私数据不得外泄，遵循最小必要原则
  
  ## 输出格式规范
  - 使用Markdown格式，支持**加粗**、`代码`、列表等
  - 关键信息🔴高亮显示，紧急事项使用⚠️标识
  - 操作按钮明确，提供[快捷入口]
  - 复杂流程分步骤展示：① ② ③
  - 数据展示使用表格或卡片，一目了然

context_variables:
  employee_id: "员工ID"
  employee_name: "员工姓名"
  department: "所属部门"
  role: "角色权限"
  current_customer: "当前服务客户"
  session_history: "对话历史"
```

### 9.3 业务提示词示例

```yaml
# business_prompts.yaml
version: "1.0"
description: 各业务场景的提示词模板

业务场景:
  
  引入客户_线索收集:
    trigger: "员工触发潜客挖掘功能"
    prompt: |
      你正在协助员工执行【线索收集】任务。
      
      ## 任务目标
      从多渠道发现潜在机构客户线索，并初步评估价值。
      
      ## 信息来源
      1. **邮件往来**：扫描员工邮箱，识别客户咨询意向
      2. **行业活动**：分析近期参会名单、交换名片
      3. **公开市场**：监控招投标信息、券商遴选公告
      4. **同业转介**：记录其他部门/同事推荐线索
      
      ## 输出要求
      对每条线索输出以下信息：
      - 📌 **线索来源**：邮件/活动/招标/转介
      - 🏢 **客户名称**：机构全称
      - 👤 **联系人**：姓名、职位
      - 📞 **联系方式**：电话、邮箱
      - 📝 **需求描述**：具体需求、痛点
      - 💰 **预计规模**：潜在资金规模
      - ⭐ **质量评分**：1-100分
      - 🎯 **优先级**：高/中/低
      - 💡 **建议行动**：录入/联系/搁置
      
      ## 示例输出格式
      ```
      📧 邮件线索 - 易方达投资
      • 联系人：张总（投资总监）
      • 需求：咨询TWAP算法交易费用
      • 预计规模：5000万/月
      • 质量评分：92分（高价值）
      • 优先级：🔴 高
      • 建议：[录入线索] [发送资料] [安排拜访]
      ```

  引入客户_资质评估:
    trigger: "选择客户进行AI评估"
    prompt: |
      你正在对【{customer_name}】进行AI资质评估。
      
      ## 评估维度（系统自动获取）
      1. **注册资本**：查询工商信息
      2. **管理规模**：公开披露数据
      3. **成立年限**：运营稳定性
      4. **投资风格**：公开持仓分析
      5. **合规记录**：监管处罚查询
      6. **关联交易**：关系网络分析
      
      ## 评分标准
      - 90-100分：⭐⭐⭐⭐⭐ 极高价值，优先跟进
      - 80-89分：⭐⭐⭐⭐ 优质客户，重点跟进
      - 70-79分：⭐⭐⭐ 一般客户，正常跟进
      - 60-69分：⭐⭐ 观察客户，低优先级
      - <60分：⭐ 暂不适合，继续观察
      
      ## 输出格式
      ```
      📊 AI资质评估报告
      客户名称：{name}
      评估时间：{time}
      
      🎯 综合评分：{score}分（{评级}）
      
      📋 维度评分：
      • 注册资本：{score}分 - {评价}
      • 管理规模：{score}分 - {评价}
      • 成立年限：{score}分 - {评价}
      • 投资风格：{score}分 - {匹配度}
      • 合规记录：{score}分 - {评价}
      
      💡 AI建议：
      • 优先级：{立即跟进/重点跟进/正常跟进}
      • 预计成交：{time}
      • 推荐经理：{name}（匹配度{score}%）
      • 跟进策略：{strategy}
      ```

  账户开立_高净值开户:
    trigger: "选择高净值客户开户"
    prompt: |
      你正在协助办理【高净值个人客户开户】。
      
      ## 准入标准
      - 资产规模：≥1000万人民币
      - 风险承受：R4（积极型）及以上
      - 投资经验：≥2年证券投资经验
      - 合规要求：无不良诚信记录
      
      ## 信息采集清单
      请引导员工依次收集：
      
      **第一步：基本信息**
      - 客户姓名（与身份证一致）
      - 身份证号码
      - 联系电话
      - 常住地址
      
      **第二步：资产证明**（至少一项）
      - 银行存款证明
      - 证券账户资产截图
      - 其他金融资产证明
      
      **第三步：投资经验**
      - 投资年限
      - 投资品种（股票/基金/债券等）
      - 历史收益情况
      
      **第四步：风险测评**
      - 完成风险承受能力问卷
      - 确认风险等级：R4/R5
      
      ## 开户流程状态
      ① 信息录入 → ② 资料审核 → ③ 风险揭示 → ④ 协议签署 → ⑤ 账户激活
      
      当前进度：{current_step}
      预计完成：{estimated_time}

  交易服务_系统配置:
    trigger: "客户申请算法交易"
    prompt: |
      你正在为客户配置【{algorithm_type}算法交易】。
      
      ## 算法类型说明
      - **TWAP**：时间加权平均价格，适合大额订单平滑执行
      - **VWAP**：成交量加权平均价格，跟随市场成交量分布
      - **POV**：百分比成交量，按市场成交量比例参与
      
      ## 配置参数（需与客户确认）
      1. **时间窗口**：{start_time} - {end_time}
      2. **单笔上限**：{amount}万元（不超过客户限额）
      3. **参与率**：{rate}%（仅POV）
      4. **滑点控制**：≤{bps} bps
      5. **紧急度**：{urgent/normal}
      
      ## 配置前检查
      ✅ 客户交易权限已开通
      ✅ 风险限额已设置
      ✅ 算法服务可用
      ⚠️ 待确认：算法参数需客户最终确认
      
      ## 下一步
      [联系客户确认] [直接提交配置] [修改参数]

  客户服务_舆情监控:
    trigger: "发现客户负面舆情"
    prompt: |
      ⚠️ **舆情预警** - 发现客户相关负面舆情
      
      ## 舆情详情
      📰 **标题**：《{title}》
      📍 **来源**：{source}
      ⏰ **时间**：{publish_time}
      📊 **情感**：{sentiment}（负面）
      📈 **传播**：已监测到{count}家媒体转载
      
      ## 影响评估
      👤 **涉及客户**：{customer_name}
      💰 **持仓规模**：{amount}亿元
      ⚡ **风险等级**：{high/medium/low}
      🔔 **紧急程度**：{urgent/normal}
      
      ## AI建议措施
      1. **立即行动**：主动致电客户说明情况（2小时内）
      2. **材料准备**：准备业绩归因分析报告
      3. **专家介入**：安排投资经理路演沟通
      4. **持续跟踪**：监测舆情发酵情况
      
      ## 快捷操作
      [生成舆情简报] [联系客户] [安排路演] [标记已处理]

context_adaptation:
  - 根据员工角色调整详细程度（经理/普通员工）
  - 根据客户类型调整话术风格（公募/私募/企业）
  - 根据历史交互调整推荐内容
```

---

## 十、客户端入口集成方式

### 10.1 集成架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        客户端集成架构                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                    公司统一门户                           │  │
│   │   ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐   │  │
│   │   │OA系统   │  │CRM系统  │  │交易系统 │  │  ...    │   │  │
│   │   └─────────┘  └─────────┘  └─────────┘  └─────────┘   │  │
│   └─────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │              🦁 机构经纪智能助手入口                      │  │
│   │                   （统一接入点）                          │  │
│   │   • 桌面端：内网门户/企业微信/钉钉                        │  │
│   │   • 移动端：APP内嵌/小程序/H5                            │  │
│   │   • 网页端：独立站点/iframe嵌入                          │  │
│   └─────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                   API网关层                              │  │
│   │   • 统一认证（SSO/OAuth2）                              │  │
│   │   • 权限控制（RBAC）                                    │  │
│   │   • 流量限流                                            │  │
│   │   • 日志审计                                            │  │
│   └─────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                  机构经纪智能体服务                      │  │
│   │              （本地部署/混合云）                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 10.2 入口形式

| 入口类型 | 实现方式 | 适用场景 | 技术方案 |
|---------|---------|---------|---------|
| **内网门户嵌入** | iframe/微前端 | 员工日常办公 | 统一门户集成，单点登录 |
| **企业微信** | 自建应用/小程序 | 移动办公 | 企业微信SDK，消息推送 |
| **钉钉** | 微应用/H5 | 移动办公 | 钉钉开放平台 |
| **独立APP** | 原生/React Native | 高频使用 | 独立部署，深度定制 |
| **Web站点** | 响应式网页 | 临时/外部访问 | HTTPS，VPN接入 |
| **桌面客户端** | Electron/Tauri | 固定工位 | 本地缓存，离线可用 |

### 10.3 统一认证集成

```yaml
# sso_integration.yaml
authentication:
  method: "OAuth2 + JWT"
  
  identity_provider:
    type: "公司统一身份认证"
    endpoint: "https://auth.company.com/oauth2"
    
  flow:
    1_user_access: |
      用户点击"机构经纪智能助手"入口
      
    2_redirect: |
      重定向到公司统一认证页面
      
    3_authentication: |
      用户输入工号/密码（或扫码）
      公司认证中心验证身份
      
    4_token_issue: |
      认证成功后，颁发JWT Token
      Token包含：user_id, role, permissions, department
      
    5_redirect_back: |
      携带Token重定向回智能助手
      
    6_validation: |
      智能助手验证Token有效性
      解析用户权限，加载个性化配置
      
    7_session_start: |
      建立用户会话
      加载历史对话、待办任务
  
  token_config:
    access_token_ttl: "8小时"
    refresh_token_ttl: "7天"
    auto_refresh: true
    
  permission_mapping:
    role_manager: ["all_modules", "team_view", "data_export"]
    role_employee: ["customer_develop", "account_open", "service"]
    role_support: ["service", "view_only"]
```

### 10.4 前端集成代码示例

```javascript
// 内网门户集成示例 - iframe嵌入
class BrokerageAIWidget {
  constructor(config) {
    this.config = {
      apiEndpoint: config.apiEndpoint || '/api/brokerage-ai',
      ssoToken: config.ssoToken,
      containerId: config.containerId,
      theme: config.theme || 'light'
    };
    this.init();
  }
  
  init() {
    // 创建iframe容器
    const container = document.getElementById(this.config.containerId);
    const iframe = document.createElement('iframe');
    
    // 构建URL，传递认证token
    const params = new URLSearchParams({
      token: this.config.ssoToken,
      theme: this.config.theme,
      source: 'portal'
    });
    
    iframe.src = `https://brokerage-ai.company.com/?${params}`;
    iframe.style.width = '100%';
    iframe.style.height = '100%';
    iframe.style.border = 'none';
    
    container.appendChild(iframe);
    
    // 监听消息（双向通信）
    window.addEventListener('message', this.handleMessage.bind(this));
  }
  
  handleMessage(event) {
    // 验证来源
    if (event.origin !== 'https://brokerage-ai.company.com') return;
    
    const { type, data } = event.data;
    
    switch(type) {
      case 'TASK_CREATE':
        // 智能助手创建任务，同步到OA系统
        this.syncToOA(data);
        break;
      case 'NOTIFICATION':
        // 显示桌面通知
        this.showNotification(data);
        break;
      case 'NAVIGATE':
        // 导航到其他系统
        this.navigateTo(data.url);
        break;
    }
  }
  
  syncToOA(taskData) {
    // 调用OA系统API创建任务
    fetch('/api/oa/tasks', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.config.ssoToken}`
      },
      body: JSON.stringify(taskData)
    });
  }
  
  showNotification(data) {
    // 显示系统通知
    if ('Notification' in window) {
      new Notification(data.title, {
        body: data.message,
        icon: '/assets/brokerage-ai-icon.png'
      });
    }
  }
}

// 使用示例
const widget = new BrokerageAIWidget({
  containerId: 'brokerage-ai-container',
  ssoToken: window.SSO_TOKEN,
  theme: 'light'
});
```

```html
<!-- 企业微信/钉钉集成 - H5页面 -->
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>机构经纪智能助手</title>
  <script src="https://res.wx.qq.com/open/js/jweixin-1.6.0.js"></script>
  <script src="https://g.alicdn.com/dingding/open-develop/1.9.0/dingtalk.js"></script>
</head>
<body>
  <div id="app"></div>
  
  <script>
    // 检测运行环境
    const isWechat = /MicroMessenger/.test(navigator.userAgent);
    const isDingtalk = /DingTalk/.test(navigator.userAgent);
    
    // 初始化对应SDK
    if (isWechat) {
      // 企业微信JS-SDK初始化
      wx.config({
        beta: true,
        debug: false,
        appId: '${CORP_ID}',
        timestamp: '${TIMESTAMP}',
        nonceStr: '${NONCESTR}',
        signature: '${SIGNATURE}',
        jsApiList: ['getContext', 'sendChatMessage', 'openDefaultBrowser']
      });
      
      wx.ready(() => {
        // 获取用户信息
        wx.invoke('getContext', {}, (res) => {
          if (res.err_msg === 'getContext:ok') {
            const userId = res.userId;
            // 初始化应用
            initApp({ userId, platform: 'wechat' });
          }
        });
      });
    } else if (isDingtalk) {
      // 钉钉JS-API初始化
      dd.ready(() => {
        dd.runtime.permission.requestAuthCode({
          corpId: '${CORP_ID}'
        }).then((result) => {
          const code = result.code;
          // 通过code获取用户信息
          fetch(`/api/auth/dingtalk?code=${code}`)
            .then(res => res.json())
            .then(userInfo => {
              initApp({ userId: userInfo.userId, platform: 'dingtalk' });
            });
        });
      });
    } else {
      // 普通浏览器
      initApp({ platform: 'web' });
    }
    
    function initApp(context) {
      // 加载React/Vue应用
      // ...
    }
  </script>
</body>
</html>
```

### 10.5 移动端适配

```css
/* 移动端响应式样式 */
@media (max-width: 768px) {
  /* 底部输入栏固定 */
  .input-area {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    padding: 12px 16px 24px;
    background: linear-gradient(180deg, transparent 0%, var(--bg) 30%);
    z-index: 100;
  }
  
  /* 卡片全宽显示 */
  .biz-grid {
    grid-template-columns: 1fr;
  }
  
  /* 简化导航 */
  .nav-header {
    display: none;
  }
  
  /* 增大点击区域 */
  .btn, .chip {
    min-height: 44px;
    padding: 12px 20px;
  }
  
  /* 字体适配 */
  body {
    font-size: 16px; /* 防止iOS缩放 */
  }
}

/* 暗黑模式支持 */
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0a0a0a;
    --surface: #1c1c1e;
    --text: #ffffff;
    --text-secondary: rgba(255,255,255,0.6);
  }
}
```

---

## 十一、部署检查清单

### 11.1 前置条件

- [ ] 公司基础大模型API已开通
- [ ] 网络打通（本地→公司）
- [ ] 统一认证系统对接完成
- [ ] 数据安全评估通过
- [ ] 硬件资源准备就绪

### 11.2 部署步骤

1. **基础环境部署**（Day 1-2）
   - [ ] 服务器初始化
   - [ ] Docker/K8s安装
   - [ ] 数据库部署
   - [ ] 网络配置

2. **应用部署**（Day 3-4）
   - [ ] 智能体服务部署
   - [ ] 前端应用部署
   - [ ] API网关配置
   - [ ] 负载均衡设置

3. **数据初始化**（Day 5）
   - [ ] 知识库导入
   - [ ] 历史数据同步
   - [ ] 语料库对接
   - [ ] 缓存预热

4. **集成测试**（Day 6-7）
   - [ ] 公司模型对接测试
   - [ ] SSO集成测试
   - [ ] 端到端功能测试
   - [ ] 性能压力测试

5. **上线准备**（Day 8）
   - [ ] 监控配置
   - [ ] 日志收集
   - [ ] 备份策略
   - [ ] 应急预案

---

*文档版本：v2.0*  
*最后更新：2026-03-04*  
*基于原型版本：卡片式人机交互界面 + 高净值客户开户*
