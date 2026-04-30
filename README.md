# Atlas Fullstack Starter

这是一个给普通用户使用的前后端一体项目脚手架。

它的作用很简单：

帮你快速创建一个新的项目，并把前端、后端和后续和 AI 协作需要用到的文档目录一起准备好。

## 使用方式

先进入一个你准备存放项目的目录。

这个脚手架只推荐用户使用远程执行方式，不介绍本地执行方式。

按你的系统选择下面这一条命令直接执行。

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/atlas-form/atlas-fullstack-starter/main/init.sh | bash -s -- my-app
```

### Windows PowerShell

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/atlas-form/atlas-fullstack-starter/main/init.ps1))) -ProjectName my-app
```

执行完成后，会生成：

```text
./my-app
```

## 初始化后先看哪里

生成完成后，先看新项目根目录里的这些内容：

1. `README.md`
2. `AGENTS.md`
3. `temp/REQUIREMENTS/`

## 给用户的原则

1. 先让 AI 检查环境
2. 再通过 `temp/REQUIREMENTS/` 或聊天描述业务需求
3. 先确认开发文档，再让 AI 正式开发
