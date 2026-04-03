# Atlas Fullstack Starter

这个目录本身就是一个脚手架。

它的作用只有一件事：把前端模板和后端模板合并成一个全新的项目仓库，并且不保留模板原始仓库的 `.git` 记录。

## 它会做什么

执行后会自动完成：

1. 前端直接拉取模板
2. 后端通过 `cargo-generate` 生成模板
3. 组装成一个新的项目目录
4. 删除模板里的 `.git`、`node_modules`、`target`、日志等开发残留
5. 在新项目根目录重新执行 `git init`

## 生成结果

默认会生成下面这样的目录：

```text
your-project/
├── frontend/
├── backend/
├── README.md
└── .gitignore
```

## 快速使用

```bash
cd /Users/ancient/src/others/atlas-fullstack-starter
./init.sh my-app
```

默认输出到：

```text
/Users/ancient/src/others/atlas-fullstack-starter/output/my-app
```

如果要指定输出目录：

```bash
./init.sh my-app /path/to/output
```

## 默认模板来源

- 后端模板：`https://github.com/atlas-form/db-center-template.git`
- 前端模板：`https://github.com/atlas-form/react-mono-template.git`

默认分支：

- 后端：`main`
- 前端：`dev`

## 本地开发调试

如果你在本机已经有模板目录，可以直接覆盖来源，不需要真的走 GitHub：

```bash
BACKEND_SOURCE=/Users/ancient/src/rust/db-center-template \
FRONTEND_SOURCE=/Users/ancient/src/frontend/react-mono-template \
./init.sh demo-local
```

后端即使使用本地目录，也仍然会通过 `cargo-generate` 来生成，这样可以保持和后端模板设计一致。

## 让 AI 帮用户执行

用户只需要把类似下面的话发给 AI：

```text
请帮我用 atlas-fullstack-starter 初始化一个前后端项目。

要求：
1. 项目名叫 my-app
2. 不要保留模板原来的 .git 目录
3. 初始化完成后重新创建新的 git 仓库
4. 如果过程中报错，你自己处理
5. 完成后告诉我项目目录和下一步怎么启动
```

## 结果要求

最终新项目必须满足：

1. 根目录是一个新的 Git 仓库
2. `frontend/` 和 `backend/` 内部不能带模板原仓库的 `.git`
3. 用户可以直接在这个新仓库里继续开发和提交代码
