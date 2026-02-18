<#
.SYNOPSIS
PaqX Manager for Windows - Universal Setup Script

.DESCRIPTION
Installs and configures PaqX (based on Paqet) on Windows.
Requires PowerShell running as Administrator.
#>

# Ensure running as Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run as Administrator!" -ForegroundColor Red
    Start-Sleep -Seconds 2
    Exit
}

$RepoOwner = "hanselime"
$RepoName = "paqet"
$InstallDir = "C:\Program Files\PaqX"
$BinaryPath = "$InstallDir\paqet.exe"
$ConfigPath = "$InstallDir\config.yaml"
$Version = "3.0.0"

# --- Helper Functions ---

function Check-Npcap {
    Write-Host "Checking for Npcap..." -ForegroundColor Cyan
    if (Test-Path "C:\Windows\System32\Npcap" -PathType Container) {
        Write-Host "Npcap detected." -ForegroundColor Green
        return $true
    } else {
        Write-Host "Npcap NOT found!" -ForegroundColor Red
        Write-Host "Please install Npcap from https://npcap.com/dist/npcap-1.75.exe" -ForegroundColor Yellow
        Write-Host "Ensure 'Install Npcap in WinPcap API-compatible Mode' is CHECKED during install."
        return $false
    }
}

function Download-Binary {
    Write-Host "Downloading Paqet..." -ForegroundColor Cyan
    $Url = "https://github.com/$RepoOwner/$RepoName/releases/download/$Version/paqet-windows-amd64-$Version.zip"
    $ZipPath = "$env:TEMP\paqet.zip"
    
    try {
        Invoke-WebRequest -Uri $Url -OutFile $ZipPath
        Expand-Archive -Path $ZipPath -DestinationPath "$env:TEMP\paqet_extract" -Force
        
        $ExtractedBin = Get-ChildItem -Path "$env:TEMP\paqet_extract" -Recurse -Filter "paqet.exe" | Select-Object -First 1
        if ($ExtractedBin) {
            New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
            Move-Item -Path $ExtractedBin.FullName -Destination $BinaryPath -Force
            Write-Host "Installed to $BinaryPath" -ForegroundColor Green
        } else {
            Write-Error "Binary not found in zip."
        }
    } catch {
        Write-Error "Failed to download: $_"
    }
}

function Install-Client {
    if (-not (Check-Npcap)) { return }
    
    Download-Binary
    
    Write-Host "`n--- Client Configuration ---" -ForegroundColor Yellow
    $ServerIP = Read-Host "Enter Server IP"
    $ServerPort = Read-Host "Enter Server Port"
    $Key = Read-Host "Enter Encryption Key"
    
    # Network Info
    $Interface = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
    $Gateway = Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Select-Object -First 1
    $GatewayIP = $Gateway.NextHop
    # Get Gateway MAC via ARP
    $GatewayMAC = (arp -a $GatewayIP | Select-String "$GatewayIP\s+([0-9a-f-]{17})" | ForEach-Object { $_.Matches.Groups[1].Value }) -replace '-', ':'
    
    $Guid = $Interface.InterfaceGuid
    $NpcapGuid = "\Device\NPF_$Guid"
    
    $ConfigContent = @"
role: "client"
log:
  level: "info"
socks5:
  - listen: "127.0.0.1:1080"
network:
  # GUID for Npcap on Windows
  guid: "$NpcapGuid"
  ipv4:
    addr: "0.0.0.0:0"
    router_mac: "$GatewayMAC"
server:
  addr: "$ServerIP:$ServerPort"
transport:
  protocol: "kcp"
  kcp:
    mode: "fast"
    key: "$Key"
"@
    Set-Content -Path $ConfigPath -Value $ConfigContent
    Write-Host "Config saved to $ConfigPath" -ForegroundColor Green
    
    # Create Scheduled Task for persistence (Service is harder without nssm)
    $Action = New-ScheduledTaskAction -Execute $BinaryPath -Argument "run -c `"$ConfigPath`""
    $Trigger = New-ScheduledTaskTrigger -AtLogon
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName "PaqX_Client" -Action $Action -Trigger $Trigger -Principal $Principal -Force
    
    Start-ScheduledTask -TaskName "PaqX_Client"
    Write-Host "PaqX Client Started (Scheduled Task)" -ForegroundColor Green
}

function Show-Menu {
    Clear-Host
    Write-Host "=== PAQX MANAGER (WINDOWS) ===" -ForegroundColor Cyan
    Write-Host "1. Install Client"
    Write-Host "2. Start Service"
    Write-Host "3. Stop Service"
    Write-Host "4. Uninstall"
    Write-Host "0. Exit"
    
    $Choice = Read-Host "Select Option"
    switch ($Choice) {
        "1" { Install-Client }
        "2" { Start-ScheduledTask -TaskName "PaqX_Client"; Write-Host "Started." }
        "3" { Stop-ScheduledTask -TaskName "PaqX_Client"; Write-Host "Stopped." }
        "4" { 
            Unregister-ScheduledTask -TaskName "PaqX_Client" -Confirm:$false
            Remove-Item -Path $InstallDir -Recurse -Force
            Write-Host "Uninstalled."
        }
        "0" { Exit }
    }
    Pause
}

# Loop
while ($true) { Show-Menu }
