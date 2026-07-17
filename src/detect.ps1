# Molt detection engine. Pure, testable. No side effects, no removal here.

function Test-MoltMatch {
    # EXACT, case-insensitive, full-string equality against a list of targets.
    # Deliberately NOT substring/prefix/regex: that is the guarantee that a target
    # of 'LGElectronics.LGMonitorApp' can never match Logitech's 'LGHUB'.
    param(
        [string]   $Candidate,
        [string[]] $Targets
    )
    if ([string]::IsNullOrWhiteSpace($Candidate)) { return $false }
    if (-not $Targets) { return $false }
    $c = $Candidate.Trim()
    foreach ($t in $Targets) {
        if (-not [string]::IsNullOrWhiteSpace($t) -and $c -ieq $t.Trim()) { return $true }
    }
    return $false
}

function Import-MoltCatalog {
    param([string]$Path)
    $data = Import-PowerShellDataFile -Path $Path
    return $data
}

function Select-MoltInstalledPkgs {
    # Keep only packages actually INSTALLED for at least one real user.
    # Get-AppxPackage -AllUsers also returns 'Staged' ghost copies owned by
    # nobody; flagging those loops forever, because removal cannot end a state
    # that no user has. A user-facing scanner counts what users actually have.
    param([Parameter(ValueFromPipeline)]$Pkg)
    process {
        if (-not $Pkg) { return }
        $info = @($Pkg.PackageUserInformation)
        if (-not $info.Count) { $Pkg; return }   # no user info available: keep (current-user view)
        $installed = @($info | Where-Object { "$($_.InstallState)" -match 'Installed' })
        if ($installed.Count) { $Pkg }
    }
}

function Get-InstalledAppxNames {
    # Overridable in tests via -Names.
    # When elevated, scan every user's packages so detection sees exactly what
    # removal (-AllUsers) can reach. Falls back to current user when not admin.
    param([string[]]$Names)
    if ($PSBoundParameters.ContainsKey('Names')) { return $Names }
    $pkgs = $null
    try   { $pkgs = Get-AppxPackage -AllUsers -ErrorAction Stop | Select-MoltInstalledPkgs }
    catch { $pkgs = Get-AppxPackage -ErrorAction SilentlyContinue }
    $pkgs | Select-Object -ExpandProperty Name -Unique
}

function Get-InstalledUninstallRecords {
    # Every uninstall registry record as {DisplayName, Publisher}. The Publisher
    # field is what lets a generic-sounding name (ReasonLabs' 'Online Security')
    # be targeted safely: those entries only match name AND publisher together.
    param($Records)
    if ($PSBoundParameters.ContainsKey('Records')) { return $Records }
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    Get-ItemProperty $keys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName } |
        ForEach-Object { [pscustomobject]@{ DisplayName = $_.DisplayName; Publisher = [string]$_.Publisher } }
}

function Get-InstalledUninstallNames {
    # Names-only view, kept for callers and tests that predate publisher matching.
    param([string[]]$Names)
    if ($PSBoundParameters.ContainsKey('Names')) { return $Names }
    Get-InstalledUninstallRecords | Select-Object -ExpandProperty DisplayName -Unique
}

function Get-MoltFindings {
    # Returns one object per catalog entry that is BOTH verified AND currently present.
    param(
        $Catalog,
        [string[]]$AppxNames,      # for tests
        [string[]]$UninstallNames, # for tests (plain names, no publisher)
        $UninstallRecords          # for tests ({DisplayName, Publisher} objects)
    )
    $appx = if ($PSBoundParameters.ContainsKey('AppxNames')) { $AppxNames } else { Get-InstalledAppxNames }
    $records =
        if     ($PSBoundParameters.ContainsKey('UninstallRecords')) { @($UninstallRecords) }
        elseif ($PSBoundParameters.ContainsKey('UninstallNames'))   { @($UninstallNames | ForEach-Object { [pscustomobject]@{ DisplayName = $_; Publisher = '' } }) }
        else                                                        { @(Get-InstalledUninstallRecords) }

    foreach ($e in $Catalog.Entries) {
        if (-not $e.Verified) { continue }  # never act on unverified entries
        $hitAppx = @($appx | Where-Object { Test-MoltMatch $_ $e.Detect.Appx })
        $hitUn   = @($records | Where-Object { Test-MoltMatch $_.DisplayName $e.Detect.Uninstall } |
                     Select-Object -ExpandProperty DisplayName -Unique)

        # Publisher-scoped targets: BOTH the display name AND the publisher must
        # match exactly. This is the only way a generic name is ever allowed in.
        $hitPub  = @{}
        if ($e.Detect.ContainsKey('UninstallWithPublisher')) {
            foreach ($pair in $e.Detect.UninstallWithPublisher) {
                foreach ($r in $records) {
                    if ((Test-MoltMatch $r.DisplayName @($pair.Name)) -and (Test-MoltMatch $r.Publisher @($pair.Publisher))) {
                        if (-not ($hitUn -contains $r.DisplayName)) { $hitUn += $r.DisplayName }
                        $hitPub[$r.DisplayName] = $pair.Publisher
                    }
                }
            }
        }

        if ($hitAppx.Count -or $hitUn.Count) {
            [pscustomobject]@{
                Id                  = $e.Id
                Name                = $e.Name
                Publisher           = $e.Publisher
                What                = $e.What
                KeepIf              = $e.KeepIf
                Recommend           = [bool]$e.Recommend
                AppxHits            = $hitAppx
                UninstallHits       = $hitUn
                UninstallPublishers = $hitPub
            }
        }
    }
}
