#!/system/bin/sh
# MoveCA2SYS - openssl 查找脚本
# openssl 已内置在模块中 (common/tools/<arch>/openssl)
# 本脚本仅验证可用性，无需下载

MODDIR=$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)
TOOLS_DIR="$MODDIR/tools"
ARCH=$(getprop ro.product.cpu.abi 2>/dev/null || uname -m 2>/dev/null)

echo "arch:$ARCH"

# 确定架构目录
case "$ARCH" in
  arm64-v8a|arm64|aarch64) _ARCH_DIR="arm64-v8a" ;;
  armeabi-v7a|armv7*)      _ARCH_DIR="armeabi-v7a" ;;
  x86_64|amd64)            _ARCH_DIR="x86_64" ;;
  x86|i686|i386)           _ARCH_DIR="x86" ;;
  *)                       _ARCH_DIR="" ;;
esac

# 查找可用 openssl
_FOUND=""
for _p in "$TOOLS_DIR/$_ARCH_DIR/openssl" "$TOOLS_DIR/openssl" \
  /system/bin/openssl /system/xbin/openssl \
  /data/data/com.termux/files/usr/bin/openssl; do
  [ -x "$_p" ] || continue
  _VER=$("$_p" version 2>/dev/null)
  [ -n "$_VER" ] || continue
  _FOUND="$_p"
  break
done

if [ -n "$_FOUND" ]; then
  # 确保 tools/openssl 存在
  if [ "$_FOUND" != "$TOOLS_DIR/openssl" ] && [ "$_FOUND" != "$TOOLS_DIR/$_ARCH_DIR/openssl" ]; then
    mkdir -p "$TOOLS_DIR" 2>/dev/null
    cp "$_FOUND" "$TOOLS_DIR/openssl" 2>/dev/null
    chmod 755 "$TOOLS_DIR/openssl" 2>/dev/null
  fi
  _VER=$("$TOOLS_DIR/openssl" version 2>/dev/null || "$_FOUND" version 2>/dev/null)
  echo "found:$_FOUND"
  echo "usable"
  echo "$_VER"
  exit 0
fi

echo "not_found"
echo ""
echo "openssl 未找到。请安装 Termux 后运行:"
echo "  pkg update && pkg install openssl-tool"
echo "然后重新运行本脚本"
exit 1
