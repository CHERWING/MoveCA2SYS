#!/system/bin/sh

MODDIR=$(cd "$(dirname "$0")/.." && pwd)
TRACKING_FILE="$MODDIR/certs_installed.txt"
API=$(getprop ro.build.version.sdk)
LOG_FILE="/cache/moveca2sys.log"

# 系统证书路径（可写版本，mount --bind 后）
if [ "$API" -ge 34 ]; then
  SYS_CERT_DIR="/apex/com.android.conscrypt/cacerts"
else
  SYS_CERT_DIR="/system/etc/security/cacerts"
fi
# 模块目录（KernelSU/Magisk magic mount 在重启后生效）
MODULE_CERT_DIR="$MODDIR/system/etc/security/cacerts"

USER_CERT_DIR="/data/misc/user/0/cacerts-added"
MANUAL_DIR="/storage/emulated/0/MoveCA2SYS"

# ---------- 查找 openssl ----------
find_openssl() {
  # 优先: 模块内置（架构专用）
  _arch=$(getprop ro.product.cpu.abi 2>/dev/null || echo "")
  case "$_arch" in
    arm64-v8a|arm64|aarch64)  _arch_dir="arm64-v8a"  ;;
    armeabi-v7a|armv7*)       _arch_dir="armeabi-v7a" ;;
    x86_64|amd64)             _arch_dir="x86_64"      ;;
    x86|i686|i386)            _arch_dir="x86"         ;;
    *)                        _arch_dir=""            ;;
  esac
  [ -n "$_arch_dir" ] && [ -x "$MODDIR/common/tools/$_arch_dir/openssl" ] && { echo "$MODDIR/common/tools/$_arch_dir/openssl"; return 0; }
  [ -x "$MODDIR/common/tools/openssl" ] && { echo "$MODDIR/common/tools/openssl"; return 0; }
  # 系统路径
  for _b in /system/bin/openssl /system/xbin/openssl /data/data/com.termux/files/usr/bin/openssl; do
    [ -x "$_b" ] && { echo "$_b"; return 0; }
  done
  # 其它模块
  for _b in /data/adb/modules/*/system/bin/openssl /data/adb/ksu/modules/*/system/bin/openssl; do
    [ -x "$_b" ] && { echo "$_b"; return 0; }
  done
  # 全盘搜索
  _f=$(find /data /system /apex -name openssl -type f -executable 2>/dev/null | head -1)
  [ -n "$_f" ] && { echo "$_f"; return 0; }
  echo ""
}
OPENSSL=$(find_openssl)

# ---------- 日志 ----------
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# ---------- 计算 hash ----------
compute_hash() {
  _file="$1"
  _ext="${_file##*.}"

  # .0 文件直接用文件名 hash
  if [ "$_ext" = "0" ]; then
    _name=$(basename "$_file")
    echo "${_name%.*}"
    return 0
  fi

  # PEM/CRT/DER 需要 openssl
  if [ -z "$OPENSSL" ]; then
    echo ""
    return 1
  fi

  "$OPENSSL" x509 -in "$_file" -subject_hash -noout 2>/dev/null
  return $?
}

# ---------- 移动单个 ----------
move_one() {
  _filename="$1"
  _src=""

  if [ -f "$USER_CERT_DIR/$_filename" ]; then
    _src="$USER_CERT_DIR/$_filename"
  elif [ -f "$MANUAL_DIR/$_filename" ]; then
    _src="$MANUAL_DIR/$_filename"
  else
    _src=$(find /data/data -maxdepth 6 -name "$_filename" -type f 2>/dev/null | head -1)
  fi

  # 按文件名找不到时，尝试按 hash 匹配 PEM/CRT 文件
  if [ -z "$_src" ] || [ ! -f "$_src" ]; then
    _hash_cand="${_filename%.*}"
    for _try_dir in "$USER_CERT_DIR" "$MANUAL_DIR"; do
      [ -d "$_try_dir" ] || continue
      for _try_f in "$_try_dir"/*; do
        [ -f "$_try_f" ] || continue
        _try_ext="${_try_f##*.}"
        case "$_try_ext" in pem|PEM|crt|CRT|cer|CER|der|DER)
          [ -z "$OPENSSL" ] && continue
          _try_h=$("$OPENSSL" x509 -in "$_try_f" -subject_hash -noout 2>/dev/null)
          [ -n "$_try_h" ] && [ "$_try_h" = "$_hash_cand" ] && { _src="$_try_f"; break 2; }
        esac
      done
    done
  fi

  if [ -z "$_src" ] || [ ! -f "$_src" ]; then
    echo "{\"ok\":false,\"name\":\"$_filename\",\"error\":\"源文件不存在\"}"
    log "失败: $_filename - 源文件不存在"
    return 1
  fi

  _hash=$(compute_hash "$_src")

  if [ -z "$_hash" ]; then
    echo "{\"ok\":false,\"name\":\"$_filename\",\"error\":\"无法计算 subject_hash\"}"
    log "失败: $_filename - 无法计算 hash"
    return 1
  fi

  _dst_name="${_hash}.0"
  _dst="$SYS_CERT_DIR/$_dst_name"
  _mod_dst="$MODULE_CERT_DIR/$_dst_name"

  if [ -f "$_dst" ]; then
    # 同时确保模块目录也有
    if [ ! -f "$_mod_dst" ]; then
      mkdir -p "$MODULE_CERT_DIR" 2>/dev/null
      cp -f "$_src" "$_mod_dst" 2>/dev/null
      chmod 644 "$_mod_dst" 2>/dev/null
    fi
    if ! grep -qxF "$_dst_name" "$TRACKING_FILE" 2>/dev/null; then
      echo "$_dst_name" >> "$TRACKING_FILE"
    fi
    echo "{\"ok\":true,\"name\":\"$_filename\",\"action\":\"skip\",\"dst\":\"$_dst\",\"hash\":\"$_hash\"}"
    log "跳过(已存在): $_filename -> $_dst_name"
    return 0
  fi

  # 复制到系统路径（当前会话立即生效）
  cp -f "$_src" "$_dst" 2>/dev/null
  _cp_ok=$?
  if [ $_cp_ok -ne 0 ]; then
    echo "{\"ok\":false,\"name\":\"$_filename\",\"error\":\"复制到系统路径失败\"}"
    log "失败: $_filename - 复制到 $_dst 失败"
    return 1
  fi

  chmod 644 "$_dst" 2>/dev/null
  chcon u:object_r:system_file:s0 "$_dst" 2>/dev/null

  # 复制到模块目录（重启后仍保留）
  mkdir -p "$MODULE_CERT_DIR" 2>/dev/null
  cp -f "$_src" "$_mod_dst" 2>/dev/null
  chmod 644 "$_mod_dst" 2>/dev/null

  echo "$_dst_name" >> "$TRACKING_FILE"
  log "已移动: $_filename ($_src -> $_dst + $_mod_dst) hash=$_hash"

  echo "{\"ok\":true,\"name\":\"$_filename\",\"action\":\"moved\",\"dst\":\"$_dst\",\"hash\":\"$_hash\"}"
}

# ---------- 主逻辑 ----------
echo "{\"openssl\":\"${OPENSSL:-unavailable}\",\"results\":["

if [ "$1" = "--all" ]; then
  _first=true

  # 用户证书目录
  for _cert in "$USER_CERT_DIR"/*; do
    [ -f "$_cert" ] || continue
    _name=$(basename "$_cert")
    grep -qxF "$_name" "$TRACKING_FILE" 2>/dev/null && continue
    if [ -f "$SYS_CERT_DIR/$_name" ]; then
      echo "$_name" >> "$TRACKING_FILE"
      continue
    fi
    $_first || echo ","; _first=false
    move_one "$_name"
  done

  # 手动放置目录
  if [ -d "$MANUAL_DIR" ]; then
    for _cert in "$MANUAL_DIR"/*; do
      [ -f "$_cert" ] || continue
      _name=$(basename "$_cert")
      grep -qxF "$_name" "$TRACKING_FILE" 2>/dev/null && continue
      _h=$(compute_hash "$_cert")
      if [ -n "$_h" ]; then
        _dn="${_h}.0"
        grep -qxF "$_dn" "$TRACKING_FILE" 2>/dev/null && continue
        [ -f "$SYS_CERT_DIR/$_dn" ] && { echo "$_dn" >> "$TRACKING_FILE"; continue; }
      fi
      $_first || echo ","; _first=false
      move_one "$_name"
    done
  fi

  # App 目录
  for _dir in /storage/emulated/0/HttpCanary/certs \
             /data/data/com.guoshi.httpcanary/cache \
             /data/data/com.guoshi.httpcanary/files \
             /data/data/com.lixiqing.proxypin/certs \
             /data/data/com.lixiqing.proxypin/files/certs \
             /data/data/app.greyshirts.pcap/app_certs \
             /data/data/app.greyshirts.ssc/app_certs \
             /data/data/com.telerik.fiddler/files \
             /data/data/com.xk72.charles/files; do
    [ -d "$_dir" ] || continue
    for _cert in "$_dir"/*; do
      [ -f "$_cert" ] || continue
      _name=$(basename "$_cert")
      _h=$(compute_hash "$_cert")
      if [ -n "$_h" ]; then
        _dn="${_h}.0"
        grep -qxF "$_dn" "$TRACKING_FILE" 2>/dev/null && continue
        [ -f "$SYS_CERT_DIR/$_dn" ] && { echo "$_dn" >> "$TRACKING_FILE"; continue; }
      fi
      grep -qxF "$_name" "$TRACKING_FILE" 2>/dev/null && continue
      $_first || echo ","; _first=false
      move_one "$_name"
    done
  done

elif [ $# -gt 0 ]; then
  _first=true
  for _arg in "$@"; do
    [ -z "$_arg" ] && continue
    $_first || echo ","; _first=false
    move_one "$_arg"
  done
fi

echo "]}"
