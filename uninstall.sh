#!/system/bin/sh

MODDIR=${0%/*}
API=$(getprop ro.build.version.sdk)
LOG_FILE="/cache/moveca2sys.log"
TRACKING_FILE="$MODDIR/certs_installed.txt"

[ "$API" -ge 14 ] && SYS_CERT_DIR="/apex/com.android.conscrypt/cacerts" \
                || SYS_CERT_DIR="/system/etc/security/cacerts"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [卸载] $*" >> "$LOG_FILE"; }

log "开始卸载清理"

if [ -f "$TRACKING_FILE" ]; then
  while IFS= read -r cert_name; do
    [ -z "$cert_name" ] && continue
    cert_path="$SYS_CERT_DIR/$cert_name"
    if [ -f "$cert_path" ]; then
      rm -f "$cert_path" 2>/dev/null
      log "移除 $cert_name"
    fi
  done < "$TRACKING_FILE"
  rm -f "$TRACKING_FILE"
fi

rm -f "$MODDIR/certs_installed.txt" 2>/dev/null

if [ "$API" -ge 14 ]; then
  OVERLAY_DIR="$MODDIR/cert-overlay"
  umount "$SYS_CERT_DIR" 2>/dev/null
  rm -rf "$OVERLAY_DIR" 2>/dev/null
fi

log "卸载清理完毕"
