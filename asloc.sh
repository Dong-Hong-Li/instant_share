#!/usr/bin/env bash
# ai_localizations Go 工具一键启动（从 Flutter 项目根目录运行）
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AILOC_PKG_DIR="$PROJECT_ROOT/packages/ai_localizations"
TOOLS_DIR="$AILOC_PKG_DIR/tools"
ROOT_ENV_FILE="$PROJECT_ROOT/.env"
PKG_ENV_FILE="$AILOC_PKG_DIR/.env"
ENV_EXAMPLE="$AILOC_PKG_DIR/.env.example"

if ! command -v go >/dev/null 2>&1; then
  echo "错误: 未找到 go，请先安装 Go SDK" >&2
  exit 1
fi

if [ ! -d "$TOOLS_DIR" ]; then
  echo "错误: 未找到 Go 工具目录 $TOOLS_DIR" >&2
  exit 1
fi

# Go 配置加载器固定读取 ai_localizations 包根目录下的 .env
if [ ! -f "$PKG_ENV_FILE" ]; then
  if [ -f "$ROOT_ENV_FILE" ]; then
    ln -sf "../../.env" "$PKG_ENV_FILE"
  else
    echo "错误: 缺少配置文件 $PKG_ENV_FILE" >&2
    if [ -f "$ENV_EXAMPLE" ]; then
      echo "请执行: cp packages/ai_localizations/.env.example .env" >&2
      echo "并填写 AILOC_API_KEY 等必填项" >&2
    fi
    exit 1
  fi
fi

cd "$TOOLS_DIR"
exec go run ./cmd/
