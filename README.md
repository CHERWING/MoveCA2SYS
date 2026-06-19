# MoveCA2SYS 🚀

<p align="center">
  <img src="https://img.shields.io/badge/Magisk-支持-00BFA5?style=flat-square">
  <img src="https://img.shields.io/badge/KernelSU-支持-1976D2?style=flat-square">
  <img src="https://img.shields.io/badge/APatch-支持-FF6F00?style=flat-square">
  <img src="https://img.shields.io/badge/openssl-内置-4CAF50?style=flat-square">
  <img src="https://img.shields.io/badge/API-24%2B-FF5722?style=flat-square">
</p>

<p align="center">
  将抓包证书一键移至系统目录的 WebUI 管理模块 📱<br>
  支持 HttpCanary · ProxyPin · Packet Capture · Fiddler · Charles · 手动放置
</p>

---

## ✨ 功能亮点

- **🖥️ WebUI 管理** — 模块管理器直接打开，图形化操作，无需写命令
- **📊 统计面板** — 总计 / 已迁移 / 待迁移，状态一目了然
- **🔍 搜索过滤** — 按 hash、Subject、文件名、来源 App 实时筛选
- **📋 证书详情** — 显示 hash 名、Subject、原始文件名、格式、大小、状态
- **📦 内置 openssl** — arm64-v8a / armeabi-v7a / x86_64 / x86 四架构全内置，安装时自动匹配
- **🔄 PEM 自动转换** — PEM/CRT/DER 自动计算 subject_hash → `<hash>.0`
- **📁 手动放置** — 放入 `/storage/emulated/0/MoveCA2SYS/` 即可识别
- **🛡️ 去重保护** — 同一证书仅显示一次，防止重复迁移
- **📝 跟踪清单** — 记录已迁移证书，增量操作、干净卸载

## 📥 安装

```bash
# 在 Magisk / KernelSU / APatch 管理器中直接刷入 zip
```

## 🎮 使用指南

1. 打开 Magisk/KernelSU → **模块** → **MoveCA2SYS**
2. 点击 **UI** 按钮进入管理界面
3. 单击 **刷新** 扫描证书
4. 点击 **迁移全部** 或逐行点击 **移动**

### 验证迁移

```bash
# 查看系统证书目录
ls /system/etc/security/cacerts/ | grep -E "^[a-f0-9]{8}\.0$" | head -10

# 查看迁移日志
cat /cache/moveca2sys.log
```

## 📂 文件结构

```
MoveCA2SYS/
├── module.prop                         # 📋 模块元数据
├── post-fs-data.sh                     # 🚀 Android 14+ mount --bind
├── customize.sh                        # ⚙️ 安装脚本 (自动选择架构 openssl)
├── uninstall.sh                        # 🗑️ 卸载清理
├── pack.ps1                            # 📦 打包脚本 (.NET ZipFile)
├── README.md                           # 📖 说明文档
├── common/
│   ├── scan.sh                         # 🔍 扫描证书输出 JSON
│   ├── move.sh                         # 📤 移动证书 (单个/批量)
│   └── tools/
│       ├── install-openssl.sh          # 🔗 搜索设备已有 openssl
│       ├── arm64-v8a/openssl           # 🤖 arm64 静态 openssl
│       ├── armeabi-v7a/openssl         # 🤖 armv7 静态 openssl
│       ├── x86_64/openssl              # 🖥️ x86_64 静态 openssl
│       └── x86/openssl                 # 🖥️ x86 静态 openssl
├── webroot/
│   └── index.html                      # 🌐 WebUI 管理页面
└── system/
    └── etc/security/cacerts/           # 📁 模块证书覆写目录 (无 .replace)
```

## 🔧 技术机制

| 特性 | 说明 |
|------|------|
| **Android 13 及以下** | 直接复制到 `/system/etc/security/cacerts`，KernelSU magic mount 重启保留 |
| **Android 14+ (SDK ≥ 34)** | `post-fs-data.sh` → `mount --bind` overlay → 使 `/apex/com.android.conscrypt/cacerts` 可写 |
| **证书转换** | openssl `x509 -subject_hash` → PEM/CRT → `<hash>.0` |
| **权限修复** | `chmod 644` + `chcon u:object_r:system_file:s0` |
| **双拷贝策略** | 同时复制到系统目录（立即生效）和模块目录（重启保留） |
| **迁移跟踪** | `certs_installed.txt` 记录已迁移 hash，避免重复 |
| **查找限深** | `find -maxdepth 6` 避免扫描 `/data/data` 卡死 |

## 📎 支持的证书来源

| 来源 | 格式 |
|------|------|
| HttpCanary (`com.guoshi.httpcanary`) | PEM / `.0` |
| ProxyPin (`com.lixiqing.proxypin`) | 任意 |
| Packet Capture (`app.greyshirts.*`) | 任意 |
| Fiddler (`com.telerik.fiddler`) | CER / PEM |
| Charles (`com.xk72.charles`) | PEM |
| 系统设置安装的用户证书 | `.0` |
| 手动放置 (`/storage/emulated/0/MoveCA2SYS/`) | 任意 |

## 🧹 卸载

直接在模块管理器中移除模块即可，`uninstall.sh` 会自动清理已迁移的证书。

## 📄 开源许可

本项目仅供学习交流使用。
