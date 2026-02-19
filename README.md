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

---

## 🖥️ Server (Linux)

```bash
curl -L "https://raw.githubusercontent.com/bolandi-org/paqx/main/paqx" -o /usr/bin/paqx && chmod +x /usr/bin/paqx && paqx
```

Select **Server** on first run. The installer auto-configures firewall, kernel optimizations, and service.

---

## 📱 Client

### 🐧 Linux

```bash
curl -L "https://raw.githubusercontent.com/bolandi-org/paqx/main/paqx" -o /usr/bin/paqx && chmod +x /usr/bin/paqx && paqx
```

Select **Client** on first run. Requires server IP:Port and encryption key.

### 🪟 Windows

Open **PowerShell as Administrator** and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; iwr https://raw.githubusercontent.com/bolandi-org/paqx/main/windows/setup.ps1 -OutFile paqx.ps1 -UseBasicParsing; .\paqx.ps1
```

> **Note:** [Npcap](https://npcap.com/#download) is required. The script will detect if it's missing and offer to download it automatically.

### 📡 OpenWrt

SSH into your router and run:

```sh
curl -L "https://raw.githubusercontent.com/bolandi-org/paqx/main/openwrt/setup.sh" -o /tmp/paqx.sh && sh /tmp/paqx.sh
```

> After first setup, use `paqx` command to manage.

---

## Features

### Server

| Feature | Description |
|---------|-------------|
| **Protocol Modes** | `Simple` (key only) · `Automatic` (tuned to CPU/RAM) · `Manual` (14 params) |
| **Kernel Optimization** | BBR, TCP Fast Open, socket buffers via `/etc/sysctl.d/99-paqx.conf` |
| **Firewall Anti-Probing** | `NOTRACK` + `RST DROP` rules, tagged with `--comment "paqx"` |
| **IPv4 + IPv6** | Full dual-stack firewall support |
| **Auto-Detection** | Local IP, interface, gateway MAC |

### Client (All Platforms)

| Feature | Description |
|---------|-------------|
| **Plug & Play** | Auto-detects network adapter, gateway MAC, and generates config |
| **SOCKS5 Proxy** | Configurable local port (default `1080`) |
| **Service Management** | `systemd` (Linux) · `procd` (OpenWrt) · Scheduled Task (Windows) |
| **Protocol Modes** | `Simple` (key only) · `Automatic` (optimized defaults) |
| **Refresh Network** | Switch between adapters without reinstalling |

### Management Panel

All platforms share the same panel interface:

```
 1) Status           6) Settings
 2) Log              7) Update Core
 3) Start/Stop       8) Downgrade Core
 4) Restart          9) Uninstall
 5) Disable/Enable   0) Exit
```

Settings menu:

```
 1) Change Server (IP:Port & Key)
 2) Change Local SOCKS5 Port
 3) Change Protocol Mode
 4) View Server Info
 5) Refresh Network
 0) Back
```

---

## Architecture

```
paqx/
├── paqx                     # Linux entry point (Server & Client)
├── lib/
│   ├── core.sh              # Constants, colors, shared helpers
│   ├── utils.sh             # Logging, arch detection, download
│   ├── network.sh           # IP/interface/gateway detection
│   └── crypto.sh            # Key generation
├── modules/
│   ├── server.sh            # Server install, config, firewall
│   ├── client.sh            # Linux client
│   └── client_openwrt.sh    # OpenWrt client (modular)
├── windows/
│   └── setup.ps1            # Windows client (standalone)
└── openwrt/
    └── setup.sh             # OpenWrt client (standalone)
```

---

## Security

- **Firewall rules** are tagged with `--comment "paqx"` — only PaqX rules are touched during uninstall
- **Kernel params** use a separate `/etc/sysctl.d/99-paqx.conf` file — `/etc/sysctl.conf` is never modified
- **Config files** are stored with `600` permissions
- **Encryption keys** are generated via `openssl rand -base64 24`

---

## Uninstall

### Linux

Select **Uninstall** from the panel, or manually:

```bash
systemctl stop paqx && systemctl disable paqx
rm -f /etc/systemd/system/paqx.service /etc/sysctl.d/99-paqx.conf
rm -rf /etc/paqx /usr/local/paqx /usr/bin/paqx /usr/bin/paqet
sysctl --system
```

### Windows

Select **Uninstall** from the panel, or manually:

```powershell
Stop-ScheduledTask -TaskName "PaqX_Client"
Unregister-ScheduledTask -TaskName "PaqX_Client" -Confirm:$false
Remove-Item paqet.exe, config.yaml -Force
```

### OpenWrt

Select **Uninstall** from the panel, or manually:

```sh
/etc/init.d/paqet stop && /etc/init.d/paqet disable
rm -f /etc/init.d/paqet /usr/bin/paqet /usr/bin/paqx
rm -rf /etc/paqet
nft delete table inet paqet_rules 2>/dev/null
```

---

# 🇮🇷 راهنمای فارسی

**PaqX — ابزار مدیریت هوشمند تونل [Paqet](https://github.com/hanselime/paqet)**

## 🖥️ سرور (لینوکس)

```bash
curl -L "https://raw.githubusercontent.com/bolandi-org/paqx/main/paqx" -o /usr/bin/paqx && chmod +x /usr/bin/paqx && paqx
```

> در اولین اجرا **سرور** را انتخاب کنید.

## 📱 کلاینت

### 🐧 لینوکس

```bash
curl -L "https://raw.githubusercontent.com/bolandi-org/paqx/main/paqx" -o /usr/bin/paqx && chmod +x /usr/bin/paqx && paqx
```

> در اولین اجرا **کلاینت** را انتخاب کنید. آدرس سرور و کلید رمزنگاری لازم است.

### 🪟 ویندوز

پاورشل را **به عنوان ادمین** باز کنید:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; iwr https://raw.githubusercontent.com/bolandi-org/paqx/main/windows/setup.ps1 -OutFile paqx.ps1 -UseBasicParsing; .\paqx.ps1
```

> Npcap لازم است. اسکریپت در صورت نبود آن، دانلود خودکار پیشنهاد می‌دهد.

### 📡 اوپن‌دبلیوآرتی (OpenWrt)

از طریق SSH به روتر وصل شوید:

```sh
curl -L "https://raw.githubusercontent.com/bolandi-org/paqx/main/openwrt/setup.sh" -o /tmp/paqx.sh && sh /tmp/paqx.sh
```

> بعد از نصب اولیه، با دستور `paqx` مدیریت کنید.

## حالت‌های پروتکل

| حالت | توضیح |
|------|-------|
| **Simple** | فقط `mode: fast` و `key` — بدون تنظیمات اضافی |
| **Automatic** | بهینه‌سازی خودکار بر اساس RAM و CPU سرور |
| **Manual** | تنظیم دستی ۱۴ پارامتر پروتکل KCP |

## امنیت

- **قوانین فایروال** با تگ `paqx` مشخص می‌شوند — هنگام حذف فقط قوانین PaqX پاک می‌شوند
- **تنظیمات کرنل** در فایل جداگانه `/etc/sysctl.d/99-paqx.conf` — بدون تغییر `sysctl.conf` اصلی
- **Docker، Traefik، Nginx** و سایر سرویس‌ها هیچ تأثیری نمی‌پذیرند

---

**Developed by [Bolandi-Org](https://github.com/bolandi-org)**
