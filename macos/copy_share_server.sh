#!/bin/sh
set -e

RES_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources"
mkdir -p "$RES_DIR"

# 1) 独立二进制（子进程模式，历史方案）
BIN_SRC="${PROJECT_DIR}/../assets/bin/instant-share-server"
BIN_DST="${RES_DIR}/instant-share-server"
if [ -f "$BIN_SRC" ]; then
  cp -f "$BIN_SRC" "$BIN_DST"
  chmod +x "$BIN_DST"
  if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$BIN_DST" || true
  fi
  echo "Copied share server binary -> ${BIN_DST}"
else
  echo "warning: ${BIN_SRC} not found, skip copy share server binary"
fi

# 2) c-shared 动态库（进程内模式，dart:ffi 加载）
LIB_SRC="${PROJECT_DIR}/../assets/lib/libinstantshare.dylib"
LIB_DST="${RES_DIR}/libinstantshare.dylib"
if [ -f "$LIB_SRC" ]; then
  cp -f "$LIB_SRC" "$LIB_DST"
  if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$LIB_DST" || true
  fi
  echo "Copied share server dylib -> ${LIB_DST}"
else
  echo "warning: ${LIB_SRC} not found, run instant_share_server/build_lib.sh macos"
fi
