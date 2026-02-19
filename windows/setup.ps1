<#
.SYNOPSIS
    PaqX Client for Windows - Plug & Play Setup
.DESCRIPTION
    Fully automatic Paqet client for Windows.
    Run from any folder - all files are downloaded and stored in that folder.
    Requires: PowerShell (Admin) + Npcap installed.
#>

# -- Constants ----------------------------------------------------------
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $ScriptDir) { $ScriptDir = Get-Location }
$BinaryName = "paqet.exe"
$BinaryPath = Join-Path $ScriptDir $BinaryName
$ConfigPath = Join-Path $ScriptDir "config.yaml"
$TaskName = "PaqX_Client"
$RepoOwner = "hanselime"
$RepoName = "paqet"
$NpcapUrl = "https://npcap.com/dist/npcap-1.80.exe"

# -- Colors -------------------------------------------------------------
function Write-C { param([string]$T, [string]$C = "White") Write-Host $T -ForegroundColor $C -NoNewline }
function Write-CL { param([string]$T, [string]$C = "White") Write-Host $T -ForegroundColor $C }
function Write-OK { param([string]$T) Write-CL "[+] $T" "Green" }
function Write-Warn { param([string]$T) Write-CL "[!] $T" "Yellow" }
function Write-Err { param([string]$T) Write-CL "[-] $T" "Red" }
function Write-Info { param([string]$T) Write-CL "[*] $T" "Cyan" }

# -- Admin Check --------------------------------------------------------
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Err "Please run PowerShell as Administrator!"
    Start-Sleep -Seconds 3
    Exit 1
}

# -- Npcap --------------------------------------------------------------
function Test-Npcap {
    if (Test-Path "C:\Windows\System32\Npcap" -PathType Container) { return $true }
    return $false
}

function Install-Npcap {
    Write-Info "Npcap is required but not found."
    Write-CL ""
    Write-CL "  Options:" "Yellow"
    Write-CL "  1) Download & Install automatically"
    Write-CL "  2) I'll install it manually (exit)"
    $c = Read-Host "  Select [1]"
    if ($c -eq "2") { Write-Warn "Install Npcap from: https://npcap.com/#download"; Exit }

    $npcapPath = Join-Path $env:TEMP "npcap-installer.exe"
    Write-Info "Downloading Npcap..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $NpcapUrl -OutFile $npcapPath -UseBasicParsing
        Write-OK "Downloaded. Starting installer..."
        Write-Warn "IMPORTANT: Check 'Install Npcap in WinPcap API-compatible Mode'"
        Start-Process -FilePath $npcapPath -Wait
        if (Test-Npcap) {
            Write-OK "Npcap installed successfully."
        }
        else {
            Write-Err "Npcap still not detected. Please install manually."
            Exit 1
        }
    }
    catch {
        Write-Err "Failed to download Npcap: $_"
        Write-Warn "Install manually from: https://npcap.com/#download"
        Exit 1
    }
}

# -- Binary Download ----------------------------------------------------
function Get-PaqetBinary {
    Write-Info "Fetching latest release from GitHub..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $apiUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest"
        $release = Invoke-RestMethod -Uri $apiUrl -Headers @{"User-Agent" = "PaqX" } -UseBasicParsing

        $asset = $release.assets | Where-Object { $_.name -match "windows.*amd64.*\.zip$" } | Select-Object -First 1
        if (-not $asset) {
            Write-Err "No Windows amd64 binary found in release."
            return $false
        }

        $zipPath = Join-Path $env:TEMP "paqet-win.zip"
        $extractDir = Join-Path $env:TEMP "paqet-extract"

        Write-Info "Downloading $($asset.name)..."
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing

        if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

        $exe = Get-ChildItem -Path $extractDir -Recurse -Filter "paqet.exe" | Select-Object -First 1
        if ($exe) {
            Copy-Item -Path $exe.FullName -Destination $BinaryPath -Force
            Write-OK "Binary installed: $BinaryPath"
        }
        else {
            # Might be named differently
            $exe = Get-ChildItem -Path $extractDir -Recurse -Filter "*.exe" | Select-Object -First 1
            if ($exe) {
                Copy-Item -Path $exe.FullName -Destination $BinaryPath -Force
                Write-OK "Binary installed: $BinaryPath"
            }
            else {
                Write-Err "No .exe found in archive."
                return $false
            }
        }

        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        Write-Err "Download failed: $_"
        return $false
    }
}

# -- Network Detection --------------------------------------------------
function Get-NetworkInfo {
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Loopback|Virtual|Hyper-V|WSL|Docker|vEthernet' } | Select-Object -First 1
    if (-not $adapter) {
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
    }

    # Local IP
    $localIP = ""
    $ipObj = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($ipObj) { $localIP = $ipObj.IPAddress }

    $gwRoute = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1
    $gwIP = if ($gwRoute) { $gwRoute.NextHop } else { "" }

    # Gateway MAC via ARP (keep dash format)
    $gwMAC = ""
    if ($gwIP) {
        $arpOutput = arp -a $gwIP 2>$null
        $match = $arpOutput | Select-String "([0-9a-f]{2}-[0-9a-f]{2}-[0-9a-f]{2}-[0-9a-f]{2}-[0-9a-f]{2}-[0-9a-f]{2})"
        if ($match) {
            $gwMAC = $match.Matches[0].Value
        }
    }

    $guid = $adapter.InterfaceGuid
    $npcapGuid = "\Device\NPF_$guid"

    return @{
        AdapterName = $adapter.Name
        GUID        = $npcapGuid
        LocalIP     = $localIP
        GatewayIP   = $gwIP
        GatewayMAC  = $gwMAC
    }
}

# -- Install ------------------------------------------------------------
function Install-PaqXClient {
    # 1. Npcap check
    if (-not (Test-Npcap)) { Install-Npcap }

    # 2. Download binary
    if (-not (Get-PaqetBinary)) {
        Write-Err "Cannot continue without binary."
        return
    }

    # 3. Client config
    Write-CL ""
    Write-CL "--- Client Configuration ---" "Yellow"
    $serverAddr = Read-Host "  Server (IP:Port)"
    $key = Read-Host "  Encryption Key"

    Write-CL ""
    Write-CL "  1) Simple (Fast mode, key only - recommended)" "White"
    Write-CL "  2) Automatic (Default optimized settings)" "White"
    $mode = Read-Host "  Select [1]"
    if (-not $mode) { $mode = "1" }

    $localPort = Read-Host "  Local SOCKS5 Port [1080]"
    if (-not $localPort) { $localPort = "1080" }

    # 4. Network detection
    Write-Info "Detecting network..."
    $net = Get-NetworkInfo
    Write-OK "Adapter: $($net.AdapterName)"
    Write-OK "Local IP: $($net.LocalIP)"
    Write-OK "Gateway MAC: $($net.GatewayMAC)"

    # 5. Generate config
    if ($mode -eq "2") {
        $configContent = @"
role: "client"

log:
  level: "info"

socks5:
  - listen: "127.0.0.1:$localPort"
    username: ""
    password: ""

network:
  interface: "$($net.AdapterName)"
  guid: '$($net.GUID)'
  ipv4:
    addr: "$($net.LocalIP):0"
    router_mac: "$($net.GatewayMAC)"

  tcp:
    local_flag: ["PA"]
    remote_flag: ["PA"]

server:
  addr: "${serverAddr}"

transport:
  protocol: "kcp"
  conn: 1

  kcp:
    mode: "fast"
    nodelay: 1
    interval: 10
    resend: 2
    nocongestion: 1
    wdelay: false
    acknodelay: true
    mtu: 1350
    rcvwnd: 1024
    sndwnd: 1024
    block: "aes"
    key: "$key"
    smuxbuf: 4194304
    streambuf: 2097152
    dshard: 10
    pshard: 3
"@
    }
    else {
        # Simple mode
        $configContent = @"
role: "client"

log:
  level: "info"

socks5:
  - listen: "127.0.0.1:$localPort"
    username: ""
    password: ""

network:
  interface: "$($net.AdapterName)"
  guid: '$($net.GUID)'
  ipv4:
    addr: "$($net.LocalIP):0"
    router_mac: "$($net.GatewayMAC)"

  tcp:
    local_flag: ["PA"]
    remote_flag: ["PA"]

server:
  addr: "${serverAddr}"

transport:
  protocol: "kcp"
  conn: 1

  kcp:
    mode: "fast"
    key: "$key"
"@
    }

    Set-Content -Path $ConfigPath -Value $configContent -Encoding UTF8
    Write-OK "Config saved: $ConfigPath"

    # 6. Create Scheduled Task
    Write-Info "Creating startup task..."
    $action = New-ScheduledTaskAction -Execute $BinaryPath -Argument "run -c `"$ConfigPath`"" -WorkingDirectory $ScriptDir
    $trigger = New-ScheduledTaskTrigger -AtLogon
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

    Start-ScheduledTask -TaskName $TaskName
    Start-Sleep -Seconds 2

    Write-CL ""
    Write-OK "PaqX Client is running!"
    Write-CL ""
    Write-CL "  SOCKS5 Proxy: 127.0.0.1:$localPort" "Yellow"
    Write-CL ""
    Read-Host "Press Enter to continue"
}

# -- Dashboard ----------------------------------------------------------
function Show-Dashboard {
    while ($true) {
        # Re-read config each loop
        $srvAddr = ""
        $socksPort = ""
        if (Test-Path $ConfigPath) {
            $section = ""
            $lines = Get-Content $ConfigPath
            foreach ($line in $lines) {
                if ($line -match '^(\w+):') { $section = $Matches[1] }
                if ($section -eq "server" -and $line -match '^\s*addr:\s*"([^"]+)"') { $srvAddr = $Matches[1] }
                if ($line -match '^\s*-?\s*listen:\s*"([^"]+)"') { $socksPort = $Matches[1] }
            }
        }

        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        $isRunning = $false
        $isEnabled = $false
        if ($task) {
            $isRunning = ($task.State -eq "Running")
            $isEnabled = ($task.State -ne "Disabled")
        }

        Clear-Host
        Write-CL ""
        Write-CL "  +===============================+" "Blue"
        Write-CL "  |      PaqX Client  (Windows)   |" "Blue"
        Write-CL "  +===============================+" "Blue"
        Write-CL ""

        # Info card
        $statusText = if ($isRunning) { "Running" } else { "Stopped" }
        $statusColor = if ($isRunning) { "Green" } else { "Red" }
        $autoText = if ($isEnabled) { "Enabled" } else { "Disabled" }
        $autoColor = if ($isEnabled) { "Green" } else { "Red" }

        $maxLen = @($srvAddr.Length, $socksPort.Length, 12) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
        $cardW = $maxLen + 16
        if ($cardW -lt 42) { $cardW = 42 }
        $border = "-" * $cardW

        Write-CL "  +$border+" "Cyan"
        Write-C  "  | " "Cyan"; Write-C "Status:  " "White"; Write-C "$statusText" $statusColor; Write-C (" " * ($cardW - $statusText.Length - 11)); Write-CL "|" "Cyan"
        Write-C  "  | " "Cyan"; Write-C "Auto:    " "White"; Write-C "$autoText" $autoColor; Write-C (" " * ($cardW - $autoText.Length - 11)); Write-CL "|" "Cyan"
        Write-CL "  +$border+" "Cyan"
        Write-C  "  | " "Cyan"; Write-C "Server:  " "White"; Write-C "$srvAddr" "Yellow"; Write-C (" " * ($cardW - $srvAddr.Length - 11)); Write-CL "|" "Cyan"
        Write-C  "  | " "Cyan"; Write-C "SOCKS5:  " "White"; Write-C "$socksPort" "Yellow"; Write-C (" " * ($cardW - $socksPort.Length - 11)); Write-CL "|" "Cyan"
        Write-CL "  +$border+" "Cyan"

        Write-CL ""
        Write-CL "   1) Start"
        Write-CL "   2) Stop"
        Write-CL "   3) Restart"
        Write-CL "   4) Settings"
        Write-CL "   5) Logs"
        Write-CL "   6) Update Core"
        Write-CL "   7) Uninstall"
        Write-CL "   0) Exit"
        Write-CL ""
        $opt = Read-Host "  Select"

        switch ($opt) {
            "1" {
                Start-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
                Write-OK "Started."
                Start-Sleep -Seconds 2
            }
            "2" {
                Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
                Write-OK "Stopped."
                Start-Sleep -Seconds 2
            }
            "3" {
                Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
                Start-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
                Write-OK "Restarted."
                Start-Sleep -Seconds 2
            }
            "4" { Show-Settings }
            "5" {
                Write-CL ""
                Write-Info "Task Scheduler Info:"
                Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue | Get-ScheduledTaskInfo | Format-List
                Write-CL ""
                # Try to show process output
                $proc = Get-Process -Name "paqet" -ErrorAction SilentlyContinue
                if ($proc) {
                    Write-OK "paqet process running (PID: $($proc.Id))"
                }
                else {
                    Write-Warn "paqet process not found."
                }
                Write-CL ""
                Read-Host "Press Enter to continue"
            }
            "6" {
                Write-Info "Stopping service..."
                Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
                Stop-Process -Name "paqet" -Force -ErrorAction SilentlyContinue
                if (Get-PaqetBinary) {
                    Start-ScheduledTask -TaskName $TaskName
                    Write-OK "Updated and restarted."
                }
                Start-Sleep -Seconds 2
            }
            "7" {
                Uninstall-PaqX
                return
            }
            "0" { Exit }
        }
    }
}

# -- Settings -----------------------------------------------------------
function Show-Settings {
    while ($true) {
        Write-CL ""
        Write-CL "  --- Client Settings ---" "White"
        Write-CL "  1) Change Server (IP:Port & Key)"
        Write-CL "  2) Change Local SOCKS5 Port"
        Write-CL "  3) Change Protocol Mode"
        Write-CL "  4) View Server Info"
        Write-CL "  0) Back"
        $s = Read-Host "  Select"

        switch ($s) {
            "1" {
                $newAddr = Read-Host "  New Server (IP:Port)"
                $newKey = Read-Host "  New Encryption Key"

                $content = Get-Content $ConfigPath -Raw
                $content = $content -replace '(server:\s*\n\s*addr:\s*)"[^"]*"', "`$1`"$newAddr`""
                $content = $content -replace '(key:\s*)"[^"]*"', "`$1`"$newKey`""
                Set-Content -Path $ConfigPath -Value $content -Encoding UTF8

                Write-OK "Server config updated."
                Restart-PaqXTask
            }
            "2" {
                $newLocal = Read-Host "  New Local Port [1080]"
                if (-not $newLocal) { $newLocal = "1080" }

                $content = Get-Content $ConfigPath -Raw
                $content = $content -replace '(listen:\s*)"[^"]*"', "`$1`"127.0.0.1:$newLocal`""
                Set-Content -Path $ConfigPath -Value $content -Encoding UTF8

                Write-OK "Local port changed to $newLocal."
                Restart-PaqXTask
            }
            "3" {
                Write-CL ""
                Write-CL "  1) Simple (Fast mode, key only)" "White"
                Write-CL "  2) Automatic (Optimized defaults)" "White"
                $pm = Read-Host "  Select"

                $content = Get-Content $ConfigPath -Raw

                # Extract current key
                $curKey = ""
                if ($content -match 'key:\s*"([^"]*)"') { $curKey = $Matches[1] }

                # Extract everything before transport section
                $head = ($content -split "transport:")[0]

                if ($pm -eq "2") {
                    $transport = @"
transport:
  protocol: "kcp"
  conn: 1

  kcp:
    mode: "fast"
    nodelay: 1
    interval: 10
    resend: 2
    nocongestion: 1
    wdelay: false
    acknodelay: true
    mtu: 1350
    rcvwnd: 1024
    sndwnd: 1024
    block: "aes"
    key: "$curKey"
    smuxbuf: 4194304
    streambuf: 2097152
    dshard: 10
    pshard: 3
"@
                }
                else {
                    $transport = @"
transport:
  protocol: "kcp"
  conn: 1

  kcp:
    mode: "fast"
    key: "$curKey"
"@
                }

                Set-Content -Path $ConfigPath -Value ($head + $transport) -Encoding UTF8
                Write-OK "Protocol mode updated."
                Restart-PaqXTask
            }
            "4" {
                Write-CL ""
                $infoAddr = ""
                $infoKey = ""
                $infoSocks = ""
                if (Test-Path $ConfigPath) {
                    $sec = ""
                    foreach ($ln in (Get-Content $ConfigPath)) {
                        if ($ln -match '^(\w+):') { $sec = $Matches[1] }
                        if ($sec -eq "server" -and $ln -match '^\s*addr:\s*"([^"]+)"') { $infoAddr = $Matches[1] }
                        if ($ln -match '^\s*key:\s*"([^"]+)"') { $infoKey = $Matches[1] }
                        if ($ln -match '^\s*-?\s*listen:\s*"([^"]+)"') { $infoSocks = $Matches[1] }
                    }
                }
                Write-CL "  --- Current Server Info ---" "Yellow"
                Write-CL "  Server:   $infoAddr" "Cyan"
                Write-CL "  Key:      $infoKey" "Cyan"
                Write-CL "  SOCKS5:   $infoSocks" "Cyan"
                Write-CL ""
                Read-Host "  Press Enter to continue"
            }
            "0" { return }
            default { return }
        }
    }
}

function Restart-PaqXTask {
    Write-Info "Restarting service..."
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Stop-Process -Name "paqet" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Start-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Write-OK "Restarted."
    Start-Sleep -Seconds 1
}

# -- Uninstall ----------------------------------------------------------
function Uninstall-PaqX {
    Write-CL ""
    Write-Err "WARNING: This will COMPLETELY remove PaqX Client."
    Write-CL ""
    Write-CL "  This will remove:" "White"
    Write-CL "  - Scheduled Task ($TaskName)"
    Write-CL "  - paqet.exe binary"
    Write-CL "  - Configuration file"
    Write-CL ""
    $c = Read-Host "  Are you sure? (y/N)"
    if ($c -ne "y" -and $c -ne "Y") { return }

    Write-Info "Stopping service..."
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Stop-Process -Name "paqet" -Force -ErrorAction SilentlyContinue

    Write-Info "Removing scheduled task..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

    Write-Info "Removing files..."
    Remove-Item -Path $BinaryPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $ConfigPath -Force -ErrorAction SilentlyContinue

    Write-CL ""
    Write-OK "PaqX Client completely uninstalled."
    Start-Sleep -Seconds 3
    Exit
}

# -- Entry Point --------------------------------------------------------
Write-CL ""
if (Test-Path $ConfigPath) {
    Show-Dashboard
}
else {
    Clear-Host
    Write-CL ""
    Write-CL "  +===============================+" "Blue"
    Write-CL "  |    PaqX Client  (Windows)     |" "Blue"
    Write-CL "  +===============================+" "Blue"
    Write-CL ""
    Write-CL "  1) Install Client" "White"
    Write-CL "  0) Exit" "White"
    Write-CL ""
    $choice = Read-Host "  Select"
    if ($choice -eq "1") {
        Install-PaqXClient
        Show-Dashboard
    }
    else {
        Exit
    }
}
