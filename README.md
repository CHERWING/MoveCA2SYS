# MoveCA2SYS 🚀

<p align="center">
  <img src="https://img.shields.io/badge/Magisk-Support-00BFA5?style=flat-square">
  <img src="https://img.shields.io/badge/KernelSU-Support-1976D2?style=flat-square">
  <img src="https://img.shields.io/badge/APatch-Support-FF6F00?style=flat-square">
  <img src="https://img.shields.io/badge/openssl-Built-in-4CAF50?style=flat-square">
  <img src="https://img.shields.io/badge/OTA_Update-Supported-FF5722?style=flat-square">
</p>

<p align="center">
  Move packet capture certificates to Android system trust store via WebUI 📱<br>
  <strong>将抓包证书一键移至系统证书目录的 WebUI 管理模块</strong><br>
  HttpCanary · ProxyPin · Packet Capture · Fiddler · Charles · Manual
</p>

---

## ✨ Features / 功能亮点

- **🖥️ WebUI Management** — Graphical interface in module manager, no CLI needed / 图形化操作
- **📊 Stats Dashboard** — Total / Moved / Pending counts / 统计面板一目了然
- **🔍 Search & Filter** — By hash, subject, filename, source app / 多维搜索过滤
- **📋 Cert Details** — Hash name, subject, original filename, format, size, status / 证书详情
- **🔄 OTA Updates** — Auto-detect updates in Magisk/KernelSU manager / 面板内在线更新
- **📦 Built-in openssl** — Pre-compiled for arm64-v8a / armeabi-v7a / x86_64 / x86 / 内置四架构 openssl
- **🔄 Auto PEM Convert** — PEM/CRT/DER → `subject_hash.0` via openssl / 自动转换
- **📁 Manual Drop** — Place certs in `/storage/emulated/0/MoveCA2SYS/` / 手动放置即识别
- **🛡️ Dedup Protection** — Each cert shown once / 同一证书仅显示一次
- **📝 Tracking Log** — `certs_installed.txt` tracks moved certs for clean uninstall / 跟踪清单

## 📥 Installation / 安装

```bash
# Flash the zip in Magisk / KernelSU / APatch manager
# 在模块管理器直接刷入
```

## 🎮 Usage / 使用指南

1. Open Magisk/KernelSU → **Modules** → **MoveCA2SYS**
2. Tap **UI** to open the WebUI / 点击 **UI** 按钮
3. Tap **Refresh** to scan certificates / 单击 **刷新** 扫描
4. Tap **Move All** or click **Move** per row / 迁移全部或逐行移动

### OTA Update / 在线更新

The module manager automatically checks for updates via `update.json`. You can also tap the **Update** button in WebUI.

模块管理器面板内自动检测更新，WebUI 也提供检测按钮。

### Verification / 验证

```bash
# List system certificates
ls /system/etc/security/cacerts/ | grep -E "^[a-f0-9]{8}\.0$" | head -10

# View migration log
cat /cache/moveca2sys.log
```

## 📂 File Structure / 文件结构

```
MoveCA2SYS/
├── module.prop                         # 📋 Module metadata (with updateJson)
├── update.json                         # 🔄 OTA update info
├── CHANGELOG.md                        # 📝 Changelog
├── post-fs-data.sh                     # 🚀 Android 14+ mount --bind
├── customize.sh                        # ⚙️ Install script
├── uninstall.sh                        # 🗑️ Uninstall cleanup
├── pack.ps1                            # 📦 Packaging script (.NET ZipFile)
├── common/
│   ├── scan.sh                         # 🔍 Cert scanner → JSON
│   ├── move.sh                         # 📤 Move certificates
│   ├── check-update.sh                 # 🔄 Update check (WebUI)
│   └── tools/
│       ├── arm64-v8a/openssl           # 🤖 Static openssl
│       ├── armeabi-v7a/openssl
│       ├── x86_64/openssl
│       └── x86/openssl
├── webroot/
│   └── index.html                      # 🌐 WebUI management page
└── system/etc/security/cacerts/        # 📁 Module cert overlay (no .replace)
```

## 🔧 Technical Details / 技术机制

| Feature | Description |
|---------|-------------|
| **Android ≤13** | Copy to `/system/etc/security/cacerts`; KernelSU magic mount persists after reboot |
| **Android 14+ (SDK ≥ 34)** | `mount --bind` overlay → writeable `/apex/com.android.conscrypt/cacerts` |
| **Cert Convert** | openssl `x509 -subject_hash` → PEM/CRT/DER → `<hash>.0` |
| **Permission Fix** | `chmod 644` + `chcon u:object_r:system_file:s0` |
| **Dual Copy** | Copies to system dir (immediate) + module dir (reboot persistence) |
| **OTA Update** | `update.json` → GitHub Release; auto-detect in module manager |
| **Find Limit** | `find -maxdepth 6` prevents `/data/data` scan freeze |

## 📎 Supported Sources / 支持的来源

| Source | Format |
|--------|--------|
| HttpCanary (`com.guoshi.httpcanary`) | PEM / `.0` |
| ProxyPin (`com.lixiqing.proxypin`) | Any |
| Packet Capture (`app.greyshirts.*`) | Any |
| Fiddler (`com.telerik.fiddler`) | CER / PEM |
| Charles (`com.xk72.charles`) | PEM |
| System Settings → User certs | `.0` |
| Manual (`/storage/emulated/0/MoveCA2SYS/`) | Any |

## 🧹 Uninstall / 卸载

Remove the module in manager — `uninstall.sh` automatically cleans up all migrated certs.

在模块管理器中移除即可，`uninstall.sh` 自动清理已迁移证书。
