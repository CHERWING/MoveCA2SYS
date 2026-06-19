# Changelog

## v1.3 (2024-06-19)

- ✨ 新增在线更新机制（update.json + module.prop updateJson）
- 🖥️ WebUI 全面美化：统计卡片、证书详情、搜索过滤
- 📦 内置四架构 openssl，安装时自动匹配
- 🔧 修复 API 级别判断（`-ge 14` → `-ge 34`）
- ⚡ 修复移动 PEM/CRT 时 `find /data/data` 卡死
- 🗑️ 移除 `.replace` 文件，系统证书不再被隐藏
- 📋 证书列表显示原始文件名、Subject 信息
