#!/system/bin/sh
# 检查最新版本 — 从 GitHub Releases API 获取

CURRENT_VER=$(grep "^version=" "/data/adb/modules/MoveCA2SYS/module.prop" 2>/dev/null | cut -d= -f2)
CURRENT_CODE=$(grep "^versionCode=" "/data/adb/modules/MoveCA2SYS/module.prop" 2>/dev/null | cut -d= -f2)
PROXY="${1:-}"  # 可选代理 http://127.0.0.1:10809

fetch_url() {
  _url="$1"
  if [ -n "$PROXY" ]; then
    # 尝试 curl + 代理
    command -v curl 2>/dev/null && curl -s --max-time 10 -x "$PROXY" "$_url" 2>/dev/null && return
    # 尝试 wget + 代理
    command -v wget 2>/dev/null && wget -q -O - --timeout=10 -e "use_proxy=on" -e "http_proxy=$PROXY" -e "https_proxy=$PROXY" "$_url" 2>/dev/null && return
  else
    command -v curl 2>/dev/null && curl -s --max-time 10 "$_url" 2>/dev/null && return
    command -v wget 2>/dev/null && wget -q -O - --timeout=10 "$_url" 2>/dev/null && return
  fi
  return 1
}

JSON=$(fetch_url "https://api.github.com/repos/CHERWING/MoveCA2SYS/releases/latest" 2>/dev/null)
if [ -z "$JSON" ]; then
  echo '{"ok":false,"error":"无法连接 GitHub","current":{"version":"'$CURRENT_VER'","code":"'$CURRENT_CODE'"}}'
  exit 1
fi

LATEST_VER=$(echo "$JSON" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
LATEST_CODE=$(echo "$JSON" | grep -m1 '"id"' | sed 's/.*"id": *\([0-9]*\).*/\1/')
LATEST_URL=$(echo "$JSON" | grep '"zipball_url"' | head -1 | sed 's/.*"zipball_url": *"\([^"]*\)".*/\1/')
DOWNLOAD_URL=$(echo "$JSON" | grep '"browser_download_url"' | head -1 | sed 's/.*"browser_download_url": *"\([^"]*\)".*/\1/')
BODY=$(echo "$JSON" | grep '"body"' | head -1 | sed 's/.*"body": *"\(.*\)"/\1/' | sed 's/\\r\\n/\\n/g')

# 简单版本号比较
NEED_UPDATE=0
if [ -n "$LATEST_VER" ] && [ "$LATEST_VER" != "$CURRENT_VER" ]; then
  NEED_UPDATE=1
fi

echo '{"ok":true,"current":{"version":"'$CURRENT_VER'","code":"'$CURRENT_CODE'"},"latest":{"version":"'$LATEST_VER'","code":"'$LATEST_CODE'"},"need_update":'$NEED_UPDATE',"download":"'$DOWNLOAD_URL'","zipball":"'$LATEST_URL'"}'