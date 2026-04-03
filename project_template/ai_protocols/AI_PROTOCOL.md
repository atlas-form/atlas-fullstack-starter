# Fullstack AI Protocol

这个协议给 AI 使用。

## 根原则

这个项目的任何业务设计，必须先从服务端开始。

不允许出现下面这种顺序：

1. 先写前端页面
2. 再倒推后端接口
3. 最后再补数据库设计

允许的顺序只能是：

1. 用户提供需求
2. AI 读取 `requirements/`
3. AI 先写后端开发文档
4. AI 先设计数据库表结构和后端接口
5. 用户确认
6. AI 产出前端开发文档和接口文档
7. 用户确认
8. AI 开始正式开发

## 目录职责

- `requirements/`：用户放需求文档
- `development_docs/backend/`：AI 写后端开发文档
- `development_docs/frontend/`：AI 在后端 API 明确后写前端开发文档
- `api_docs/`：AI 写前后端通信接口文档
- `frontend/`：前端项目
- `backend/`：后端项目

## 强制规则

1. 任何新需求，都先检查 `requirements/` 是否已有对应文档
2. 任何后端开发开始前，都必须先在 `development_docs/backend/` 产出文档
3. 后端开发文档里必须包含数据库表结构、字段说明、接口说明、鉴权说明
4. 用户未确认后端文档前，不允许进入正式开发
5. 只有在后端 API 明确后，才允许写 `development_docs/frontend/`
6. `api_docs/` 必须在后端 API 设计确定后生成，并作为前后端联调依据
7. 如果用户只说“做一个页面”，但该页面依赖新接口，仍然必须先回到服务端设计流程

## 阅读顺序

1. 根目录 `README.md`
2. 根目录 `AI_START.md`
3. 根目录 `ai_protocols/`
4. 根目录 `requirements/`
5. 如果涉及后端实现，再读 `backend/ai_protocols/` 和 `backend/user_docs/`
6. 如果涉及前端实现，再读 `frontend/` 内文档和代码结构
