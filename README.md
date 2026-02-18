# PaqX - Universal Paqet Manager

[![Platform](https://img.shields.io/badge/Platform-Linux%20|%20OpenWrt%20|%20Windows-blue)]()
[![License](https://img.shields.io/badge/License-MIT-orange)]()

**The ultimate all-in-one management tool for deploying [Paqet](https://github.com/hanselime/paqet) tunnels.**  
Supports **Linux Servers**, **Linux Clients**, **OpenWrt Routers**, and **Windows**.

---

## 🚀 Installation & Usage

### 🐧 Linux (Server & Client) / OpenWrt

Run the following command on your **Server**, **Linux Desktop**, or **OpenWrt Router**:

```bash
curl -L "https://raw.githubusercontent.com/bolandi-org/paqx/main/paqx" -o /usr/bin/paqx && chmod +x /usr/bin/paqx && paqx install
```

* **Server Mode:** Intelligent optimization for CPU/RAM, Auto-Firewall configuration (Bypassing GFW active probing).
* **Client Mode:** Auto-detects Gateway MAC, sets up systemd/procd service.

### 🪟 Windows

1. Download and install [Npcap](https://npcap.com/#download) (Check "Install in WinPcap API-compatible Mode").
2. Open **PowerShell** as Administrator.
3. Run the installer:

    ```powershell
    irm https://raw.githubusercontent.com/bolandi-org/paqx/main/windows/setup.ps1 | iex
    ```

---

## 🛠 Features

* **Intelligent Server Optimization**:
  * Auto-tunes `sysctl` kernel parameters (BBR, Fast Open, File/Socket limits).
  * Dynamic buffer calculation (SndWnd/RcvWnd) based on available RAM.
* **Firewall Bypass**:
  * Automatically applies `iptables` rules to set `NOTRACK` and DROP `RST` packets, preventing connection resets.
* **Multi-Platform**:
  * **OpenWrt**: Uses `procd` and lightweight dependencies (`opkg`).
  * **Linux**: Uses `systemd` and standard package managers (`apt`, `yum`, `dnf`).
  * **Windows**: Native PowerShell setup with `Scheduled Task` persistence.
* **Plug & Play**: Auto-detects Architecture (amd64, arm64, mips, etc.) and Network Interface/Gateway.

---

# 🇮🇷 راهنمای فارسی (Persian Documentation)

**پک‌اِکس (PaqX) - ابزار مدیریت هوشمند تونل Paqet برای سرور و کلاینت**

---

## 🚀 نصب و راه‌اندازی

### 🐧 سرور لینوکس / کلاینت لینوکس / روتر OpenWrt

دستور زیر را در ترمینال اجرا کنید. اسکریپت به صورت خودکار سیستم عامل را تشخیص داده و گزینه‌های مناسب (سرور/کلاینت) را نمایش می‌دهد:

```bash
curl -L "https://raw.githubusercontent.com/bolandi-org/paqx/main/paqx" -o /usr/bin/paqx && chmod +x /usr/bin/paqx && paqx install
```

* **سمت سرور (Server):**
  * بهینه‌سازی خودکار هسته لینوکس (BBR, TCP Tuning).
  * تنظیم فایرفال برای جلوگیری از شناسایی (IPtables NOTRACK).
  * محاسبه بهترین کانفیگ بر اساس میزان رم و قدرت پردازنده سرور.
* **سمت کلاینت (OpenWrt/Linux):**
  * شناسایی خودکار گت‌وی (Gateway) و مک آدرس.
  * نصب سرویس پایدار (Systemd/Procd).

### 🪟 ویندوز

۱. ابتدا برنامه [Npcap](https://npcap.com/#download) را دانلود و نصب کنید (تیک گزینه WinPcap Compatible را بزنید).
۲. پاورشل (PowerShell) را به صورت **Run as Administrator** باز کنید.
۳. دستور زیر را اجرا کنید:

```powershell
irm https://raw.githubusercontent.com/bolandi-org/paqx/main/windows/setup.ps1 | iex
```

---

## منوی مدیریت (Management Menu)

پس از نصب، با تایپ دستور `paqx` (در لینوکس) یا اجرای مجدد اسکریپت (در ویندوز) به پنل مدیریت دسترسی خواهید داشت:

* **Start/Stop:** مدیریت سرویس.
* **Uninstall:** حذف کامل برنامه و تنظیمات.
* **Logs:** مشاهده وضعیت اتصال و خطاها.

---
**Developed by Bolandi-Org**
