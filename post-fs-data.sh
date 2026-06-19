#!/system/bin/sh

MODDIR=${0%/*}
API=$(getprop ro.build.version.sdk)

# Android 14+: mount --bind 使系统证书目录可写
if [ "$API" -ge 34 ]; then
  SYS_CERT_DIR="/apex/com.android.conscrypt/cacerts"
  OVERLAY_DIR="$MODDIR/cert-overlay"

  MODULE_CERT_DIR="$MODDIR/system/etc/security/cacerts"

  mkdir -p "$OVERLAY_DIR"

  if ! mount | grep -q "$OVERLAY_DIR on $SYS_CERT_DIR"; then
    # 复制原始系统证书到 overlay
    cp -af "$SYS_CERT_DIR/." "$OVERLAY_DIR/" 2>/dev/null
    # 恢复用户之前迁移的证书（从模块目录复制到 overlay）
    if [ -d "$MODULE_CERT_DIR" ]; then
      for _f in "$MODULE_CERT_DIR"/*; do
        [ -f "$_f" ] && cp -af "$_f" "$OVERLAY_DIR/" 2>/dev/null
      done
    fi
    mount --bind "$OVERLAY_DIR" "$SYS_CERT_DIR" 2>/dev/null
  fi
fi
