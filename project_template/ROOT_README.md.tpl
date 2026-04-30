# __PROJECT_NAME__

这是一个由 Atlas Fullstack Starter 生成的前后端一体项目。

## 目录结构

- `user_docs/`：给普通用户阅读的使用说明
- `REQUIREMENTS/`：用户放需求文档
- `DEVELOPMENT_DOCS/backend/`：AI 编写后端开发文档
- `DEVELOPMENT_DOCS/frontend/`：AI 在后端 API 确认后编写前端开发文档
- `API_DOCS/`：项目唯一 API 文档入口
- `frontend/`：前端项目
- `backend/`：后端项目
- `AGENTS.md`：AI 统一入口，负责指向前端和后端子项目规则

## 推荐使用方式

1. 先让 AI 从根目录 `AGENTS.md` 开始读取规则
2. 再让 AI 检查本机环境是否能启动前端和后端
3. 可以把业务需求文档放进 `REQUIREMENTS/`，也可以直接在聊天里描述需求
4. 让 AI 先整理需求摘要，再生成 `DEVELOPMENT_DOCS/backend/` 下的后端开发文档和数据库表结构
5. 用户确认后端设计
6. 让 AI 再生成 `API_DOCS/` 和 `DEVELOPMENT_DOCS/frontend/`
7. 用户确认后，再开始正式开发
8. 如果后端接口有新增或修改，让 AI 同步更新根目录 `API_DOCS/`

## 启动前建议

1. 阅读根目录 `AGENTS.md`
2. 阅读根目录 `user_docs/`
3. 如需开新对话，可以参考根目录 `USER_START.md` 里的提示词
4. 阅读根目录 `AI_PROTOCOLS/`
5. 阅读 `REQUIREMENTS/`、`DEVELOPMENT_DOCS/`、`API_DOCS/` 下的模板文件
6. 阅读 `backend/user_docs/` 和 `backend/AI_PROTOCOLS/`
7. 前端实现阶段再阅读 `frontend/` 内文档
8. 让 AI 自己处理缺少依赖、环境报错、数据库配置等问题
