# Molt removal engine. This is the "removing" half. It only ever acts on the
# exact items the finding step already matched against the junk list. It never
# decides WHAT to remove on its own, only HOW to remove what was handed to it.

# WHAT THIS DOES: checks whether the tool is running with administrator power.
# Administrator is needed to remove apps for every user account and to change
# the protection settings. Returns a simple yes or no.
function Test-MoltElevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltinRole]::Administrator)
}

# WHAT THIS DOES: looks up a single Store app by name and reports the real,
# currently installed copies of it. The finding step, the removal step, and the
# "did it actually go away" check all use this same lookup, so they always agree
# with each other. Using one shared answer is what stopped the old bug where an
# app looked removed but came back on the next scan.
function Get-MoltLivePkgs {
    # The one instrument for "is this appx really on this PC": same view for
    # detection, removal targeting, and post-removal verification. Elevated =
    # all users, filtered to copies a real user actually has (needs detect.ps1's
    # Select-MoltInstalledPkgs, which Molt always loads first).
    param([Parameter(Mandatory)][string]$Name)
    if (Test-MoltElevated) {
        @(Get-AppxPackage -AllUsers -Name $Name -ErrorAction SilentlyContinue | Select-MoltInstalledPkgs)
    } else {
        @(Get-AppxPackage -Name $Name -ErrorAction SilentlyContinue)
    }
}

# WHAT THIS DOES: removes one Store app (like the LG Monitor App or Candy Crush).
# In preview mode it only says what it WOULD do and touches nothing. Otherwise it
# uninstalls the app for every user if it can, tells Windows not to hand that app
# to brand new accounts either, and then checks again to confirm it is really
# gone. It reports back one of: would-remove, not-found, removed, failed, or error.
function Remove-MoltAppx {
    param([Parameter(Mandatory)][string]$Name, [switch]$WhatIf)
    if ($WhatIf) { return [pscustomobject]@{ Target=$Name; Kind='appx'; Status='would-remove' } }
    try {
        $pkgs = Get-MoltLivePkgs -Name $Name
        if (-not $pkgs.Count) { return [pscustomobject]@{ Target=$Name; Kind='appx'; Status='not-found' } }
        $allUsers = Test-MoltElevated
        foreach ($p in $pkgs) {
            Remove-AppxPackage -Package $p.PackageFullName -AllUsers:$allUsers -ErrorAction Stop
        }
        # deprovision so it cannot seed new profiles (best-effort, elevated only)
        if ($allUsers) {
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -ieq $Name } |
                ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }
        }
        # verify with the SAME instrument the scanner uses. Anything less and a
        # partial failure reports 'removed' today and reappears at the next scan.
        $still = Get-MoltLivePkgs -Name $Name
        $st = if (-not $still.Count) { 'removed' } else { 'failed' }
        [pscustomobject]@{ Target=$Name; Kind='appx'; Status=$st }
    } catch {
        [pscustomobject]@{ Target=$Name; Kind='appx'; Status='error'; Detail="$_" }
    }
}

# WHAT THIS DOES: finds the Windows record for one normal installed program by
# its exact name, so the tool can read that program's own official uninstaller.
# If a maker name is also given, the record's maker must match too. That double
# check is the safety rail for programs with common names: it makes sure the tool
# only ever grabs the exact bad program, not an innocent one that shares a name.
function Get-MoltUninstallEntry {
    # Exact DisplayName -> registry uninstall record (or $null).
    # When -Publisher is given, the record's Publisher must ALSO match exactly.
    # That is the safety rail for generic-sounding names ('Online Security').
    param([Parameter(Mandatory)][string]$DisplayName, [string]$Publisher)
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    Get-ItemProperty $keys -ErrorAction SilentlyContinue |
        Where-Object {
            $_.DisplayName -and ($_.DisplayName.Trim() -ieq $DisplayName.Trim()) -and
            (-not $Publisher -or ([string]$_.Publisher).Trim() -ieq $Publisher.Trim())
        } |
        Select-Object -First 1
}

# WHAT THIS DOES: actually runs a program's own built-in uninstaller, the same
# one that runs when you remove it from "Add or remove programs". It asks it to
# run quietly without popups and without forcing a restart where possible, waits
# for it to finish, and reports whether it succeeded. Molt does not delete these
# programs itself, it politely asks each program to uninstall itself.
function Invoke-MoltUninstallString {
    param([string]$CommandLine)
    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return $false }
    # MSI product: force silent + no reboot regardless of how it was registered.
    if ($CommandLine -match '(?i)msiexec' -and $CommandLine -match '\{[0-9A-Fa-f\-]{36}\}') {
        $guid = $Matches[0]
        $p = Start-Process msiexec.exe -ArgumentList "/x $guid /qn /norestart" -Wait -PassThru
        return ($p.ExitCode -in 0, 1605, 1614, 3010, 1641)
    }
    # EXE uninstaller: split quoted exe from its args, then run and wait.
    if     ($CommandLine -match '^\s*"([^"]+)"\s*(.*)$') { $exe = $Matches[1]; $rest = $Matches[2] }
    elseif ($CommandLine -match '^\s*(\S+)\s*(.*)$')     { $exe = $Matches[1]; $rest = $Matches[2] }
    else { return $false }
    $splat = @{ FilePath = $exe; Wait = $true; PassThru = $true }
    if ($rest.Trim()) { $splat.ArgumentList = $rest }
    $p = Start-Process @splat
    return ($p.ExitCode -in 0, 1605, 1614, 3010, 1641)
}

# WHAT THIS DOES: removes one normal installed program (like McAfee or Wave
# Browser). It finds the program's record, and in preview mode just says what it
# would do. Otherwise it runs that program's own uninstaller, then checks whether
# the program is really gone, and reports back: would-remove, not-found, removed,
# failed, or error.
function Remove-MoltWin32 {
    param([Parameter(Mandatory)][string]$DisplayName, [string]$Publisher, [switch]$WhatIf)
    $entry = Get-MoltUninstallEntry -DisplayName $DisplayName -Publisher $Publisher
    if (-not $entry) { return [pscustomobject]@{ Target=$DisplayName; Kind='win32'; Status='not-found' } }
    if ($WhatIf)     { return [pscustomobject]@{ Target=$DisplayName; Kind='win32'; Status='would-remove' } }
    try {
        # Prefer the vendor's own silent string; fall back to the normal one.
        $cmd = if ($entry.QuietUninstallString) { $entry.QuietUninstallString } else { $entry.UninstallString }
        $ok  = Invoke-MoltUninstallString -CommandLine $cmd
        $still = Get-MoltUninstallEntry -DisplayName $DisplayName -Publisher $Publisher
        $status = if (-not $still) { 'removed' } elseif ($ok) { 'removed' } else { 'failed' }
        [pscustomobject]@{ Target=$DisplayName; Kind='win32'; Status=$status }
    } catch {
        [pscustomobject]@{ Target=$DisplayName; Kind='win32'; Status='error'; Detail="$_" }
    }
}

# WHAT THIS DOES: the conductor for removals. You give it the list of things you
# ticked in the window, and it removes each one by calling the right helper
# (Store app or normal program) for every exact match. It collects what happened
# to each and hands back a per item report the results screen shows you.
function Invoke-MoltRemoval {
    # Takes selected findings (from Get-MoltFindings) and removes their exact hits.
    param([Parameter(Mandatory)]$Findings, [switch]$WhatIf)
    foreach ($f in $Findings) {
        $results = @()
        $pubMap = $null
        if ($f.PSObject.Properties['UninstallPublishers']) { $pubMap = $f.UninstallPublishers }
        foreach ($a in @($f.AppxHits)) { $results += Remove-MoltAppx -Name $a -WhatIf:$WhatIf }
        foreach ($u in @($f.UninstallHits)) {
            $pub = if ($pubMap -and $pubMap[$u]) { $pubMap[$u] } else { '' }
            $results += Remove-MoltWin32 -DisplayName $u -Publisher $pub -WhatIf:$WhatIf
        }
        [pscustomobject]@{ Id=$f.Id; Name=$f.Name; Results=$results }
    }
}
