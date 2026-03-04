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

### 3.1 调用内容清单

| 调用方向 | 调用内容 | 数据类型 | 频率 | 说明 |
|---------|---------|---------|------|------|
| **本地 → 公司** | 客户身份验证 | 身份ID | 每次会话 | 统一身份打通 |
| **本地 → 公司** | 客户画像查询 | 客户ID | 实时 | 获取关系网络数据 |
| **本地 → 公司** | 历史交易记录 | 账户ID | 按需 | 风控/服务参考 |
| **本地 → 公司** | 舆情/监管数据 | 客户名称 | 定时同步 | 客户服务用 |
| **公司 → 本地** | 任务派发 | 任务JSON | 实时 | 公司级调度 |
| **公司 → 本地** | 考核指标 | KPI数据 | 日/周 | AI驱动考核 |
| **公司 → 本地** | 知识更新 | 知识条目 | 定时 | 知识库同步 |

### 3.2 API接口标准

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

*文档版本：v1.0*  
*最后更新：2026-03-04*  
*基于原型版本：卡片式人机交互界面*
