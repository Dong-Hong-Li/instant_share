#!/bin/sh
set -e

RES_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources"
mkdir -p "$RES_DIR"

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
