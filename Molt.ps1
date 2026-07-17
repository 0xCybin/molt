#requires -version 5.1
<#
  Molt: remove bloatware, scamware and preloaded junk, then lock Windows so it stays gone.
  by Cybin. Readable on purpose. this is an anti junk tool, so nothing is hidden.

  Usage:
    Run.bat            double-click. scans, shows a checklist, you approve, it cleans.
    Undo.bat           puts the Windows protections back to default.
    Molt.ps1 -WhatIf  preview only, changes nothing.
    Molt.ps1 -Demo    show the UI populated with sample items (safe, removes nothing real).
#>
param(
    [switch]$WhatIf,
    [switch]$Undo,
    [switch]$Demo,
    [switch]$NoElevate
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $PSCommandPath

function Test-Elevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltinRole]::Administrator)
}

# Self-elevate so all-users removal + the HKLM lock actually work.
if (-not (Test-Elevated) -and -not $NoElevate) {
    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File', $PSCommandPath)
    if ($WhatIf) { $argList += '-WhatIf' }
    if ($Undo)   { $argList += '-Undo' }
    if ($Demo)   { $argList += '-Demo' }
    try   { Start-Process powershell.exe -Verb RunAs -ArgumentList $argList | Out-Null; exit }
    catch { }  # user declined UAC - fall through and run with what we've got
}

. (Join-Path $here 'src\detect.ps1')
. (Join-Path $here 'src\remove.ps1')
. (Join-Path $here 'src\lockdown.ps1')
. (Join-Path $here 'src\gui.ps1')

if ($Undo) {
    $msg = (Undo-MoltLockdown) -join "`n"
    Add-Type -AssemblyName PresentationFramework
    [void][Windows.MessageBox]::Show("$msg`n`nWindows auto-install and suggestion settings are back to default.", 'Molt', 'OK', 'Information')
    return
}

function Get-DemoFindings {
    @(
        [pscustomobject]@{ Id='lg-monitor-app'; Name='LG Monitor App'; Publisher='LG Electronics'
            What='Installs itself silently when you plug in an LG monitor, then shows McAfee popup ads and asks for broad access to your system and data. You do not need it to use the monitor.'
            KeepIf='You actually use LG''s OnScreen Control / Screen Split features (uncommon).'
            Recommend=$true; AppxHits=@('LGElectronics.LGMonitorApp'); UninstallHits=@() }
        [pscustomobject]@{ Id='wave-browser'; Name='Wave Browser'; Publisher='Wavesor / Eightpoint'
            What='A look-alike Chrome that sneaks in through bundled installers and tracks browsing. Flagged as a PUP by every major security vendor.'
            KeepIf=''
            Recommend=$true; AppxHits=@(); UninstallHits=@('Wave Browser') }
        [pscustomobject]@{ Id='mcafee'; Name='McAfee (preinstalled trial)'; Publisher='McAfee'
            What='Preinstalled McAfee trial and the "Scam Detector" popup the LG app pushes. Nags for paid upgrades. This is trialware, not antivirus you chose and paid for.'
            KeepIf='You actually pay for and use a McAfee subscription.'
            Recommend=$true; AppxHits=@('5A894077.McAfeeSecurity'); UninstallHits=@() }
        [pscustomobject]@{ Id='ms-dead-apps'; Name='dead Microsoft apps'; Publisher='Microsoft'
            What='Apps Microsoft itself has shut down or abandoned, still sitting on your PC: Skype, the old Mail and Calendar, Maps and friends. They do nothing useful anymore.'
            KeepIf=''
            Recommend=$true; AppxHits=@('Microsoft.SkypeApp','microsoft.windowscommunicationsapps','Microsoft.WindowsMaps'); UninstallHits=@() }
        [pscustomobject]@{ Id='ms-copilot'; Name='Copilot'; Publisher='Microsoft'
            What='The Copilot AI chat app Microsoft pushed onto PCs through Windows Update. Removing it does not break anything else, and it reinstalls free from the Store.'
            KeepIf='you actually use Copilot.'
            Recommend=$true; AppxHits=@('Microsoft.Copilot'); UninstallHits=@() }
        [pscustomobject]@{ Id='alienware-command-center'; Name='Alienware Command Center'; Publisher='Dell / Alienware'
            What='Alienware''s RGB lighting, fan and performance control app. Genuinely useful if you own Alienware gear, so this one is unchecked by default.'
            KeepIf='You use it to control Alienware lighting, fan curves, or overclock profiles.'
            Recommend=$false; AppxHits=@(); UninstallHits=@('Alienware Command Center') }
    )
}

if ($Demo) {
    $findings = Get-DemoFindings
} else {
    $catalog  = Import-MoltCatalog -Path (Join-Path $here 'data\catalog.psd1')
    $findings = @(Get-MoltFindings -Catalog $catalog)
}
$lockState = Get-MoltLockdownState

Show-MoltGui -Findings $findings -Lockdown $lockState -WhatIf:$WhatIf -Demo:$Demo -AppRoot $here
