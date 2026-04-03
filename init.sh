#!/usr/bin/env bash
set -euo pipefail

DEFAULT_OUTPUT_DIR="$(pwd)"

BACKEND_SOURCE_DEFAULT="https://github.com/atlas-form/db-center-template.git"
BACKEND_REF_DEFAULT="main"
FRONTEND_SOURCE_DEFAULT="https://github.com/atlas-form/react-mono-template.git"
FRONTEND_REF_DEFAULT="main"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "错误：缺少命令 '$1'"
    exit 1
  fi
}

usage() {
  cat <<'EOF'
用法：
  ./init.sh <project-name> [output-dir]

示例：
  ./init.sh my-app
  ./init.sh my-app /Users/ancient/workspace

远程执行示例：
  curl -fsSL https://raw.githubusercontent.com/atlas-form/atlas-fullstack-starter/main/init.sh | bash -s -- my-app
  curl -fsSL https://raw.githubusercontent.com/atlas-form/atlas-fullstack-starter/main/init.sh | bash -s -- my-app /Users/ancient/src

可选环境变量：
  BACKEND_SOURCE   后端模板来源，可以是 git 地址或本地目录
  BACKEND_REF      后端分支、标签或提交，仅对 git 地址有效
  FRONTEND_SOURCE  前端模板来源，可以是 git 地址或本地目录
  FRONTEND_REF     前端分支、标签或提交，仅对 git 地址有效
EOF
}

is_git_url() {
  case "$1" in
    http://*|https://*|git@*|ssh://*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

copy_local_dir() {
  local source_dir="$1"
  local target_dir="$2"

  if [ ! -d "$source_dir" ]; then
    echo "错误：本地模板目录不存在：$source_dir"
    exit 1
  fi

  mkdir -p "$target_dir"
  (
    cd "$source_dir" && tar \
      --exclude='.git' \
      --exclude='node_modules' \
      --exclude='target' \
      --exclude='dist' \
      --exclude='.turbo' \
      --exclude='logs' \
      --exclude='tmp' \
      --exclude='.DS_Store' \
      -cf - .
  ) | (
    cd "$target_dir" && tar -xf -
  )
}

copy_git_repo() {
  local repo_url="$1"
  local repo_ref="$2"
  local tmp_dir="$3"
  local target_dir="$4"

  git clone --depth 1 --branch "$repo_ref" "$repo_url" "$tmp_dir" >/dev/null
  mkdir -p "$target_dir"
  (cd "$tmp_dir" && tar --exclude='.git' -cf - .) | (cd "$target_dir" && tar -xf -)
}

generate_backend_with_cargo_generate() {
  local source="$1"
  local ref="$2"
  local destination_dir="$3"

  require_command cargo-generate

  mkdir -p "$(dirname "$destination_dir")"

  if is_git_url "$source"; then
    cargo generate \
      --git "$source" \
      --branch "$ref" \
      --destination "$(dirname "$destination_dir")" \
      --name "$(basename "$destination_dir")" \
      --silent \
      --vcs none
  else
    cargo generate \
      --path "$source" \
      --destination "$(dirname "$destination_dir")" \
      --name "$(basename "$destination_dir")" \
      --silent \
      --vcs none
  fi
}

copy_frontend_template() {
  local source="$1"
  local ref="$2"
  local tmp_dir="$3"
  local target_dir="$4"

  echo "==> 准备前端模板"
  echo "    来源：$source"

  if is_git_url "$source"; then
    echo "    版本：$ref"
    copy_git_repo "$source" "$ref" "$tmp_dir" "$target_dir"
  else
    copy_local_dir "$source" "$target_dir"
  fi
}

clean_generated_files() {
  local project_dir="$1"

  find "$project_dir" -name .git -type d -prune -exec rm -rf {} +
  find "$project_dir" -name node_modules -type d -prune -exec rm -rf {} +
  find "$project_dir" -name target -type d -prune -exec rm -rf {} +
  find "$project_dir" -name logs -type d -prune -exec rm -rf {} +
  find "$project_dir" -name dist -type d -prune -exec rm -rf {} +
  find "$project_dir" -name .turbo -type d -prune -exec rm -rf {} +
  find "$project_dir" -name tmp -type d -prune -exec rm -rf {} +
  find "$project_dir" -name .DS_Store -type f -delete
}

write_root_readme() {
  local project_dir="$1"
  local project_name="$2"

  cat > "$project_dir/README.md" <<EOF
# $project_name

这是一个由 Atlas Fullstack Starter 生成的前后端一体项目。

## 目录结构

- \`frontend/\`：前端项目
- \`backend/\`：后端项目

## 推荐使用方式

1. 先让 AI 检查本机环境是否能启动前端和后端
2. 让用户先描述业务需求
3. 让 AI 先生成服务端开发文档和数据库表结构
4. 用户确认设计后，再开始正式开发

## 启动前建议

1. 阅读 \`frontend/README.md\`
2. 阅读 \`backend/README.md\`
3. 阅读 \`backend/user_docs/\` 和 \`backend/ai_protocols/\`
4. 让 AI 自己处理缺少依赖、环境报错、数据库配置等问题
EOF
}

write_root_gitignore() {
  local project_dir="$1"

  cat > "$project_dir/.gitignore" <<'EOF'
.DS_Store
.idea/
.vscode/
.claude/
.serena/

# frontend
frontend/node_modules/
frontend/dist/
frontend/.turbo/
frontend/.env
frontend/.env.local
frontend/.env.development.local
frontend/.env.test.local
frontend/.env.production.local

# backend
backend/target/
backend/logs/
backend/tmp/
backend/.env
backend/sh_test/

# misc
output/
tmp/
EOF
}

PROJECT_NAME="${1:-}"
OUTPUT_DIR="${2:-$DEFAULT_OUTPUT_DIR}"

if [ -z "$PROJECT_NAME" ]; then
  usage
  exit 1
fi

if [[ ! "$PROJECT_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "错误：项目名 '$PROJECT_NAME' 非法。只允许字母、数字、点、下划线和中划线。"
  exit 1
fi

require_command git
require_command tar

BACKEND_SOURCE="${BACKEND_SOURCE:-$BACKEND_SOURCE_DEFAULT}"
BACKEND_REF="${BACKEND_REF:-$BACKEND_REF_DEFAULT}"
FRONTEND_SOURCE="${FRONTEND_SOURCE:-$FRONTEND_SOURCE_DEFAULT}"
FRONTEND_REF="${FRONTEND_REF:-$FRONTEND_REF_DEFAULT}"

TARGET_DIR="$OUTPUT_DIR/$PROJECT_NAME"
BACKEND_DIR="$TARGET_DIR/backend"
FRONTEND_DIR="$TARGET_DIR/frontend"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/atlas-fullstack-starter.XXXXXX")"
TMP_BACKEND_DIR="$TMP_DIR/backend"
TMP_FRONTEND_DIR="$TMP_DIR/frontend"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ -e "$TARGET_DIR" ]; then
  echo "错误：目标目录已存在：$TARGET_DIR"
  exit 1
fi

mkdir -p "$OUTPUT_DIR" "$TARGET_DIR"

echo "==> 生成后端模板"
echo "    来源：$BACKEND_SOURCE"
if is_git_url "$BACKEND_SOURCE"; then
  echo "    版本：$BACKEND_REF"
fi
generate_backend_with_cargo_generate "$BACKEND_SOURCE" "$BACKEND_REF" "$BACKEND_DIR"

copy_frontend_template "$FRONTEND_SOURCE" "$FRONTEND_REF" "$TMP_FRONTEND_DIR" "$FRONTEND_DIR"

echo "==> 清理模板残留文件"
clean_generated_files "$TARGET_DIR"

echo "==> 生成根目录 README 和 .gitignore"
write_root_readme "$TARGET_DIR" "$PROJECT_NAME"
write_root_gitignore "$TARGET_DIR"

echo "==> 初始化新的 git 仓库"
git -C "$TARGET_DIR" init -b main >/dev/null 2>&1 || {
  git -C "$TARGET_DIR" init >/dev/null
  git -C "$TARGET_DIR" branch -M main >/dev/null 2>&1 || true
}

echo
echo "初始化完成：$TARGET_DIR"
echo "当前项目已经是一个全新的 git 仓库"
echo "模板仓库原本的 .git 目录不会保留到用户项目中"
echo
echo "目录结构："
echo "  $TARGET_DIR/"
echo "  ├── frontend/"
echo "  ├── backend/"
echo "  ├── README.md"
echo "  └── .gitignore"
