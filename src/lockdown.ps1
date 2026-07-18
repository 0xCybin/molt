# Molt lockdown engine. This is the "so it never comes back" half. It flips a few
# Windows settings so the junk cannot silently reinstall itself later. Every one
# of these settings can be flipped straight back (that is what Undo.bat does), so
# nothing here is permanent. These are the same switches buried deep in Windows
# settings menus; Molt just gathers them in one place.

# These four lines are the exact Windows settings locations (registry paths) the
# switches live at. Plain readers can ignore them: they are just addresses.
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

# WHAT THIS DOES: reads one Windows setting and returns its current value (or
# nothing if it has never been set). A small helper the checks below rely on.
function Get-MoltRegDword {
    param([string]$Path, [string]$Name)
    (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
}

# WHAT THIS DOES: checks whether each of the three protections is currently
# turned on, so the window can show the switches already flipped for anything you
# have set before. Returns a simple on/off for each of the three.
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

# WHAT THIS DOES: turns ON whichever of the three protections you left checked.
# Switch one stops Windows auto installing a maker's app when you plug in a
# device (this is the switch that stops the LG situation). Switch two stops
# Windows quietly dropping sponsored apps on you. Switch three turns off the
# "suggested" app ads in your Start menu and Settings. In preview mode it only
# says what it would do. It returns a plain list of what it changed.
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

# WHAT THIS DOES: the reverse of the switches above. It puts all three Windows
# settings back exactly the way Windows had them by default (auto install on,
# sponsored apps on, suggestions on). This is what runs when someone double
# clicks Undo.bat. Nothing Molt locks down is permanent.
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
