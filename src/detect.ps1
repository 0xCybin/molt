# Molt detection engine. This is the "finding" half of the tool. It only ever
# LOOKS at your PC and compares what it finds against the junk list. It never
# removes anything: that is a different file (remove.ps1). Nothing here can
# change your computer.

# WHAT THIS DOES: the safety gate of the whole tool. It answers one yes/no
# question: "is this app's name EXACTLY one of the names on our junk list?"
# It only says yes on a perfect, whole-word match (upper/lowercase does not
# matter). It never says yes on a partial match. That is the promise that
# keeps "LG" from ever touching Logitech's "LGHUB": the names are not identical,
# so the answer is no.
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

# WHAT THIS DOES: opens the junk list file (data/catalog.psd1, the hand written
# list of known bloatware) and loads it into memory so the rest of the tool can
# read it. Think of it as opening the recipe book before cooking. It prefers the
# normal Windows helper for this, but if that helper is ever missing on a PC it
# falls back to reading the file as pure data (no code is ever run from the file),
# so Molt still works everywhere. The file is a data list only, never a program.
function Import-MoltCatalog {
    param([string]$Path)
    if (Get-Command Import-PowerShellDataFile -ErrorAction SilentlyContinue) {
        return Import-PowerShellDataFile -Path $Path
    }
    # Fallback: read the .psd1 as data only via the language parser. SafeGetValue
    # evaluates literals (strings, numbers, booleans, hashtables, arrays) and
    # THROWS on anything executable, so a catalog file can never run code.
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count) { throw "catalog parse error: $($errors[0].Message)" }
    $hash = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.HashtableAst] }, $false)
    if (-not $hash) { throw "catalog has no data table at $Path" }
    return $hash.SafeGetValue()
}

# WHAT THIS DOES: Windows sometimes keeps a "ghost" copy of an app that is not
# really installed for anybody (it is just staged in the background). Those
# ghosts cannot be removed because there is nothing there to remove, so if the
# tool kept flagging them it would look like the junk never goes away. This
# function throws the ghosts out and keeps only the apps a real person actually
# has installed.
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

# WHAT THIS DOES: gets the list of "Store apps" installed on the PC (the modern
# kind of app Windows installs from the Microsoft Store, which is what the LG
# Monitor App and Candy Crush are). If the tool is running as administrator it
# looks at every user account on the PC; if not, just the current one.
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

# WHAT THIS DOES: gets the list of normal installed programs (the classic kind
# you would see in "Add or remove programs", like McAfee or Wave Browser). For
# each one it grabs two things: the program's name and who made it (the
# publisher). Knowing the maker is what lets the tool safely target a program
# with a common name, because it can check the maker matches too.
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

# WHAT THIS DOES: same list of normal installed programs as above, but just the
# names without the maker. An older, simpler helper kept around so existing
# tests keep working.
function Get-InstalledUninstallNames {
    # Names-only view, kept for callers and tests that predate publisher matching.
    param([string[]]$Names)
    if ($PSBoundParameters.ContainsKey('Names')) { return $Names }
    Get-InstalledUninstallRecords | Select-Object -ExpandProperty DisplayName -Unique
}

# WHAT THIS DOES: the heart of the "finding" step. It walks down the junk list
# and, for each entry, checks whether that junk is actually on this PC right now.
# It skips any list entry not marked Verified (a safety rule: half finished
# entries can never act). For matches, it hands back a tidy summary the window
# shows you: the name, who made it, the plain description, the "keep it if" note,
# whether it should be pre-checked, and exactly which installed items matched.
# If nothing on the list is found, it hands back nothing and the window says your
# PC is clean.
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
