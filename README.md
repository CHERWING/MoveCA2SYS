# MoveCA2SYS 🚀

<p align="center">
  <img src="https://img.shields.io/badge/Magisk-Support-00BFA5?style=flat-square">
  <img src="https://img.shields.io/badge/KernelSU-Support-1976D2?style=flat-square">
  <img src="https://img.shields.io/badge/APatch-Support-FF6F00?style=flat-square">
  <img src="https://img.shields.io/badge/openssl-Built_in-4CAF50?style=flat-square">
  <img src="https://img.shields.io/badge/OTA_Update-Supported-FF5722?style=flat-square">
  <br>
  <a href="README_CN.md">🇨🇳 中文版</a>
</p>

<p align="center">
  Move packet capture certificates to Android system trust store via WebUI 📱<br>
  HttpCanary · ProxyPin · Packet Capture · Fiddler · Charles · Manual
</p>

---

## ✨ Features

- **🖥️ WebUI Management** — Graphical interface in module manager, no CLI needed
- **📊 Stats Dashboard** — Total / Moved / Pending counts at a glance
- **🔍 Search & Filter** — By hash, subject, filename, source app
- **📋 Cert Details** — Hash name, subject, original filename, format, size, status
- **🔄 OTA Updates** — Auto-detect updates in Magisk/KernelSU manager
- **📦 Built-in openssl** — Pre-compiled for arm64-v8a / armeabi-v7a / x86_64 / x86
- **🔄 Auto PEM Convert** — PEM/CRT/DER → `subject_hash.0` via openssl
- **📁 Manual Drop** — Place certs in `/storage/emulated/0/MoveCA2SYS/`
- **🛡️ Dedup Protection** — Each cert shown once
- **📝 Tracking Log** — Tracks moved certs for clean uninstall

## 📥 Installation

```bash
# Flash the zip in Magisk / KernelSU / APatch manager
```

## 🎮 Usage

1. Open Magisk/KernelSU → **Modules** → **MoveCA2SYS**
2. Tap **UI** to open the WebUI
3. Tap **Refresh** to scan certificates
4. Tap **Move All** or click **Move** per row

### OTA Update

The module manager automatically checks for updates via `update.json`. You can also tap the **Update** button in WebUI.

### Verification

```bash
ls /system/etc/security/cacerts/ | grep -E "^[a-f0-9]{8}\.0$" | head -10
cat /cache/moveca2sys.log
```

## 📂 File Structure

```
MoveCA2SYS/
├── module.prop                         # Module metadata (with updateJson)
├── update.json                         # OTA update info
├── CHANGELOG.md                        # Changelog
├── post-fs-data.sh                     # Android 14+ mount --bind
├── customize.sh                        # Install script
├── uninstall.sh                        # Uninstall cleanup
├── pack.ps1                            # Packaging script
├── README.md                           # English readme
├── README_CN.md                        # Chinese readme
├── common/
│   ├── scan.sh                         # Cert scanner → JSON
│   ├── move.sh                         # Move certificates
│   ├── check-update.sh                 # Update check (WebUI)
│   └── tools/
│       └── <arch>/openssl              # Static openssl binaries
├── webroot/
│   └── index.html                      # WebUI management page
└── system/etc/security/cacerts/        # Module cert overlay (no .replace)
```

## 🔧 Technical Details

| Feature | Description |
|---------|-------------|
| **Android ≤13** | Copy to `/system/etc/security/cacerts`; KernelSU magic mount persists after reboot |
| **Android 14+ (SDK ≥ 34)** | `mount --bind` overlay → writeable `/apex/com.android.conscrypt/cacerts` |
| **Cert Convert** | openssl `x509 -subject_hash` → PEM/CRT/DER → `<hash>.0` |
| **Permission Fix** | `chmod 644` + `chcon u:object_r:system_file:s0` |
| **Dual Copy** | Copies to system dir (immediate) + module dir (reboot persistence) |
| **OTA Update** | `update.json` → GitHub Release; auto-detect in module manager |
| **Find Limit** | `find -maxdepth 6` prevents `/data/data` scan freeze |

## 📎 Supported Sources

| Source | Format |
|--------|--------|
| HttpCanary (`com.guoshi.httpcanary`) | PEM / `.0` |
| ProxyPin (`com.lixiqing.proxypin`) | Any |
| Packet Capture (`app.greyshirts.*`) | Any |
| Fiddler (`com.telerik.fiddler`) | CER / PEM |
| Charles (`com.xk72.charles`) | PEM |
| System Settings → User certs | `.0` |
| Manual (`/storage/emulated/0/MoveCA2SYS/`) | Any |

## 🧹 Uninstall

Remove the module in manager — `uninstall.sh` automatically cleans up all migrated certs.
