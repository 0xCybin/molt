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

# WHAT THIS DOES: checks whether Molt is already running with administrator
# power. It needs admin to remove apps for every account and to set the
# protections, which is why the very next block asks Windows for it.
function Test-Elevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltinRole]::Administrator)
}

# This block is what pops the "do you want to allow this app to make changes"
# Windows prompt. If Molt is not already admin, it relaunches itself as admin
# (carrying the same options). If you click No, it keeps running with what it has.
# Self-elevate so all-users removal + the HKLM lock actually work.
if (-not (Test-Elevated) -and -not $NoElevate) {
    # NOTE: the path is wrapped in quotes on purpose. Start-Process joins these
    # args with plain spaces and adds no quoting of its own, so an unquoted path
    # that contains a space (e.g. C:\Users\First Last\...) would reach the elevated
    # PowerShell as "-File C:\Users\First", which cannot be found and closes at
    # once, before Molt's window ever shows. Do not remove the quotes.
    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File', ('"{0}"' -f $PSCommandPath))
    if ($WhatIf) { $argList += '-WhatIf' }
    if ($Undo)   { $argList += '-Undo' }
    if ($Demo)   { $argList += '-Demo' }
    try   { Start-Process powershell.exe -Verb RunAs -ArgumentList $argList | Out-Null; exit }
    catch { }  # user declined UAC - fall through and run with what we've got
}

# SAFETY NET: if anything below throws, show the error in a message box instead
# of letting the window vanish. A user reported the elevated Molt closing the
# instant it opened, with no message at all, which made the real cause (a space
# in the path) impossible to see or report. Now it speaks up. This covers the
# scan, the protection settings, and building the window.
trap {
    try { Add-Type -AssemblyName PresentationFramework -ErrorAction Stop } catch { }
    $reportUrl = 'https://github.com/0xCybin/molt/issues'
    $text = "Molt ran into a problem and could not finish:`n`n$($_.Exception.Message)`n`nThis is a bug, not something you did. Please report it at $reportUrl so it can be fixed."
    try   { [void][System.Windows.MessageBox]::Show($text, 'Molt', 'OK', 'Error') }
    catch { Write-Host $text; [void](Read-Host "`nPress Enter to close") }
    exit 1
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

# WHAT THIS DOES: builds a fake, made up list of findings for the -Demo mode, so
# the window can be shown off (in a screenshot or a quick look) without scanning a
# real PC and without removing anything. These are examples only, not real results.
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

# This is the actual start of a normal run, the few lines that tie it together:
# in demo mode use the fake examples, otherwise load the junk list and scan this
# PC for real matches. Then check which protections are already on, and finally
# hand it all to the window to show you. Everything from here is your decision.
if ($Demo) {
    $findings = Get-DemoFindings
} else {
    $catalog  = Import-MoltCatalog -Path (Join-Path $here 'data\catalog.psd1')
    $findings = @(Get-MoltFindings -Catalog $catalog)
}
$lockState = Get-MoltLockdownState

Show-MoltGui -Findings $findings -Lockdown $lockState -WhatIf:$WhatIf -Demo:$Demo -AppRoot $here
