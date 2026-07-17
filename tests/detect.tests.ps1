# Molt safety tests. No Pester dependency. Exits 1 on any failure.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'src\detect.ps1')

$fail = 0
function Check($name, $cond) {
    if ($cond) { Write-Host "  PASS  $name" -ForegroundColor Green }
    else       { Write-Host "  FAIL  $name" -ForegroundColor Red; $script:fail++ }
}

Write-Host "`nTest-MoltMatch (the guardrail):"
$lg = @('LGElectronics.LGMonitorApp')
Check "exact match hits"                 (Test-MoltMatch 'LGElectronics.LGMonitorApp' $lg)
Check "case-insensitive hits"            (Test-MoltMatch 'lgelectronics.lgmonitorapp' $lg)
Check "whitespace-padded hits"           (Test-MoltMatch '  LGElectronics.LGMonitorApp ' $lg)
Check "LGHUB (Logitech) is NOT matched"  (-not (Test-MoltMatch 'LGHUB' $lg))
Check "Logitech G HUB is NOT matched"    (-not (Test-MoltMatch 'Logitech G HUB' $lg))
Check "prefix is NOT matched"            (-not (Test-MoltMatch 'LGElectronics.LGMonitorApp.Companion' $lg))
Check "substring is NOT matched"         (-not (Test-MoltMatch 'MyLGElectronics.LGMonitorApp' $lg))
Check "empty candidate is NOT matched"   (-not (Test-MoltMatch '' $lg))
Check "null candidate is NOT matched"    (-not (Test-MoltMatch $null $lg))
Check "empty target list is NOT matched" (-not (Test-MoltMatch 'anything' @()))

Write-Host "`nCatalog integrity:"
$catalog = Import-MoltCatalog -Path (Join-Path $root 'data\catalog.psd1')
Check "catalog loads"                    ($null -ne $catalog -and $catalog.Entries.Count -ge 1)
Check "LG entry is verified"             (($catalog.Entries | Where-Object Id -eq 'lg-monitor-app').Verified -eq $true)
$ids = $catalog.Entries.Id
Check "entry ids are unique"             (($ids | Sort-Object -Unique).Count -eq $ids.Count)
foreach ($e in $catalog.Entries) {
    if ($e.Verified) {
        $hasTarget = ($e.Detect.Appx.Count + $e.Detect.Uninstall.Count) -ge 1
        Check "verified entry '$($e.Id)' has >=1 detect target" $hasTarget
        Check "verified entry '$($e.Id)' has a name and honest What text" (($e.Name.Trim().Length -ge 3) -and ($e.What.Trim().Length -ge 30))
    }
}

Write-Host "`nCatalog structure (exact-match promise):"
$allTargets = @()
$allPairs   = @()
foreach ($e in $catalog.Entries) {
    $allTargets += $e.Detect.Appx; $allTargets += $e.Detect.Uninstall
    if ($e.Detect.ContainsKey('UninstallWithPublisher')) { $allPairs += $e.Detect.UninstallWithPublisher }
}
# A wildcard or regex char in a target would quietly widen the match surface somewhere.
$wild = @($allTargets | Where-Object { $_ -match '[\*\?\[\]]' })
Check "no target contains wildcard characters" ($wild.Count -eq 0)
$wildP = @($allPairs | Where-Object { ($_.Name + $_.Publisher) -match '[\*\?\[\]]' })
Check "no publisher pair contains wildcard characters" ($wildP.Count -eq 0)
foreach ($p in $allPairs) {
    Check "pair '$($p.Name)' always carries a publisher" (-not [string]::IsNullOrWhiteSpace($p.Publisher))
}
$short = @($allTargets | Where-Object { $_.Trim().Length -lt 4 })
Check "no target is a dangerously short string" ($short.Count -eq 0)
# The house style law: no em or en dashes anywhere users can read.
$dashHits = @($catalog.Entries | Where-Object { ($_.Name + $_.What + $_.KeepIf) -match [char]0x2013 -or ($_.Name + $_.What + $_.KeepIf) -match [char]0x2014 })
Check "no em or en dashes in any catalog text" ($dashHits.Count -eq 0)

Write-Host "`nHonesty guardrails (things we must NEVER match):"
# Real names that live on real PCs right next to our targets. If any of these ever
# match, the catalog has betrayed the exact-match promise.
$sacred = @(
    'Logitech G HUB'                          # the LG trap, forever
    'LGHUB'
    'Dell Update for Windows Universal'       # real updaters stay
    'Dell Command | Update'
    'Intel(R) Driver & Support Assistant'     # legit, despite 'Driver Support' being a target
    'Waves MaxxAudio Pro'                     # legit OEM audio, despite 'Wave Browser' being a target
    'MSTeams'                                 # the CURRENT Teams. only the dead 'MicrosoftTeams' goes
    'Microsoft.WindowsStore'
    'Microsoft.DesktopAppInstaller'           # winget
    'Microsoft.SecHealthUI'                   # Windows Security UI
    'Microsoft.WindowsCalculator'
    'Microsoft.Windows.Photos'
    'Microsoft.WindowsCamera'
    'Microsoft.WindowsNotepad'
    'Microsoft.WindowsTerminal'
    'Microsoft.ScreenSketch'                  # Snipping Tool
    'Microsoft.ZuneMusic'                     # Media Player, despite the legacy name
    'Microsoft.OneDriveSync'
    'Microsoft OneDrive'
    'Microsoft.MicrosoftEdge.Stable'
    'MicrosoftWindows.Client.CBS'             # OS shell plumbing
    'Microsoft.Windows.ShellExperienceHost'   # the Windows shell itself
    'Microsoft.Windows.StartMenuExperienceHost'
    'Microsoft.AAD.BrokerPlugin'              # sign-in broker
    'NVIDIACorp.NVIDIAControlPanel'
    'AdvancedMicroDevicesInc-2.AMDRadeonSoftware'
    'RealtekSemiconductorCorp.RealtekAudioControl'
    'Microsoft.BingWeather'                   # the Weather app people actually use
    'AD2F1837.HPSupportAssistant'             # HP's real support/update tool, deliberately off-list
    'MSI Afterburner'                         # beloved, despite MSI Center being a target
    'Armoury Crate'                           # deliberately not listed (gamers depend on it)
    'MicrosoftCorporationII.WindowsSubsystemForLinux'  # WSL, one word from the dead WSA
    'Online Security'                         # only allowed WITH a publisher, never by name alone
    'McAfee'                                  # bare brand names must never be targets
    'Dell'
    'Norton'
)
foreach ($s in $sacred) {
    Check "'$s' is never a target" (-not (Test-MoltMatch $s $allTargets))
}

Write-Host "`nGet-MoltFindings (scan logic on fake machines):"
# A messy real-world machine: junk AND its lookalike neighbors side by side.
$findings = @(Get-MoltFindings -Catalog $catalog `
    -AppxNames @('LGElectronics.LGMonitorApp','LGHUB','5A894077.McAfeeSecurity','Microsoft.WindowsStore','Microsoft.Copilot','Microsoft.SkypeApp','MSTeams','MicrosoftTeams','BytedancePte.Ltd.TikTok','Microsoft.SecHealthUI','B9ECED6F.MyASUS','9426MICRO-STARINTERNATION.MSICenter','MicrosoftCorporationII.WindowsSubsystemForAndroid','MicrosoftCorporationII.WindowsSubsystemForLinux') `
    -UninstallNames @('Logitech G HUB','Dell SupportAssist','Dell Update for Windows Universal','Google Chrome','Wave Browser','Waves MaxxAudio Pro','Driver Support','Intel(R) Driver & Support Assistant','OneLaunch','Norton 360','Bing Wallpaper','ASUS GIFTBOX','MSI Afterburner','Armoury Crate'))
Check "finds the LG app"                 ($findings.Id -contains 'lg-monitor-app')
Check "finds McAfee"                     ($findings.Id -contains 'mcafee')
Check "finds Dell SupportAssist"         ($findings.Id -contains 'dell-supportassist')
Check "finds Copilot"                    ($findings.Id -contains 'ms-copilot')
Check "finds dead apps (Skype + old Teams)" (($findings | Where-Object Id -eq 'ms-dead-apps').AppxHits -contains 'Microsoft.SkypeApp')
Check "finds Wave Browser"               ($findings.Id -contains 'wave-browser')
Check "finds OneLaunch"                  ($findings.Id -contains 'onelaunch')
Check "finds Norton trial"               ($findings.Id -contains 'norton-trial')
Check "finds Bing Wallpaper"             ($findings.Id -contains 'bing-wallpaper')
Check "finds driver updater junk"        ($findings.Id -contains 'driver-updater-scamware')
Check "finds TikTok stub"                ($findings.Id -contains 'sponsored-social-stubs')
Check "does NOT flag Dell's updater"     (-not ($findings | ForEach-Object { $_.UninstallHits } | Where-Object { $_ -eq 'Dell Update for Windows Universal' }))
Check "does NOT flag Logitech anything"  (-not ($findings | Where-Object { $_.AppxHits -contains 'LGHUB' -or $_.UninstallHits -contains 'Logitech G HUB' }))
Check "does NOT flag Waves MaxxAudio"    (-not ($findings | ForEach-Object { $_.UninstallHits } | Where-Object { $_ -eq 'Waves MaxxAudio Pro' }))
Check "does NOT flag Intel's assistant"  (-not ($findings | ForEach-Object { $_.UninstallHits } | Where-Object { $_ -eq 'Intel(R) Driver & Support Assistant' }))
Check "does NOT flag the new Teams"      (-not ($findings | ForEach-Object { $_.AppxHits } | Where-Object { $_ -eq 'MSTeams' }))
Check "does NOT flag Windows Security"   (-not ($findings | ForEach-Object { $_.AppxHits } | Where-Object { $_ -eq 'Microsoft.SecHealthUI' }))
Check "old dead Teams IS flagged"        (($findings | Where-Object Id -eq 'ms-dead-apps').AppxHits -contains 'MicrosoftTeams')
Check "LG finding carries only exact hit"(($findings | Where-Object Id -eq 'lg-monitor-app').AppxHits -eq 'LGElectronics.LGMonitorApp')
Check "finds ASUS GiftBox"               ($findings.Id -contains 'asus-giftbox')
Check "finds MyASUS (unchecked group)"   ($findings.Id -contains 'asus-extras')
Check "finds MSI Center"                 ($findings.Id -contains 'msi-center')
Check "dead WSA IS flagged"              (($findings | Where-Object Id -eq 'ms-dead-apps').AppxHits -contains 'MicrosoftCorporationII.WindowsSubsystemForAndroid')
Check "WSL is NEVER flagged"             (-not ($findings | ForEach-Object { $_.AppxHits } | Where-Object { $_ -eq 'MicrosoftCorporationII.WindowsSubsystemForLinux' }))
Check "MSI Afterburner is NEVER flagged" (-not ($findings | ForEach-Object { $_.UninstallHits } | Where-Object { $_ -eq 'MSI Afterburner' }))
Check "Armoury Crate is NEVER flagged"   (-not ($findings | ForEach-Object { $_.UninstallHits } | Where-Object { $_ -eq 'Armoury Crate' }))

Write-Host "`nStaged-ghost filter (Select-MoltInstalledPkgs):"
# -AllUsers returns 'Staged' copies owned by nobody. Flagging those loops
# forever (removal cannot end a state no user has), so the scanner drops them.
$mk = { param($name, $states) [pscustomobject]@{ Name=$name; PackageUserInformation=@($states | ForEach-Object { [pscustomobject]@{ InstallState=$_ } }) } }
$kept = @(@(
    (& $mk 'InstalledApp' @('Installed'))
    (& $mk 'StagedGhost'  @('Staged'))
    (& $mk 'MixedApp'     @('Staged','Installed'))
    [pscustomobject]@{ Name='CurrentUserView'; PackageUserInformation=@() }
) | Select-MoltInstalledPkgs | ForEach-Object Name)
Check "installed package kept"            ($kept -contains 'InstalledApp')
Check "staged-for-nobody ghost dropped"   (-not ($kept -contains 'StagedGhost'))
Check "mixed staged+installed kept"       ($kept -contains 'MixedApp')
Check "current-user view (no info) kept"  ($kept -contains 'CurrentUserView')

Write-Host "`nPublisher-scoped matching (the Online Security rail):"
$recs = @(
    [pscustomobject]@{ DisplayName='Online Security'; Publisher='ReasonLabs' }
    [pscustomobject]@{ DisplayName='Google Chrome';  Publisher='Google LLC' }
)
$pubFind = @(Get-MoltFindings -Catalog $catalog -AppxNames @() -UninstallRecords $recs)
$rav = $pubFind | Where-Object Id -eq 'rav-reasonlabs'
Check "right publisher: Online Security matches"        ($rav.UninstallHits -contains 'Online Security')
Check "finding carries the matched publisher"           ($rav.UninstallPublishers['Online Security'] -eq 'ReasonLabs')
$wrongPub = @(Get-MoltFindings -Catalog $catalog -AppxNames @() -UninstallRecords @(
    [pscustomobject]@{ DisplayName='Online Security'; Publisher='Bitdefender SRL' }
))
Check "wrong publisher: Online Security never matches"  (-not ($wrongPub | Where-Object Id -eq 'rav-reasonlabs'))
$noPub = @(Get-MoltFindings -Catalog $catalog -AppxNames @() -UninstallRecords @(
    [pscustomobject]@{ DisplayName='Online Security'; Publisher='' }
))
Check "blank publisher: Online Security never matches"  (-not ($noPub | Where-Object Id -eq 'rav-reasonlabs'))

# Recommend defaults: the risky ones must arrive unchecked.
foreach ($riskyId in 'ms-xbox','ms-optional-apps','sponsored-streaming-stubs','ms-quick-assist','alienware-command-center','expressvpn-preload','ms-widgets','asus-extras','msi-center') {
    $entry = $catalog.Entries | Where-Object Id -eq $riskyId
    Check "'$riskyId' is unchecked by default" ($entry.Recommend -eq $false)
}

# Clean machine -> no findings
$clean = @(Get-MoltFindings -Catalog $catalog -AppxNames @('Microsoft.WindowsStore') -UninstallNames @('7-Zip'))
Check "clean machine yields no findings" ($clean.Count -eq 0)

# Unverified entries must NEVER surface, even when their target is 'installed'.
$fakeCatalog = @{ Version=99; Entries=@(
    @{ Id='experimental'; Name='X'; Publisher='?'; What=''; KeepIf=''; Recommend=$true; Verified=$false;
       Detect=@{ Appx=@('Contoso.Experimental'); Uninstall=@() } }
) }
$exp = @(Get-MoltFindings -Catalog $fakeCatalog -AppxNames @('Contoso.Experimental') -UninstallNames @())
Check "unverified entry never surfaces even when installed" ($exp.Count -eq 0)

Write-Host ""
if ($fail -gt 0) { Write-Host "$fail check(s) FAILED" -ForegroundColor Red; exit 1 }
Write-Host "All checks passed." -ForegroundColor Green
exit 0
