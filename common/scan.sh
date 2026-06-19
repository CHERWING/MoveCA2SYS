#!/system/bin/sh
# 扫描证书输出 JSON — 一次性 printf 避免输出截断

MODDIR=$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)

MANUAL_DIR="/storage/emulated/0/MoveCA2SYS"
HC_CERTS="/storage/emulated/0/HttpCanary/certs"
USER_CERT_DIR="/data/misc/user/0/cacerts-added"
SYS_CERT_DIR="/system/etc/security/cacerts"
APEX_CERT_DIR="/apex/com.android.conscrypt/cacerts"

API=$(getprop ro.build.version.sdk)

# openssl — 广泛搜索（内置 > 设备已有）
OPENSSL=""
_search_openssl() {
  # 优先: 模块内置（架构专用）
  _arch=$(getprop ro.product.cpu.abi 2>/dev/null || echo "")
  case "$_arch" in
    arm64-v8a|arm64|aarch64)  _arch_dir="arm64-v8a"  ;;
    armeabi-v7a|armv7*)       _arch_dir="armeabi-v7a" ;;
    x86_64|amd64)             _arch_dir="x86_64"      ;;
    x86|i686|i386)            _arch_dir="x86"         ;;
    *)                        _arch_dir=""            ;;
  esac
  [ -n "$_arch_dir" ] && [ -x "$MODDIR/common/tools/$_arch_dir/openssl" ] && { echo "$MODDIR/common/tools/$_arch_dir/openssl"; return; }
  # 通用 fallback
  [ -x "$MODDIR/common/tools/openssl" ] && { echo "$MODDIR/common/tools/openssl"; return; }
  # 系统路径
  for _p in /system/bin/openssl /system/xbin/openssl \
    /data/data/com.termux/files/usr/bin/openssl; do
    [ -x "$_p" ] && { echo "$_p"; return; }
  done
  # 其他模块
  for _p in /data/adb/modules/*/system/bin/openssl /data/adb/ksu/modules/*/system/bin/openssl; do
    [ -x "$_p" ] && { echo "$_p"; return; }
  done
  # 全盘搜索
  find /data /system /apex -name openssl -type f -executable 2>/dev/null | head -1
}
OPENSSL=$(_search_openssl)

# Android 证书文件必须是 OpenSSL subject_hash 格式，文件名必须是 <hash>.0。
# 设备无 openssl 时不能可靠计算 PEM/CRT 的真实 hash，因此这类文件只用于提示，不能迁移。

# 工具函数
_get_key() { echo "$1" | tr '/. _' '____'; }

_dir_info() {
  _d="$1"
  _exists=0; _files=0
  [ -d "$_d" ] && { _exists=1; _files=$(ls "$_d" 2>/dev/null | wc -l); }
  _key=$(_get_key "$_d")
  _PUT "\"dir_$_key\":{\"path\":\"$_d\",\"exists\":$_exists,\"files\":$_files}"
}

_cert_hash() {
  _f="$1" _n="$2" _e="${_n##*.}"
  case "$_e" in
    0) _h="${_n%.*}" ;;
    crt|cer|der)
      _h=""
      [ -n "$OPENSSL" ] && _h=$("$OPENSSL" x509 -in "$_f" -subject_hash -noout 2>/dev/null)
      ;;
    pem|PEM)
      _h=""
      [ -n "$OPENSSL" ] && _h=$("$OPENSSL" x509 -in "$_f" -subject_hash -noout 2>/dev/null)
      ;;
    *) _h="" ;;
  esac
  echo "$_h"
}

_cert_subject() {
  _f="$1" _n="$2" _e="${_n##*.}"
  case "$_e" in
    0|crt|cer|der)
      _s="${_n%.*}"
      [ -n "$OPENSSL" ] && { _t=$("$OPENSSL" x509 -in "$_f" -subject -noout 2>/dev/null); [ -n "$_t" ] && _s="$_t"; }
      ;;
    pem|PEM)
      _s="(need openssl)"
      [ -n "$OPENSSL" ] && { _s=$("$OPENSSL" x509 -in "$_f" -subject -noout 2>/dev/null); [ -z "$_s" ] && _s="Unable to parse"; }
      ;;
    *) _s="$_n" ;;
  esac
  echo "$_s"
}

# ============================================================
# 收集所有数据到变量，末尾一次性输出
# ============================================================

_OUT=""
_PUT() { _OUT="${_OUT}$1"; }
_COMMA=""

_PUT '{"debug":{'
_PUT "\"moddir\":\"${MODDIR:-unknown}\","
_PUT "\"openssl\":$([ -n "$OPENSSL" ] && echo 1 || echo 0)"

_PUT ","
_dir_info "$MANUAL_DIR"; _PUT ","
_dir_info "$HC_CERTS"; _PUT ","
_dir_info "$USER_CERT_DIR"; _PUT ","
_dir_info "$SYS_CERT_DIR"; _PUT ","
_dir_info "$APEX_CERT_DIR"

_uid=$(id -u 2>/dev/null || echo "?")
_PUT ",\"uid\":\"$_uid\""
_PUT "},"

# 系统证书列表
_PUT '"sys":{"list":['
_sys_list=$(ls "$SYS_CERT_DIR" "$APEX_CERT_DIR" 2>/dev/null | sort -u)
_sys_first=1
for _c in $_sys_list; do
  [ -z "$_c" ] && continue
  [ $_sys_first -eq 1 ] && _sys_first=0 || _PUT ","
  _PUT "\"$_c\""
done
_PUT "]},"

# 用户证书列表
_PUT '"user":{"list":['
_user_list=$(ls "$USER_CERT_DIR" 2>/dev/null)
_user_first=1
for _c in $_user_list; do
  [ -z "$_c" ] && continue
  [ $_user_first -eq 1 ] && _user_first=0 || _PUT ","
  _PUT "\"$_c\""
done
_PUT "]},"

_PUT '"certs":['

_seen=""
_is_seen() { for _s in $_seen; do [ "$_s" = "$1" ] && return 0; done; return 1; }

_scan() {
  _dir="$1" _src="$2" _app="$3" _glob="$4"
  [ -d "$_dir" ] || return
  for _cert in "$_dir"/$_glob; do
    [ -f "$_cert" ] || continue
    _n=$(basename "$_cert")
    _e="${_n##*.}"
    _h=$(_cert_hash "$_cert" "$_n")
    _converted=1
    if [ -z "$_h" ]; then
      _h="${_n%.*}"
      _converted=0
    fi
    _is_seen "$_h" && continue; _seen="$_seen $_h"
    _s=$(_cert_subject "$_cert" "$_n")
    _size=$(wc -c < "$_cert" 2>/dev/null || echo 0)
    _dst="${_h}.0"
    _moved=0
    [ -f "$SYS_CERT_DIR/$_dst" ] || [ -f "$APEX_CERT_DIR/$_dst" ] && _moved=1
    grep -qxF "$_dst" "$TRACKING_FILE" 2>/dev/null && _moved=1
    [ "$_e" = "PEM" ] && _e="pem"

    [ -n "$_COMMA" ] && _PUT "$_COMMA"
    _COMMA=","
    _PUT "$(printf '{"name":"%s","target":"%s","hash":"%s","subject":"%s","size":%s,"moved":%s,"source":"%s","app":"%s","format":"%s","converted":%s}' \
      "$_n" "$_dst" "$_h" "$_s" "$_size" "$_moved" "$_src" "$_app" "$_e" "$_converted")"
  done
}

_scan "$USER_CERT_DIR" "user-certs" "系统设置安装" "*"
_scan "$MANUAL_DIR"    "manual"     "手动放置"      "*"
_scan "$HC_CERTS"     "app-data"   "HttpCanary"    "*"
_scan "/data/data/com.guoshi.httpcanary/cache" "app-data" "HttpCanary" "*.pem"
_scan "/data/data/com.guoshi.httpcanary/files" "app-data" "HttpCanary" "*.pem"
_scan "/data/data/com.lixiqing.proxypin/certs" "app-data" "ProxyPin" "*"
_scan "/data/data/com.lixiqing.proxypin/files/certs" "app-data" "ProxyPin" "*"
_scan "/data/data/app.greyshirts.pcap/app_certs" "app-data" "PacketCapture" "*"
_scan "/data/data/app.greyshirts.ssc/app_certs"  "app-data" "PacketCapture" "*"
_scan "/data/data/com.telerik.fiddler/files"     "app-data" "Fiddler"       "*.cer"
_scan "/data/data/com.telerik.fiddler/files"     "app-data" "Fiddler"       "*.pem"
_scan "/data/data/com.xk72.charles/files"        "app-data" "Charles"       "*.pem"

_PUT "]}"
echo "$_OUT"
