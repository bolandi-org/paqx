<p align="center">
  <h1 align="center">PaqX</h1>
  <p align="center"><strong>Universal Paqet Tunnel Manager</strong></p>
  <p align="center">
    <a href="#"><img src="https://img.shields.io/badge/Platform-Linux%20|%20OpenWrt%20|%20Windows-0078D4?style=flat-square" alt="Platform"></a>
    <a href="#"><img src="https://img.shields.io/badge/License-MIT-orange?style=flat-square" alt="License"></a>
    <a href="https://github.com/hanselime/paqet"><img src="https://img.shields.io/badge/Core-Paqet-blueviolet?style=flat-square" alt="Core"></a>
  </p>
</p>

---

Deploy and manage **[Paqet](https://github.com/hanselime/paqet)** tunnels across **Linux servers**, **Linux/OpenWrt clients**, and **Windows** — from a single toolset.

## Quick Start

### 🐧 Linux Server / Linux Client / OpenWrt Router

```bash
curl -L "https://raw.githubusercontent.com/bolandi-org/paqx/main/paqx" -o /usr/bin/paqx && chmod +x /usr/bin/paqx && paqx install
```

The installer auto-detects your OS and presents the appropriate role (Server or Client).

### 🪟 Windows Client

Open **PowerShell as Administrator** in any folder and run:

```powershell
iwr https://raw.githubusercontent.com/bolandi-org/paqx/main/windows/setup.ps1 -OutFile paqx.ps1 -UseBasicParsing; .\paqx.ps1
```

> **Note:** [Npcap](https://npcap.com/#download) is required. The script will detect if it's missing and offer to download it automatically.

---

## Features

### Server (Linux)

| Feature | Description |
|---------|-------------|
| **Protocol Modes** | `Simple` (key only) · `Automatic` (tuned to CPU/RAM) · `Manual` (14 params) |
| **Kernel Optimization** | BBR, TCP Fast Open, socket buffers via `/etc/sysctl.d/99-paqx.conf` (safe, isolated) |
| **Firewall Anti-Probing** | `NOTRACK` + `RST DROP` rules, tagged with `--comment "paqx"` — zero impact on Docker/Traefik/Nginx |
| **IPv4 + IPv6** | Full dual-stack firewall support |
| **Auto-Detection** | Local IP, interface, gateway MAC |

### Client (Linux / OpenWrt / Windows)

| Feature | Description |
|---------|-------------|
| **Plug & Play** | Auto-detects network adapter, gateway MAC, and generates config |
| **SOCKS5 Proxy** | Configurable local port (default `1080`) |
| **Service Management** | `systemd` (Linux) · `procd` (OpenWrt) · Scheduled Task (Windows) |
| **Protocol Modes** | `Simple` (key only) · `Automatic` (optimized defaults) |
| **Portable (Windows)** | Runs from any folder — binary + config stored locally |

### Management Panel

After installation, run `paqx` (Linux/OpenWrt) or the PowerShell script (Windows) to access:

```
╔═══════════════════════════════╗
║       PaqX Server Panel       ║
╚═══════════════════════════════╝

┌──────────────────────────────────────────────┐
│ Status:   ● Running                          │
│ Auto:     Enabled                             │
├──────────────────────────────────────────────┤
│ Address:  213.x.x.x:8443                    │
│ Key:      tkXAy3Kkzc9g4aQKNX8jzLJfOkBgYEDs  │
└──────────────────────────────────────────────┘

 1) Status       5) Disable/Enable
 2) Log          6) Settings
 3) Start/Stop   7) Update Core
 4) Restart      8) Uninstall
```

---

## Architecture

```
paqx/
├── paqx                    # Main entry point (bash)
├── lib/
│   ├── core.sh             # Constants, colors, shared helpers
│   ├── utils.sh            # Logging, arch detection, download
│   ├── network.sh          # IP/interface/gateway detection
│   └── crypto.sh           # Key generation
├── modules/
│   ├── server.sh           # Server install, config, firewall, uninstall
│   ├── client.sh           # Linux client
│   └── client_openwrt.sh   # OpenWrt client
└── windows/
    └── setup.ps1           # Windows client (PowerShell)
```

---

## Security

- **Firewall rules** are tagged with `--comment "paqx"` — only PaqX rules are touched during uninstall
- **Kernel params** use a separate `/etc/sysctl.d/99-paqx.conf` file — `/etc/sysctl.conf` is never modified
- **Config files** are stored with `600` permissions
- **Encryption keys** are generated via `openssl rand -base64 24`

---

## Uninstall

### Linux / OpenWrt

Select **Uninstall** from the panel menu, or remove manually:

```bash
systemctl stop paqx && systemctl disable paqx
rm -f /etc/systemd/system/paqx.service
rm -f /etc/sysctl.d/99-paqx.conf
rm -rf /etc/paqx /usr/local/paqx /usr/bin/paqx /usr/bin/paqet
sysctl --system
```

### Windows

Select **Uninstall** from the PowerShell panel, or remove manually:

```powershell
Stop-ScheduledTask -TaskName "PaqX_Client"
Unregister-ScheduledTask -TaskName "PaqX_Client" -Confirm:$false
Remove-Item paqet.exe, config.yaml -Force
```

---

# 🇮🇷 راهنمای فارسی

**PaqX — ابزار مدیریت هوشمند تونل [Paqet](https://github.com/hanselime/paqet)**

## نصب سریع

### سرور لینوکس / کلاینت لینوکس / روتر OpenWrt

```bash
curl -L "https://raw.githubusercontent.com/bolandi-org/paqx/main/paqx" -o /usr/bin/paqx && chmod +x /usr/bin/paqx && paqx install
```

اسکریپت به صورت خودکار سیستم‌عامل را تشخیص داده و نقش مناسب (سرور/کلاینت) را پیشنهاد می‌دهد.

### ویندوز

پاورشل را **به عنوان ادمین** باز کنید و در هر فولدری اجرا کنید:

```powershell
iwr https://raw.githubusercontent.com/bolandi-org/paqx/main/windows/setup.ps1 -OutFile paqx.ps1 -UseBasicParsing; .\paqx.ps1
```

> Npcap لازم است. اسکریپت در صورت نبود آن، دانلود خودکار پیشنهاد می‌دهد.

## حالت‌های پروتکل

| حالت | توضیح |
|------|-------|
| **Simple** | فقط `mode: fast` و `key` — بدون تنظیمات اضافی (مشابه paqctl) |
| **Automatic** | بهینه‌سازی خودکار بر اساس RAM و CPU سرور |
| **Manual** | تنظیم دستی ۱۴ پارامتر پروتکل KCP |

## امنیت

- **قوانین فایروال** با تگ `paqx` مشخص می‌شوند — هنگام حذف فقط قوانین PaqX پاک می‌شوند
- **تنظیمات کرنل** در فایل جداگانه `/etc/sysctl.d/99-paqx.conf` — بدون تغییر `sysctl.conf` اصلی
- **Docker، Traefik، Nginx** و سایر سرویس‌ها هیچ تأثیری نمی‌پذیرند

---

**Developed by [Bolandi-Org](https://github.com/bolandi-org)**
