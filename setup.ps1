if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as Administrator!"
    Exit
}

Write-Host "thank you for using Sen's setup script." -ForegroundColor Yellow
Write-Host "this will eliminate some microsoft bs and install my preferred applications" -ForegroundColor Red
Write-Host "---------------------------------------------------------------------------" -ForegroundColor Red

function Show-Menu {
    param (
        [string]$Title = 'Menu'
    )
    Write-Host "================ $Title ================"
    Write-Host "Y: Yes"
    Write-Host "N: No"
    Write-Host "Q: Quit"
}

function Get-UserConfirmation {
    param (
        [string]$Message
    )
    
    do {
        Write-Host "$Message (Y/N/Q): " -ForegroundColor Yellow -NoNewline
        $response = Read-Host
        $response = $response.ToUpper()
        if ($response -eq 'Q') {
            Write-Host "quitting..." -ForegroundColor Red
            Exit
        }
    } until ($response -eq 'Y' -or $response -eq 'N')
    
    return $response -eq 'Y'
}

function Enable-WindowsFeature {
    param (
        [string]$FeatureName,
        [string]$DisplayName
    )
    
    Write-Host "checking if $DisplayName is enabled..." -ForegroundColor DarkRed
    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName
    
    if ($feature.State -eq "Enabled") {
        Write-Host "$DisplayName is already enabled." -ForegroundColor Green
    } else {
        Write-Host "enabling $DisplayName... (This might take a few minutes)" -ForegroundColor Yellow
        Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -NoRestart -WarningAction SilentlyContinue | Out-Null
        Write-Host "$DisplayName has been enabled." -ForegroundColor Green
    }
}

function Install-WinGet {
    Write-Host "WinGet not found. attempting to install..." -ForegroundColor Yellow
    
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10 -or ($osVersion.Major -eq 10 -and $osVersion.Build -lt 17763)) {
        Write-Host "WinGet requires Windows 10 1809 or later. please fucking update your OS." -ForegroundColor Red
        return $false
    }
    
    try {
        $apiUrl = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "PowerShell Script")
        $releaseInfo = $webClient.DownloadString($apiUrl) | ConvertFrom-Json
        
        $msixAsset = $releaseInfo.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1
        
        if ($msixAsset) {
            $downloadUrl = $msixAsset.browser_download_url
            $downloadPath = "$env:TEMP\WinGet.msixbundle"
            
            Write-Host "downloading WinGet installer..." -ForegroundColor Yellow
            $webClient.DownloadFile($downloadUrl, $downloadPath)
            
            Write-Host "installing WinGet..." -ForegroundColor Yellow
            Add-AppxPackage -Path $downloadPath
            
            $wingetCheck = Get-Command winget -ErrorAction SilentlyContinue
            if ($wingetCheck) {
                Write-Host "WinGet has been successfully installed." -ForegroundColor Green
                return $true
            } else {
                Write-Host "WinGet installation failed. please install manually from the M*cros*ft St*re." -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "could not find the WinGet installer package. please install manually from the M*cros*ft St*re." -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "error installing WinGet: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "please install WinGet manually from the M*cros*ft St*re." -ForegroundColor Red
        return $false
    }
}

function Test-WinGet {
    $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetPath) {
        return Install-WinGet
    }
    
    Write-Host "WinGet is installed: " -ForegroundColor Green -NoNewline
    try {
        $wingetVersion = (winget --version) 2>&1
        Write-Host "$wingetVersion" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "unable to determine version" -ForegroundColor Yellow
        return $true
    }
}

function Show-AsciiHeader {
    param (
        [string]$HeaderText
    )
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host " $HeaderText" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
}

function Remove-PreInstalledPackages {
    param (
        [array]$Packages
    )
    foreach ($package in $Packages) {
        Write-Host "removing $package..." -ForegroundColor DarkRed
        try {
            Get-AppxPackage -Name $package | Remove-AppxPackage -ErrorAction SilentlyContinue
            Write-Host "successfully removed $package." -ForegroundColor Green
        } catch {
            Write-Host "failed to remove $package $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

if (Get-UserConfirmation "do you want to configure privacy settings and disable telemetry?") {
    Write-Host "configuring privacy settings and disabling telemetry..." -ForegroundColor Red
    
    $registryPaths = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection",
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}",
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo",
        "HKCU:\SOFTWARE\Microsoft\Siuf\Rules"
    )

    foreach ($path in $registryPaths) {
        if (-Not (Test-Path $path)) {
            Write-Host "creating registry path: $path" -ForegroundColor DarkYellow
            New-Item -Path $path -Force | Out-Null
        }
    }
    
    Write-Host "setting telemetry to 0..." -ForegroundColor DarkRed
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0
    
    Write-Host "disabling app tracking..." -ForegroundColor DarkRed
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackProgs" -Type DWord -Value 0
    
    Write-Host "disabling location tracking..." -ForegroundColor DarkRed
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Type String -Value "Deny"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Type DWord -Value 0
    
    Write-Host "disabling activity history..." -ForegroundColor DarkRed
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Type DWord -Value 0
    
    Write-Host "disabling tailored experiences..." -ForegroundColor DarkRed
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Type DWord -Value 0
    
    Write-Host "disabling advertising ID..." -ForegroundColor DarkRed
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Type DWord -Value 0
    
    Write-Host "disabling feedback..." -ForegroundColor DarkRed
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Type DWord -Value 0
    
    Write-Host "disabling Windows Error Reporting..." -ForegroundColor DarkRed
    if (-Not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Type DWord -Value 1
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Windows Error Reporting\QueueReporting" -ErrorAction SilentlyContinue | Out-Null
    
    Write-Host "disabling diagnostic tracking services..." -ForegroundColor DarkRed
    Set-Service DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue
    Set-Service dmwappushservice -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue
    Stop-Service dmwappushservice -Force -ErrorAction SilentlyContinue
    
    Write-Host "disabling Wi-Fi Sense..." -ForegroundColor DarkRed
    if (-Not (Test-Path "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting")) {
        New-Item -Path "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" -Name "Value" -Type DWord -Value 0
    
    if (-Not (Test-Path "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots")) {
        New-Item -Path "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots" -Name "Value" -Type DWord -Value 0
    
    Write-Host "privacy settings configured successfully." -ForegroundColor Green
} else {
    Write-Host "skipping privacy configuration." -ForegroundColor DarkGray
}

if (Get-UserConfirmation "do you want to set Dark Mode for Windows?") {
    Write-Host "setting Dark Mode..." -ForegroundColor Green
    
    if (-Not (Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize")) {
        New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Force | Out-Null
    }
    
    Write-Host "setting apps to dark theme..." -ForegroundColor DarkRed
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Type DWord -Value 0
    
    Write-Host "setting system to dark theme..." -ForegroundColor DarkRed
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Type DWord -Value 0
    
    Write-Host "dark Mode set successfully." -ForegroundColor Green
} else {
    Write-Host "skipping Dark Mode configuration." -ForegroundColor DarkGray
}

if (Get-UserConfirmation "do you want to configure taskbar settings?") {
    Write-Host "configuring taskbar settings..." -ForegroundColor Green
    
    $registryPaths = @(
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
    )

    foreach ($path in $registryPaths) {
        if (-Not (Test-Path $path)) {
            Write-Host "creating registry path: $path" -ForegroundColor DarkYellow
            New-Item -Path $path -Force | Out-Null
        }
    }
    
    Write-Host "setting taskbar alignment to left..." -ForegroundColor DarkRed
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Type DWord -Value 0
    
    Write-Host "hiding search bar..." -ForegroundColor DarkRed
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Type DWord -Value 0

    Write-Host "showing all tray icons..." -ForegroundColor DarkRed
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Type DWord -Value 0

    Write-Host "snoozing notifications..." -ForegroundColor DarkRed
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -Type DWord -Value 0
    
    Write-Host "taskbar settings configured successfully." -ForegroundColor Green
} else {
    Write-Host "skipping taskbar configuration." -ForegroundColor DarkGray
}

if (Get-UserConfirmation "do you want to configure File Explorer settings?") {
    Write-Host "configuring File Explorer settings..." -ForegroundColor Green
    
    if (-Not (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced")) {
        New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Force | Out-Null
    }
    
    Write-Host "setting Explorer to open to This PC..." -ForegroundColor DarkRed
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Type DWord -Value 1
    
    Write-Host "showing file extensions..." -ForegroundColor DarkRed
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Type DWord -Value 0
    
    Write-Host "showing hidden files..." -ForegroundColor DarkRed
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Type DWord -Value 1
    
    Write-Host "file Explorer settings configured successfully." -ForegroundColor Green
} else {
    Write-Host "skipping File Explorer configuration." -ForegroundColor DarkGray
}

if (Get-UserConfirmation "do you want to disable mouse acceleration?") {
    Write-Host "disabling mouse acceleration..." -ForegroundColor Green
    
    if (-Not (Test-Path "HKCU:\Control Panel\Mouse")) {
        New-Item -Path "HKCU:\Control Panel\Mouse" -Force | Out-Null
    }
    
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Type String -Value "0"
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Type String -Value "0"
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Type String -Value "0"
    
    Write-Host "mouse acceleration disabled successfully." -ForegroundColor Green
} else {
    Write-Host "skipping mouse acceleration configuration." -ForegroundColor DarkGray
}

if (Get-UserConfirmation "do you want to hide desktop icons?") {
    Write-Host "hiding desktop icons..." -ForegroundColor Green
    
    if (-Not (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced")) {
        New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Force | Out-Null
    }
    
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideIcons" -Type DWord -Value 1
    
    Write-Host "desktop icons hidden successfully." -ForegroundColor Green
} else {
    Write-Host "skipping desktop icons configuration." -ForegroundColor DarkGray
}

if (Get-UserConfirmation "do you want to enable verbose startup and shutdown messages?") {
    Write-Host "enabling verbose startup and shutdown messages..." -ForegroundColor Green
    
    if (-Not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Force | Out-Null
    }
    
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -Type DWord -Value 1
    
    Write-Host "verbose startup and shutdown messages enabled successfully." -ForegroundColor Green
} else {
    Write-Host "skipping verbose messages configuration." -ForegroundColor DarkGray
}

if (Get-UserConfirmation "do you want to enable Hyper-V and WSL features?") {
    Write-Host "enabling Windows Features..." -ForegroundColor Green
    
    Enable-WindowsFeature -FeatureName "Microsoft-Hyper-V-All" -DisplayName "Hyper-V"
    
    Enable-WindowsFeature -FeatureName "Microsoft-Windows-Subsystem-Linux" -DisplayName "Windows Subsystem for Linux"
    
    Enable-WindowsFeature -FeatureName "VirtualMachinePlatform" -DisplayName "Virtual Machine Platform"
    
    Write-Host "windows features enabled successfully." -ForegroundColor Green
    Write-Host "note: a system restart might be required for these changes to take effect." -ForegroundColor Yellow
} else {
    Write-Host "Skipping Windows Features configuration." -ForegroundColor DarkGray
}

if (Get-UserConfirmation "do you want to apply system tweaks and remove pre-installed packages?") {
    Show-AsciiHeader "System Tweaks and Privacy Configuration"

    Write-Host "applying privacy tweaks..." -ForegroundColor Green

    Show-AsciiHeader "removing bullshit"
    $packagesToRemove = @(
        "Microsoft.Edge",
        "Microsoft.Teams",
        "Microsoft.BingNews_8wekyb3d8bbwe",
        "Microsoft.BingSearch_8wekyb3d8bbwe",
        "Microsoft.BingWeather_8wekyb3d8bbwe",
        "Microsoft.Copilot_8wekyb3d8bbwe",
        "Microsoft.GetHelp_8wekyb3d8bbwe",
        "Microsoft.MicrosoftEdge.Stable_8wekyb3d8bbwe",
        "Microsoft.PowerAutomateDesktop_8wekyb3d8bbwe",
        "Microsoft.Todos_8wekyb3d8bbwe",
        "Microsoft.YourPhone_8wekyb3d8bbwe"
    )
    Remove-PreInstalledPackages -Packages $packagesToRemove

    Show-AsciiHeader "restarting Explorer"
    Write-Host "restarting Explorer to apply changes..." -ForegroundColor Yellow
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
    Write-Host "explorer restarted successfully." -ForegroundColor Green
} else {
    Write-Host "skipping system tweaks and package removal." -ForegroundColor DarkGray
}

if (Get-UserConfirmation "do you want to install applications using winget?") {
    Show-AsciiHeader "application Installation"
    Write-Host "preparing to install applications..." -ForegroundColor Green
    
    $wingetInstalled = Test-WinGet
    
    if (-not $wingetInstalled) {
        Write-Host "cannot proceed with application installation without WinGet." -ForegroundColor Red
    } else {
        $apps = @(
            "7zip.7zip",
            "Audacity.Audacity",
            "Bitwarden.Bitwarden",
            "BartoszCichecki.LenovoLegionToolkit",
            "Cisco.PlayGames.Beta",
            "CrystalRich.LockHunter",
            "Discord.Discord",
            "dotPDN.PaintDotNet",
            "Fastfetch-cli.Fastfetch",
            "Flameshot.Flameshot",
            "PeterPawlowski.foobar2000",
            "Git.Git",
            "GitHub.GitHubDesktop",
            "goatcorp.XIVLauncher",
            "Google.Chrome",
            "Gyan.FFmpeg",
            "JanDeDobbeleer.OhMyPosh",
            "Microsoft.DevHome",
            "Microsoft.DotNet.DesktopRuntime.8",
            "Microsoft.OneDrive",
            "Microsoft.PowerToys",
            "Microsoft.VisualStudioCode",
            "Microsoft.VCRedist.2015+.x64",
            "Microsoft.VCRedist.2015+.x86",
            "Microsoft.VCLibs.Desktop.14",
            "Microsoft.WSL",
            "Mozilla.Firefox",
            "Nefarius.HidHide",
            "OBSProject.OBSStudio",
            "Ollama.Ollama",
            "PrismLauncher.PrismLauncher",
            "qBittorrent.qBittorrent",
            "Valve.Steam",
            "Telegram.TelegramDesktop",
            "VideoLAN.VLC",
            "ViGEm.ViGEmBus",
            "Cemu.Cemu",
            "Debian.Debian"
        )
        
        Write-Host "will install $($apps.Count) applications." -ForegroundColor Yellow
        Write-Host "this process may take some time. each application will be installed one by one." -ForegroundColor Yellow
        
        $successCount = 0
        $failCount = 0
        
        foreach ($app in $apps) {
            Write-Host "installing $app..." -ForegroundColor DarkRed
            try {
                winget install --id $app --silent --accept-source-agreements --accept-package-agreements -e
                Write-Host "successfully installed $app." -ForegroundColor Green
                $successCount++
            } catch {
                Write-Host "failed to install $app $($_.Exception.Message)" -ForegroundColor Red
                $failCount++
            }
        }
        
        Write-Host "application installation completed." -ForegroundColor Green
        Write-Host "summary: $successCount applications installed successfully, $failCount failed." -ForegroundColor Yellow
    }
} else {
    Write-Host "skipping application installation." -ForegroundColor DarkGray
}

Write-Host "windows setup script completed!" -ForegroundColor Red
Write-Host "some changes may require a system restart to take effect." -ForegroundColor Yellow

if (Get-UserConfirmation "would you like to restart explorer.exe to apply some changes now?") {
    Write-Host "restarting Explorer..." -ForegroundColor Yellow
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
    Write-Host "explorer restarted." -ForegroundColor Green
}

if (Get-UserConfirmation "would you like to restart your computer now?") {
    Write-Host "restarting puter" -ForegroundColor Yellow
    Restart-Computer -Force
} else {
    Write-Host "remember to restart your computer later to complete all changes." -ForegroundColor Yellow
}
