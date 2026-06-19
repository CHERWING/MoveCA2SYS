#!/system/bin/sh

# 不设 SKIPUNZIP，让管理器自动解压文件
# KernelSU / Magisk 均可正常识别 webroot

API=$(getprop ro.build.version.sdk)

ui_print ""
ui_print "  ╔══════════════════════════════════╗"
ui_print "  ║   MoveCA2SYS  v1.2               ║"
ui_print "  ║   证书迁移管理工具（WebUI）       ║"
ui_print "  ║   PEM → .0 自动转换              ║"
ui_print "  ╚══════════════════════════════════╝"
ui_print ""

ui_print "- 设备: $(getprop ro.product.model)"
ui_print "- AOSP: Android $(getprop ro.build.version.release) (API $API)"

if [ -z "$BOOTMODE" ]; then
  abort "仅支持模块管理器刷入！"
fi

if [ -n "$KSU" ]; then
  ui_print "- Root: KernelSU v$KSU_KERNEL_VER_CODE"
elif [ -n "$APATCH" ]; then
  ui_print "- Root: APatch"
else
  ui_print "- Root: Magisk v$MAGISK_VER_CODE"
fi

ARCH=$(getprop ro.product.cpu.abi)
ui_print "- 架构: $ARCH"

# 权限
ui_print "- 设置权限..."
set_perm_recursive "$MODPATH"          0 0 0755 0644
set_perm_recursive "$MODPATH/system"   0 0 0755 0644
set_perm "$MODPATH/post-fs-data.sh"    0 0 0755
set_perm "$MODPATH/uninstall.sh"       0 0 0755
set_perm_recursive "$MODPATH/common"   0 0 0755 0755
set_perm_recursive "$MODPATH/webroot"  0 0 0755 0644

# 验证 webroot
if [ -f "$MODPATH/webroot/index.html" ]; then
  ui_print "- ✓ WebUI 已就绪"
else
  ui_print "- ⚠ webroot/index.html 未找到"
fi

# 根据架构选择内置 openssl（优先级: 架构专用 > 通用）
ARCH=$(getprop ro.product.cpu.abi 2>/dev/null || echo "")
case "$ARCH" in
  arm64-v8a|arm64|aarch64)  _OPENSSL_ARCH="arm64-v8a"  ;;
  armeabi-v7a|armv7*)       _OPENSSL_ARCH="armeabi-v7a" ;;
  x86_64|amd64)             _OPENSSL_ARCH="x86_64"      ;;
  x86|i686|i386)            _OPENSSL_ARCH="x86"         ;;
  *)                        _OPENSSL_ARCH=""            ;;
esac

if [ -n "$_OPENSSL_ARCH" ] && [ -f "$MODPATH/common/tools/$_OPENSSL_ARCH/openssl" ]; then
  cp "$MODPATH/common/tools/$_OPENSSL_ARCH/openssl" "$MODPATH/common/tools/openssl" 2>/dev/null
  chmod 755 "$MODPATH/common/tools/openssl" 2>/dev/null
  ui_print "- ✓ openssl 已内置 ($_OPENSSL_ARCH)"
else
  ui_print "- ⚠ 内置 openssl 不可用 (架构: $ARCH)"
  ui_print "  可安装 Termux 后: pkg install openssl-tool"
fi

# 创建手动放置目录
ui_print "- 创建 /storage/emulated/0/MoveCA2SYS/ ..."
mkdir -p "/storage/emulated/0/MoveCA2SYS" 2>/dev/null && ui_print "  ✓ 目录已就绪"

# 清理临时文件
rm -rf "$MODPATH/tmp" 2>/dev/null

ui_print ""
ui_print "  ✅ 安装完成！"
ui_print "  打开 Magisk/KernelSU → 模块 → MoveCA2SYS → UI"
ui_print "  也可将证书放入 /storage/emulated/0/MoveCA2SYS/"
ui_print ""
