# Molt removal engine. Executes removals. Every path is exact-match driven by the
# findings from detect.ps1 - this file never decides WHAT to remove, only HOW.

function Test-MoltElevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltinRole]::Administrator)
}

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
