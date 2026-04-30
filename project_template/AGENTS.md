# Fullstack Project Agent Instructions

这是一个由 Atlas Fullstack Starter 生成的前后端一体项目。

根目录 `AGENTS.md` 是 AI 的统一入口。开始回答架构问题、判断文件落点或修改代码前，必须先阅读本文件，再按任务范围继续阅读前端或后端子项目的 `AGENTS.md`。

## 必读入口

1. `README.md`
2. `AI_PROTOCOLS/AI_PROTOCOL.md`
3. `AI_PROTOCOLS/FULLSTACK_WORKFLOW.md`
4. `REQUIREMENTS/`
5. `DEVELOPMENT_DOCS/`
6. `API_DOCS/`

## 子项目入口

按任务范围继续阅读：

- 涉及前端代码、页面、组件、路由、样式或前端构建：先读 `frontend/AGENTS.md`
- 涉及后端代码、数据库、migration、service、repo、API、鉴权或模型调用：先读 `backend/AGENTS.md`
- 涉及前后端联调：同时读 `frontend/AGENTS.md`、`backend/AGENTS.md` 和 `API_DOCS/`

## 全栈流程硬规则

1. 新需求优先从 `REQUIREMENTS/` 读取；如果用户直接在聊天中描述需求，也可以继续推进，但必须先整理需求摘要并确认关键点。
2. 任何依赖新接口或新数据表的需求，都必须先做后端设计。
3. 后端开发前，必须先在 `DEVELOPMENT_DOCS/backend/` 产出后端开发文档。
4. 后端 API 明确后，才能编写 `API_DOCS/` 和 `DEVELOPMENT_DOCS/frontend/`。
5. 用户确认开发文档后，才能进入正式代码实现。
6. 所有 API 文档统一放在根目录 `API_DOCS/`，不允许在 `backend/` 下再维护第二份 API 文档目录。

## API 文档职责

本项目只有一个 API 文档入口：根目录 `API_DOCS/`。

初始化时，后端模板自带的框架 API 文档会被迁移到 `API_DOCS/`，生成后的项目不应再保留 `backend/API_CONTRACTS/`。

API 文档放置规则：

1. 框架已有后端 API：`API_DOCS/`
2. 新业务 API：按需求或模块放在 `API_DOCS/` 下，例如 `API_DOCS/order.md`
3. 前端页面消费说明：可以写在对应 API 文档中，也可以在 `DEVELOPMENT_DOCS/frontend/` 中引用 `API_DOCS/`
4. 修改或新增后端 API 后，必须同步更新根目录 `API_DOCS/`

## 文件落点

- 用户需求：`REQUIREMENTS/`
- 后端设计文档：`DEVELOPMENT_DOCS/backend/`
- 前端设计文档：`DEVELOPMENT_DOCS/frontend/`
- API 文档：`API_DOCS/`
- 前端实现：`frontend/`
- 后端实现：`backend/`

## 注意

不要把 `REQUIREMENTS/` 中的示例文件自动当成真实开发任务。用户可以通过需求文档或聊天消息提供真实需求；如果需求来自聊天，先在回复中整理需求摘要，再进入设计流程。
