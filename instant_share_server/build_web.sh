#!/bin/sh
# 构建接收者 Web 前端，产物输出到 internal/web/dist（供 Go embed 使用）。
set -e

cd "$(dirname "$0")/web"

if ! command -v npm >/dev/null 2>&1; then
  echo "[build_web] 未找到 npm，请先安装 Node.js" >&2
  exit 1
fi

if [ ! -d node_modules ]; then
  echo "[build_web] npm install ..."
  npm install
fi

echo "[build_web] npm run build ..."
npm run build

echo "[build_web] done -> internal/web/dist"
