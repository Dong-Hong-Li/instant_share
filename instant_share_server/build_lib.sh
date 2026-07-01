#!/bin/sh
# 构建进程内动态库（c-shared），供 Flutter 通过 dart:ffi 调用。
#
# 用法：
#   ./build_lib.sh            # 自动检测当前系统 (macOS / Linux)
#   ./build_lib.sh macos      # macOS 通用库 (arm64 + x86_64)
#   ./build_lib.sh windows    # Windows amd64 DLL（macOS/Linux 需 mingw-w64 交叉编译）
#   ./build_lib.sh linux      # Linux amd64 .so
#   ./build_lib.sh android    # Android arm64-v8a / armeabi-v7a / x86_64 .so
#
# 产物默认输出到 ../assets/lib/ 或 ../android/app/src/main/jniLibs/<abi>/。
set -e

cd "$(dirname "$0")"

_resolve_ndk_root() {
  if [ -n "${ANDROID_NDK_HOME:-}" ] && [ -d "$ANDROID_NDK_HOME" ]; then
    echo "$ANDROID_NDK_HOME"
    return 0
  fi

  ndk_base=""
  if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME/ndk" ]; then
    ndk_base="$ANDROID_HOME/ndk"
  elif [ -d "$HOME/Library/Android/sdk/ndk" ]; then
    ndk_base="$HOME/Library/Android/sdk/ndk"
  else
    return 1
  fi

  latest="$(ls -1 "$ndk_base" | sort -V | tail -1)"
  if [ -z "$latest" ]; then
    return 1
  fi
  echo "$ndk_base/$latest"
}

_build_android_abi() {
  abi="$1"
  goarch="$2"
  clang="$3"
  out_dir="$4"

  mkdir -p "$out_dir"
  OUT="$out_dir/libinstantshare.so"

  echo "[build_lib] Android $abi ..."
  CGO_ENABLED=1 GOOS=android GOARCH="$goarch" CC="$clang" \
    go build -buildmode=c-shared -o "$OUT" "$PKG"
  rm -f "$out_dir/libinstantshare.h"
}

echo "[build_lib] building web frontend ..."
./build_web.sh

if [ -n "${1:-}" ]; then
  PLATFORM="$1"
else
  case "$(uname -s)" in
    Darwin) PLATFORM="macos" ;;
    Linux) PLATFORM="linux" ;;
    MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
    *) PLATFORM="macos" ;;
  esac
fi

PKG="./cmd/lib"

case "$PLATFORM" in
  macos)
    OUT_DIR="../assets/lib"
    OUT="$OUT_DIR/libinstantshare.dylib"
    mkdir -p "$OUT_DIR"
    TMP="$(mktemp -d)"

    echo "[build_lib] macOS arm64 ..."
    CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 \
      go build -buildmode=c-shared -o "$TMP/arm64.dylib" "$PKG"

    echo "[build_lib] macOS amd64 ..."
    CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 \
      go build -buildmode=c-shared -o "$TMP/amd64.dylib" "$PKG"

    echo "[build_lib] lipo -> universal ..."
    lipo -create -output "$OUT" "$TMP/arm64.dylib" "$TMP/amd64.dylib"

    # ad-hoc 签名，便于本地 Debug 运行（沙盒/Gatekeeper）。
    if command -v codesign >/dev/null 2>&1; then
      codesign --force --sign - "$OUT" || true
    fi

    rm -rf "$TMP"
    echo "[build_lib] done -> $OUT"
    lipo -info "$OUT"
    ;;

  windows)
    OUT_DIR="../assets/lib"
    OUT="$OUT_DIR/instantshare.dll"
    mkdir -p "$OUT_DIR"

    if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
      MINGW_CC="x86_64-w64-mingw32-gcc"
    elif command -v x86_64-w64-mingw32-gcc-14 >/dev/null 2>&1; then
      MINGW_CC="x86_64-w64-mingw32-gcc-14"
    else
      UNAME_S=$(uname -s)
      case "$UNAME_S" in
        MINGW*|MSYS*|CYGWIN*) MINGW_CC="gcc" ;;
        *)
          echo "[build_lib] 未找到 mingw 交叉编译器。" >&2
          echo "  macOS: brew install mingw-w64" >&2
          echo "  或在 Windows 上执行: build_lib.bat" >&2
          exit 1
          ;;
      esac
    fi

    echo "[build_lib] Windows amd64 ($MINGW_CC) ..."
    CGO_ENABLED=1 CC="$MINGW_CC" GOOS=windows GOARCH=amd64 \
      go build -buildmode=c-shared -o "$OUT" "$PKG"

    rm -f "$OUT_DIR/instantshare.h"
    echo "[build_lib] done -> $OUT"
    ;;

  linux)
    OUT_DIR="../assets/lib"
    OUT="$OUT_DIR/libinstantshare.so"
    mkdir -p "$OUT_DIR"

    echo "[build_lib] Linux amd64 ..."
    CGO_ENABLED=1 GOOS=linux GOARCH=amd64 \
      go build -buildmode=c-shared -o "$OUT" "$PKG"

    rm -f "$OUT_DIR/libinstantshare.h"
    echo "[build_lib] done -> $OUT"
    ;;

  android)
    NDK="$(_resolve_ndk_root)" || {
      echo "[build_lib] 未找到 Android NDK。" >&2
      echo "  设置 ANDROID_NDK_HOME 或安装 Android Studio NDK" >&2
      exit 1
    }

    MIN_SDK="${ANDROID_MIN_SDK:-21}"
    case "$(uname -s)" in
      Darwin) PREBUILT="darwin-x86_64" ;;
      Linux) PREBUILT="linux-x86_64" ;;
      MINGW*|MSYS*|CYGWIN*) PREBUILT="windows-x86_64" ;;
      *) PREBUILT="linux-x86_64" ;;
    esac

    BIN="$NDK/toolchains/llvm/prebuilt/$PREBUILT/bin"
    JNI_BASE="../android/app/src/main/jniLibs"

    _build_android_abi arm64-v8a arm64 \
      "$BIN/aarch64-linux-android${MIN_SDK}-clang" "$JNI_BASE/arm64-v8a"
    _build_android_abi armeabi-v7a arm \
      "$BIN/armv7a-linux-androideabi${MIN_SDK}-clang" "$JNI_BASE/armeabi-v7a"
    _build_android_abi x86_64 amd64 \
      "$BIN/x86_64-linux-android${MIN_SDK}-clang" "$JNI_BASE/x86_64"

    echo "[build_lib] done -> $JNI_BASE/{arm64-v8a,armeabi-v7a,x86_64}/libinstantshare.so"
    ;;

  #
  # TODO(ios): 改用 c-archive 生成 .a 静态库并链接进 Runner：
  #   CGO_ENABLED=1 GOOS=ios GOARCH=arm64 \
  #     go build -buildmode=c-archive -o libinstantshare.a ./cmd/lib

  *)
    echo "暂未实现平台: $PLATFORM（见脚本内 TODO）" >&2
    exit 1
    ;;
esac
