# Molt lockdown engine. The "so it never comes back" half. Fully reversible.

$script:MoltDeviceMeta   = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata'
$script:MoltDeviceMetaPol= 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata'
$script:MoltCdm          = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
$script:MoltExplorerAdv  = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

# The documented ContentDeliveryManager "suggestions" family: Start menu suggestions,
# tips and tricks, Settings ad panels, the after-update welcome pitch. Deliberately
# NOT touched: RotatingLockScreenEnabled (that is the Spotlight wallpaper people like)
# and ContentDeliveryAllowed (a master switch, too broad for an honest toggle).
$script:MoltAdKeys = @(
    'SubscribedContent-310093Enabled'   # welcome experience after updates
    'SubscribedContent-338388Enabled'   # Start menu suggestions
    'SubscribedContent-338389Enabled'   # tips, tricks and suggestions
    'SubscribedContent-338393Enabled'   # suggested content in Settings
    'SubscribedContent-353694Enabled'   # suggested content in Settings
    'SubscribedContent-353696Enabled'   # suggested content in Settings
    'SubscribedContent-353698Enabled'   # timeline suggestions
    'SystemPaneSuggestionsEnabled'      # Start pane suggestions
    'SoftLandingEnabled'                # tips pop-ups
)

function Get-MoltRegDword {
    param([string]$Path, [string]$Name)
    (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
}

function Get-MoltLockdownState {
    # Returns whether each protection is currently ON, for the UI checkboxes.
    [pscustomobject]@{
        # ON when metadata auto-download is blocked (value = 1)
        BlockMonitorAutoInstall = ((Get-MoltRegDword $script:MoltDeviceMeta 'PreventDeviceMetadataFromNetwork') -eq 1)
        # ON when silent Store installs are disabled (value = 0)
        BlockSilentStoreApps    = ((Get-MoltRegDword $script:MoltCdm 'SilentInstalledAppsEnabled') -eq 0)
        # ON when the two flagship suggestion feeds are disabled (value = 0)
        BlockStartAds           = (((Get-MoltRegDword $script:MoltCdm 'SubscribedContent-338388Enabled') -eq 0) -and
                                   ((Get-MoltRegDword $script:MoltCdm 'SubscribedContent-338389Enabled') -eq 0))
    }
}

function Set-MoltLockdown {
    # Applies the protections the user left checked. HKLM parts require elevation.
    param([switch]$BlockMonitorAutoInstall, [switch]$BlockSilentStoreApps, [switch]$BlockStartAds, [switch]$WhatIf)
    $done = @()
    if ($BlockMonitorAutoInstall) {
        if ($WhatIf) { $done += 'would block monitor/device auto-install' }
        else {
            try {
                # -ErrorAction Stop matters: unelevated, the HKLM write raises a
                # NON-terminating SecurityException that would sail past the catch
                # and let us report success on a write that never happened.
                foreach ($p in @($script:MoltDeviceMeta, $script:MoltDeviceMetaPol)) {
                    if (-not (Test-Path $p)) { New-Item -Path $p -Force -ErrorAction Stop | Out-Null }
                    New-ItemProperty -Path $p -Name 'PreventDeviceMetadataFromNetwork' -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
                }
                $done += 'blocked monitor/device auto-install'
            } catch {
                $done += 'could NOT block monitor auto-install (needs administrator. re-run and click Yes at the prompt)'
            }
        }
    }
    if ($BlockSilentStoreApps) {
        if ($WhatIf) { $done += 'would block silent Store-app installs' }
        else {
            if (-not (Test-Path $script:MoltCdm)) { New-Item -Path $script:MoltCdm -Force | Out-Null }
            New-ItemProperty -Path $script:MoltCdm -Name 'SilentInstalledAppsEnabled' -Value 0 -PropertyType DWord -Force | Out-Null
            New-ItemProperty -Path $script:MoltCdm -Name 'PreInstalledAppsEnabled'   -Value 0 -PropertyType DWord -Force | Out-Null
            $done += 'blocked silent Store-app installs'
        }
    }
    if ($BlockStartAds) {
        if ($WhatIf) { $done += 'would turn off Start menu and Settings ad suggestions' }
        else {
            if (-not (Test-Path $script:MoltCdm)) { New-Item -Path $script:MoltCdm -Force | Out-Null }
            foreach ($k in $script:MoltAdKeys) {
                New-ItemProperty -Path $script:MoltCdm -Name $k -Value 0 -PropertyType DWord -Force | Out-Null
            }
            if (-not (Test-Path $script:MoltExplorerAdv)) { New-Item -Path $script:MoltExplorerAdv -Force | Out-Null }
            New-ItemProperty -Path $script:MoltExplorerAdv -Name 'Start_IrisRecommendations' -Value 0 -PropertyType DWord -Force | Out-Null
            $done += 'turned off Start menu and Settings ad suggestions'
        }
    }
    $done
}

function Undo-MoltLockdown {
    # Puts Windows back to its defaults (auto-download on, suggestions on).
    param([switch]$WhatIf)
    if ($WhatIf) { return @('would restore Windows defaults') }
    foreach ($p in @($script:MoltDeviceMeta, $script:MoltDeviceMetaPol)) {
        if (Test-Path $p) { Remove-ItemProperty -Path $p -Name 'PreventDeviceMetadataFromNetwork' -ErrorAction SilentlyContinue }
    }
    if (Test-Path $script:MoltCdm) {
        New-ItemProperty -Path $script:MoltCdm -Name 'SilentInstalledAppsEnabled' -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $script:MoltCdm -Name 'PreInstalledAppsEnabled'   -Value 1 -PropertyType DWord -Force | Out-Null
        foreach ($k in $script:MoltAdKeys) {
            New-ItemProperty -Path $script:MoltCdm -Name $k -Value 1 -PropertyType DWord -Force | Out-Null
        }
    }
    if (Test-Path $script:MoltExplorerAdv) {
        New-ItemProperty -Path $script:MoltExplorerAdv -Name 'Start_IrisRecommendations' -Value 1 -PropertyType DWord -Force | Out-Null
    }
    @('restored Windows defaults')
}
