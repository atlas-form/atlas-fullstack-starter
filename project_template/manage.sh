#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_DIR="$ROOT_DIR/temp/run"
LOG_DIR="$ROOT_DIR/temp/logs"

mkdir -p "$RUN_DIR" "$LOG_DIR"

usage() {
  cat <<'EOF'
用法：
  ./manage.sh backend start|stop|restart|status
  ./manage.sh frontend <app> start|stop|restart|status

示例：
  ./manage.sh backend start
  ./manage.sh backend stop
  ./manage.sh frontend admin start
  ./manage.sh frontend admin stop

日志：
  temp/logs/backend.log
  temp/logs/frontend-<app>.log
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "错误：缺少命令 '$1'"
    exit 1
  fi
}

is_running() {
  local pid_file="$1"

  if [ ! -f "$pid_file" ]; then
    return 1
  fi

  local pid
  pid="$(cat "$pid_file")"

  if [ -z "$pid" ]; then
    return 1
  fi

  kill -0 "$pid" >/dev/null 2>&1
}

start_process() {
  local name="$1"
  local pid_file="$2"
  local log_file="$3"
  shift 3

  if is_running "$pid_file"; then
    echo "$name 已在运行，PID: $(cat "$pid_file")"
    return 0
  fi

  echo "==> 启动 $name"
  echo "    日志：$log_file"

  nohup "$@" >"$log_file" 2>&1 &
  echo "$!" > "$pid_file"
  sleep 1

  if is_running "$pid_file"; then
    echo "$name 已启动，PID: $(cat "$pid_file")"
  else
    echo "错误：$name 启动失败，请查看日志：$log_file"
    exit 1
  fi
}

stop_process() {
  local name="$1"
  local pid_file="$2"

  if ! is_running "$pid_file"; then
    rm -f "$pid_file"
    echo "$name 未运行"
    return 0
  fi

  local pid
  pid="$(cat "$pid_file")"

  echo "==> 停止 ${name}，PID: $pid"
  kill "$pid" >/dev/null 2>&1 || true

  local i
  for i in 1 2 3 4 5; do
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      rm -f "$pid_file"
      echo "$name 已停止"
      return 0
    fi
    sleep 1
  done

  echo "==> 强制停止 $name"
  kill -9 "$pid" >/dev/null 2>&1 || true
  rm -f "$pid_file"
  echo "$name 已停止"
}

status_process() {
  local name="$1"
  local pid_file="$2"

  if is_running "$pid_file"; then
    echo "$name 运行中，PID: $(cat "$pid_file")"
  else
    rm -f "$pid_file"
    echo "$name 未运行"
  fi
}

print_frontend_url() {
  local app="$1"
  local log_file="$2"
  local url=""
  local i

  for i in 1 2 3 4 5; do
    url="$(grep -E 'Local:' "$log_file" 2>/dev/null | grep -Eo 'https?://(localhost|127\.0\.0\.1|\[::1\])(:[0-9]+)?/?' | head -n 1 || true)"
    if [ -z "$url" ]; then
      url="$(grep -Eo 'https?://(localhost|127\.0\.0\.1|\[::1\])(:[0-9]+)?/?' "$log_file" 2>/dev/null | head -n 1 || true)"
    fi
    if [ -n "$url" ]; then
      echo "访问地址：$url"
      return 0
    fi
    sleep 1
  done

  echo "访问地址：请查看日志中的 Local 地址：$log_file"
  echo "提示：Vite 默认通常是 http://localhost:5173/，如果端口被占用会自动顺延。"
}

backend() {
  local action="${1:-}"
  local pid_file="$RUN_DIR/backend.pid"
  local log_file="$LOG_DIR/backend.log"

  case "$action" in
    start)
      require_command cargo
      start_process "backend" "$pid_file" "$log_file" \
        cargo run --manifest-path "$ROOT_DIR/backend/Cargo.toml" -p web-server
      ;;
    stop)
      stop_process "backend" "$pid_file"
      ;;
    restart)
      stop_process "backend" "$pid_file"
      backend start
      ;;
    status)
      status_process "backend" "$pid_file"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

frontend() {
  local app="${1:-}"
  local action="${2:-}"

  if [ -z "$app" ] || [ -z "$action" ]; then
    usage
    exit 1
  fi

  local app_dir="$ROOT_DIR/frontend/apps/$app"
  if [ ! -d "$app_dir" ]; then
    echo "错误：前端 app 不存在：frontend/apps/$app"
    exit 1
  fi

  local pid_file="$RUN_DIR/frontend-$app.pid"
  local log_file="$LOG_DIR/frontend-$app.log"

  case "$action" in
    start)
      require_command pnpm
      if is_running "$pid_file"; then
        echo "frontend:$app 已在运行，PID: $(cat "$pid_file")"
      else
        start_process "frontend:$app" "$pid_file" "$log_file" \
          pnpm -C "$app_dir" dev
      fi
      print_frontend_url "$app" "$log_file"
      ;;
    stop)
      stop_process "frontend:$app" "$pid_file"
      ;;
    restart)
      stop_process "frontend:$app" "$pid_file"
      frontend "$app" start
      ;;
    status)
      status_process "frontend:$app" "$pid_file"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

case "${1:-}" in
  backend)
    shift
    backend "$@"
    ;;
  frontend)
    shift
    frontend "$@"
    ;;
  ""|help|--help|-h)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
