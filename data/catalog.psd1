@{
    # Molt bloatware catalog. Data only, no logic.
    # An entry is ONLY ever acted on when Verified = $true. Unverified entries are
    # ignored by the scanner, so a half-researched identifier can never remove anything.
    # Matching is EXACT, case-insensitive, full-string. Never substring. That is what
    # keeps "LG" from ever touching Logitech G HUB (LGHUB).
    # Recommend = $true means the checkbox is pre-ticked. Set $false for things a real
    # owner might legitimately want (so we never nudge someone into removing something useful).
    Version = 4
    Entries = @(

        # ---------- the original offenders ----------
        @{
            Id        = 'lg-monitor-app'
            Name      = 'LG Monitor App'
            Publisher = 'LG Electronics'
            What      = 'Installs itself silently when you plug in an LG monitor, then shows McAfee popup ads and asks for broad access to your system and data. You do not need it to use the monitor.'
            KeepIf    = 'You actually use LG''s OnScreen Control / Screen Split window features (uncommon).'
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @('LGElectronics.LGMonitorApp')
                Uninstall = @()
            }
        }
        @{
            Id        = 'mcafee'
            Name      = 'McAfee (preinstalled trial)'
            Publisher = 'McAfee'
            What      = 'Preinstalled McAfee trial and the "Scam Detector" popup the LG app pushes. Nags for paid upgrades. This is trialware, not antivirus you chose and paid for. Windows Defender takes over the moment it is gone.'
            KeepIf    = 'You actually pay for and use a McAfee subscription.'
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @('5A894077.McAfeeSecurity', 'McAfeeWPSSparsePackage')
                Uninstall = @('McAfee Security', 'McAfee Scam Detector', 'McAfee LiveSafe', 'McAfee WebAdvisor', 'McAfee Total Protection')
            }
        }
        @{
            Id        = 'norton-trial'
            Name      = 'Norton (preinstalled trial)'
            Publisher = 'Norton / Gen Digital'
            What      = 'The Norton trial many laptops ship with. Constant renewal popups and scare notifications until you pay. Windows Defender takes over once it is gone. Norton''s uninstaller is known to leave crumbs behind; if you want every trace gone afterward, Norton''s own "Remove and Reinstall" tool finishes the job.'
            KeepIf    = 'You actually pay for a Norton subscription.'
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @()
                Uninstall = @('Norton 360', 'Norton Security', 'Norton Internet Security', 'Norton Security Ultra', 'Norton Security Scan')
            }
        }

        # ---------- scamware and sneakware (the stuff that infects people) ----------
        @{
            Id        = 'onelaunch'
            Name      = 'OneLaunch'
            Publisher = 'OneLaunch Technologies'
            What      = 'An ad toolbar and search hijacker that rides in bundled with free downloads. Docks itself to the top of your screen, redirects searches through its own engine, and starts with Windows. Widely flagged as adware. It can leave scheduled tasks behind, so a free scan with something like Malwarebytes after removal is a good idea.'
            KeepIf    = 'you knowingly installed it and like it (rare).'
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @()
                Uninstall = @('OneLaunch')
            }
        }
        @{
            Id        = 'wave-browser'
            Name      = 'Wave Browser'
            Publisher = 'Wavesor / Eightpoint'
            What      = 'A look-alike Chrome that sneaks in through bundled installers and tracks browsing. Flagged as a PUP by every major security vendor. It is known to plant scheduled tasks that try to reinstall it, so if it ever reappears after removal, run a free security scan to clear the leftovers.'
            KeepIf    = ''
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @()
                Uninstall = @('Wave Browser', 'WaveBrowser')
            }
        }
        @{
            Id        = 'rav-reasonlabs'
            Name      = 'RAV antivirus (ReasonLabs)'
            Publisher = 'ReasonLabs'
            What      = 'An "antivirus" that appears after installing free games, cracked software, or driver tools, because it was bundled in the installer. Most people never chose it. It runs heavy background services and pushes paid upgrades. If it also planted an extension inside your browser, remove that from the browser''s own extensions page.'
            KeepIf    = 'you knowingly bought a ReasonLabs subscription.'
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @()
                Uninstall = @('RAV Endpoint Protection', 'RAV VPN', 'Safer Web', 'Reason Cybersecurity', 'Reason Labs', 'Reason Security')
                # 'Online Security' is ReasonLabs' real uninstall name, but the bare
                # phrase is too generic to trust alone. These only match when the
                # registry publisher ALSO matches exactly. Wrong publisher = no match.
                UninstallWithPublisher = @(
                    @{ Name = 'Online Security'; Publisher = 'ReasonLabs' }
                    @{ Name = 'Online Security'; Publisher = 'Reason Cybersecurity Inc.' }
                    @{ Name = 'Online Security'; Publisher = 'Reason Cybersecurity' }
                    @{ Name = 'Online Security'; Publisher = 'Reason Labs' }
                )
            }
        }
        @{
            Id        = 'fake-pc-fixers'
            Name      = 'Restoro / Reimage "PC repair"'
            Publisher = 'Restoro / Reimage'
            What      = 'Scareware cleaners that "find" hundreds of problems and then charge to fix them. The FTC fined these two $26 million in 2024 for tricking people, especially older people, with fake scan results and fake Microsoft popups.'
            KeepIf    = ''
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @()
                Uninstall = @('Restoro', 'Reimage Repair', 'PC Scan & Repair by Reimage')
            }
        }
        @{
            Id        = 'driver-updater-scamware'
            Name      = 'driver updater junk'
            Publisher = 'various'
            What      = 'Pay-to-fix "driver updater" tools that use scary scan results to sell subscriptions. You do not need any of them: Windows Update already delivers drivers, and your GPU has its own updater. These arrive bundled with free downloads and nag forever.'
            KeepIf    = ''
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @()
                Uninstall = @('WinZip Driver Updater', 'Outbyte Driver Updater', 'Driver Support', 'Driver Support One', 'PC HelpSoft Driver Updater')
            }
        }
        @{
            Id        = 'bing-wallpaper'
            Name      = 'Bing Wallpaper'
            Publisher = 'Microsoft'
            What      = 'Looks like a harmless daily-wallpaper app, but researchers caught it decrypting cookies from other browsers, bundling a geolocation API, pushing the Bing extension into Chrome, and nagging you to switch to Edge. A wallpaper app does not need any of that.'
            KeepIf    = 'you want the daily Bing photo enough to accept the tracking.'
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @()
                Uninstall = @('Bing Wallpaper')
            }
        }
        @{
            Id        = 'wildtangent'
            Name      = 'WildTangent Games'
            Publisher = 'WildTangent'
            What      = 'A game store preloaded on HP, Dell and other machines. Free-trial games with ads and upsells. Not connected to Steam, Xbox, or any game you installed yourself.'
            KeepIf    = 'you actually play its games.'
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @()
                Uninstall = @('WildTangent Games', 'WildTangent Games App (HP Games)', 'WildTangent Games App for HP')
            }
        }
        @{
            Id        = 'expressvpn-preload'
            Name      = 'ExpressVPN (preloaded trial)'
            Publisher = 'ExpressVPN'
            What      = 'HP ships this VPN trial on many consumer PCs. The app itself is legit, but if you did not choose it, it is just another trial nagging you to subscribe. Unchecked by default because plenty of people do pay for it.'
            KeepIf    = 'you have an ExpressVPN subscription.'
            Recommend = $false
            Verified  = $true
            Detect    = @{
                Appx      = @()
                Uninstall = @('ExpressVPN')
            }
        }

        # ---------- Microsoft: dead and abandoned ----------
        @{
            Id        = 'ms-dead-apps'
            Name      = 'dead Microsoft apps'
            Publisher = 'Microsoft'
            What      = 'Apps Microsoft itself has shut down or abandoned, still sitting on your PC: Cortana, Skype (service closed May 2025), the old Mail and Calendar (retired end of 2024), Maps, People, 3D Viewer, Print 3D, Mixed Reality Portal, Dev Home, the Android subsystem (support ended March 2025, and it takes real gigabytes), the old Xbox companion and the old Teams. They do nothing useful anymore, and some still run background tasks.'
            KeepIf    = ''
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @('Microsoft.549981C3F5F10', 'Microsoft.SkypeApp', 'microsoft.windowscommunicationsapps', 'Microsoft.People', 'Microsoft.WindowsMaps', 'Microsoft.Microsoft3DViewer', 'Microsoft.3DBuilder', 'Microsoft.Print3D', 'Microsoft.MixedReality.Portal', 'Microsoft.Messaging', 'Microsoft.OneConnect', 'Microsoft.Windows.DevHome', 'MicrosoftCorporationII.WindowsSubsystemForAndroid', 'Microsoft.XboxApp', 'MicrosoftTeams')
                Uninstall = @()
            }
        }

        # ---------- Microsoft: ads, feeds, and promo ----------
        @{
            Id        = 'ms-promo-apps'
            Name      = 'Microsoft promo and feed apps'
            Publisher = 'Microsoft'
            What      = 'The ad-and-news layer Windows ships with: Bing News, Bing Search, the MSN feed engine behind Widgets, the Tips app, the Microsoft 365 nag hub (a storefront, NOT your installed Word or Excel, which are untouched), the AI Hub, M365 Companions, and Microsoft''s own PC Manager cleaner. None of it is needed for Windows to work.'
            KeepIf    = 'you read the MSN news feed or open any of these on purpose.'
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @('Microsoft.BingNews', 'Microsoft.News', 'Microsoft.BingSearch', 'Microsoft.Getstarted', 'Microsoft.StartExperiencesApp', 'Microsoft.MicrosoftOfficeHub', 'Microsoft.Windows.AIHub', 'Microsoft.M365Companions', 'Microsoft.PCManager')
                Uninstall = @()
            }
        }
        @{
            Id        = 'ms-copilot'
            Name      = 'Copilot'
            Publisher = 'Microsoft'
            What      = 'The Copilot AI chat app Microsoft pushed onto PCs through Windows Update. Removing the app does not break anything else in Windows, and it reinstalls free from the Store if you ever want it back.'
            KeepIf    = 'you actually use Copilot.'
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @('Microsoft.Copilot')
                Uninstall = @()
            }
        }
        @{
            Id        = 'ms-background-extras'
            Name      = 'Microsoft background extras'
            Publisher = 'Microsoft'
            What      = 'Feedback Hub (for sending bug reports to Microsoft) and Power Automate (desktop automation that installed itself via Windows Update). Fine tools, but if you have never opened them they are just weight.'
            KeepIf    = 'you send Windows feedback or have built Power Automate flows.'
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @('Microsoft.WindowsFeedbackHub', 'Microsoft.PowerAutomateDesktop')
                Uninstall = @()
            }
        }
        @{
            Id        = 'ms-quick-assist'
            Name      = 'Quick Assist'
            Publisher = 'Microsoft'
            What      = 'Lets someone control your PC remotely. Genuinely useful when family or IT help you, but it is also the number one tool phone scammers use ("let me connect to fix your computer"). If nobody you trust helps you through it, removing it closes that door. Unchecked by default; think before ticking.'
            KeepIf    = 'someone you trust uses it to help you remotely.'
            Recommend = $false
            Verified  = $true
            Detect    = @{
                Appx      = @('MicrosoftCorporationII.QuickAssist')
                Uninstall = @()
            }
        }
        @{
            Id        = 'ms-optional-apps'
            Name      = 'Microsoft apps you might actually use'
            Publisher = 'Microsoft'
            What      = 'Preinstalled apps with real uses that many people still never open: To Do, OneNote, Phone Link, Family Safety, the new Outlook, Clipchamp, Solitaire Collection and Get Help. Unchecked by default. Every one of them reinstalls free from the Store, so removing unused ones costs you nothing permanent.'
            KeepIf    = 'you use any of them. only tick this if you know you do not.'
            Recommend = $false
            Verified  = $true
            Detect    = @{
                Appx      = @('Microsoft.Todos', 'Microsoft.Office.OneNote', 'Microsoft.YourPhone', 'MicrosoftCorporationII.MicrosoftFamily', 'Microsoft.OutlookForWindows', 'Clipchamp.Clipchamp', 'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.GetHelp')
                Uninstall = @()
            }
        }
        @{
            Id        = 'ms-xbox'
            Name      = 'Xbox apps'
            Publisher = 'Microsoft'
            What      = 'The Xbox app, game bar overlays and Xbox sign-in plumbing. Pure background weight if you never game on this PC. WARNING: removing this breaks Game Pass, Minecraft sign-in and the Win+G game bar, so it is unchecked by default. If you are not sure, keep it.'
            KeepIf    = 'you play ANY games on this PC. if unsure, keep it.'
            Recommend = $false
            Verified  = $true
            Detect    = @{
                Appx      = @('Microsoft.GamingApp', 'Microsoft.XboxGamingOverlay', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxIdentityProvider', 'Microsoft.XboxSpeechToTextOverlay', 'Microsoft.Xbox.TCUI')
                Uninstall = @()
            }
        }
        @{
            Id        = 'ms-widgets'
            Name      = 'Widgets board'
            Publisher = 'Microsoft'
            What      = 'The taskbar Widgets panel with MSN news, weather and ads. Removing it turns that panel off. It comes back any time from the Store as "Windows Web Experience Pack". Unchecked by default because some people do like the weather flyout.'
            KeepIf    = 'you open the Widgets board or use its weather flyout.'
            Recommend = $false
            Verified  = $true
            Detect    = @{
                Appx      = @('MicrosoftWindows.Client.WebExperience')
                Uninstall = @()
            }
        }

        # ---------- sponsored third-party stubs ----------
        @{
            Id        = 'sponsored-social-stubs'
            Name      = 'sponsored social app tiles'
            Publisher = 'various (paid placements)'
            What      = 'TikTok, Instagram, Facebook, LinkedIn and the Amazon shopping app. These show up because the companies paid Microsoft for placement in your Start menu, not because you installed them. Most are stubs that only fully download when first clicked.'
            KeepIf    = 'you actually use one of them as an installed app.'
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @('BytedancePte.Ltd.TikTok', 'Facebook.Instagram', 'Facebook.InstagramBeta', 'FACEBOOK.FACEBOOK', '7EE7776C.LinkedInforWindows', 'Amazon.com.Amazon')
                Uninstall = @()
            }
        }
        @{
            Id        = 'sponsored-streaming-stubs'
            Name      = 'streaming app tiles'
            Publisher = 'various (paid placements)'
            What      = 'Spotify, Netflix, Disney+, Hulu and Prime Video tiles that came preloaded as paid placements. Unchecked by default because lots of people genuinely watch and listen through these. If you use the website versions or do not use them at all, they are safe to clear.'
            KeepIf    = 'you watch or listen through these apps.'
            Recommend = $false
            Verified  = $true
            Detect    = @{
                Appx      = @('SpotifyAB.SpotifyMusic', '4DF9E0F8.Netflix', 'Disney.37853FC22B2CE', 'HULULLC.HULUPLUS', 'AmazonVideo.PrimeVideo')
                Uninstall = @()
            }
        }
        @{
            Id        = 'promo-games'
            Name      = 'preinstalled promo games'
            Publisher = 'King and others'
            What      = 'Candy Crush and friends. Windows pushes these on as promos. Pure filler unless you actually play them.'
            KeepIf    = 'you play them.'
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @('king.com.CandyCrushSaga', 'king.com.CandyCrushSodaSaga', 'king.com.CandyCrushFriends', 'king.com.FarmHeroesSaga', 'king.com.BubbleWitch3Saga')
                Uninstall = @()
            }
        }

        # ---------- OEM (PC maker) junk ----------
        @{
            Id        = 'dell-supportassist'
            Name      = 'Dell SupportAssist'
            Publisher = 'Dell'
            What      = 'Dell''s telemetry and auto-repair suite. Heavy on resources, historically buggy (a 2025 update sent PCs into boot loops). It is NOT what installs your BIOS or driver updates, so removing it does not stop updates.'
            KeepIf    = 'You rely on Dell''s automated diagnostics/warranty scans.'
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @('DellInc.DellSupportAssistforPCs')
                Uninstall = @('Dell SupportAssist', 'Dell SupportAssist Remediation', 'Dell SupportAssist OS Recovery Plugin for Dell Update')
            }
        }
        @{
            Id        = 'dell-delivery-extras'
            Name      = 'Dell Digital Delivery + extras'
            Publisher = 'Dell'
            What      = 'Delivers preinstalled Dell trial software and support-portal apps (Digital Delivery, TechHub, Customer Connect, Mobile Connect). Not needed for BIOS, firmware, or driver updates.'
            KeepIf    = 'You use Dell Mobile Connect to mirror your phone.'
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @('DellInc.DellDigitalDelivery', 'DellInc.DellMobileConnect')
                Uninstall = @('Dell Digital Delivery Services', 'Dell TechHub', 'Dell Customer Connect', 'Dell Mobile Connect Drivers')
            }
        }
        @{
            Id        = 'smartbyte'
            Name      = 'SmartByte (Killer network shaper)'
            Publisher = 'Rivet Networks / Dell'
            What      = 'A "network optimizer" bundled on some Dells that often does the opposite: it throttles downloads and streaming. Widely removed.'
            KeepIf    = ''
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @()
                Uninstall = @('SmartByte Drivers and Services')
            }
        }
        @{
            Id        = 'alienware-command-center'
            Name      = 'Alienware Command Center'
            Publisher = 'Dell / Alienware'
            What      = 'Alienware''s RGB lighting, fan and performance control app. It auto-installs when Alienware hardware is detected. Genuinely useful if you own Alienware gear, so this one is unchecked by default.'
            KeepIf    = 'You use it to control Alienware lighting, fan curves, or overclock profiles.'
            Recommend = $false
            Verified  = $true
            Detect    = @{
                Appx      = @()
                Uninstall = @('Alienware Command Center', 'Alienware Command Center Package Manager')
            }
        }
        @{
            Id        = 'hp-bloat'
            Name      = 'HP preinstalled extras'
            Publisher = 'HP'
            What      = 'A pile of promo and helper apps HP preloads: welcome screens, registration nags, jumpstarts, sample media apps and the like. None of it is needed to run your HP hardware. (HP Support Assistant and printer software are deliberately left off this list.)'
            KeepIf    = 'you actually use one of HP''s helper apps by name.'
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @('AD2F1837.myHP', 'AD2F1837.HPJumpStarts', 'AD2F1837.HPRegistration', 'AD2F1837.HPWelcome', 'AD2F1837.HPConnectedMusic', 'AD2F1837.HPConnectedPhotopoweredbySnapfish', 'AD2F1837.HPWorkWell', 'AD2F1837.HPEasyClean', 'AD2F1837.HPFileViewer', 'AD2F1837.HPDesktopSupportUtilities', 'AD2F1837.HPAIExperienceCenter', 'AD2F1837.HPQuickDrop', 'AD2F1837.HPQuickTouch', 'AD2F1837.HPSureShieldAI')
                Uninstall = @()
            }
        }
        @{
            Id        = 'lenovo-vantage'
            Name      = 'Lenovo Vantage'
            Publisher = 'Lenovo'
            What      = 'Lenovo''s all-in-one settings and update app. It works, but it runs background services and nags, and it is not required to keep your laptop updated (Windows Update handles drivers).'
            KeepIf    = 'you use Vantage to manage battery, updates, or hardware settings.'
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @('E046963F.LenovoCompanion', 'LenovoCompanyLimited.LenovoVantageService')
                Uninstall = @('Lenovo Vantage')
            }
        }
        @{
            Id        = 'acer-care-center'
            Name      = 'Acer Care Center'
            Publisher = 'Acer'
            What      = 'Acer''s bundled tuneup and update suite. Runs several background services on every boot. Windows Update handles drivers without it, and your Acer hardware works fine without it.'
            KeepIf    = 'you use its one-click tuneup or Acer update checks.'
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @('AcerIncorporated.AcerCareCenterS')
                Uninstall = @('Acer Care Center', 'Care Center Service')
            }
        }

        @{
            Id        = 'asus-giftbox'
            Name      = 'ASUS GiftBox'
            Publisher = 'ASUS'
            What      = 'ASUS''s preloaded app store for promo offers and partner deals (newer machines fold it into MyASUS as "AppDeals"). Pure storefront, nothing your hardware needs.'
            KeepIf    = ''
            Recommend = $true
            Verified  = $true
            Detect    = @{
                Appx      = @()
                Uninstall = @('ASUS GIFTBOX')
            }
        }
        @{
            Id        = 'asus-extras'
            Name      = 'ASUS companion apps'
            Publisher = 'ASUS'
            What      = 'MyASUS (support, warranty and update hub that also promotes offers), GlideX (phone screen sharing) and ScreenXpert. Unchecked by default: MyASUS is how some owners do warranty claims, and ScreenXpert runs the second screen on ScreenPad models, so only clear these if you know you do not use them.'
            KeepIf    = 'you use MyASUS for support/updates, share screens with GlideX, or your laptop has a ScreenPad.'
            Recommend = $false
            Verified  = $true
            Detect    = @{
                Appx      = @('B9ECED6F.MyASUS', 'B9ECED6F.Glidex', 'B9ECED6F.ScreenPadMaster')
                Uninstall = @()
            }
        }
        @{
            Id        = 'msi-center'
            Name      = 'MSI Center'
            Publisher = 'MSI'
            What      = 'MSI''s all-in-one control app. It is how you drive fans, RGB and performance modes on MSI machines, but it also runs promo features and background services. Unchecked by default because MSI owners often genuinely use it.'
            KeepIf    = 'you use it for fan curves, RGB, or performance modes on MSI hardware.'
            Recommend = $false
            Verified  = $true
            Detect    = @{
                Appx      = @('9426MICRO-STARINTERNATION.MSICenter')
                Uninstall = @()
            }
        }

        # --- TO ADD (need verified exact identifiers before flipping Verified to true) ---
        # MSI Dragon Center (the older MSI app): exact appx identifier unconfirmed.
        # Booking.com HP preload: reported to not appear in the uninstall registry at all
        #   (Start menu stub). Needs a real HP machine to confirm what it registers.
        # LastPass / Utomik HP trials: same story, need exact names from a real machine.
        # ASUS Armoury Crate: deliberately not listed. Gamers depend on it, it spans
        #   services + driver-adjacent pieces, and ASUS ships its own removal tool.
        # NOTE: CPU/GPU vendor tools are intentionally excluded. They sit too close to
        # drivers to remove safely, and this tool never touches drivers.
        # NOTE: OneDrive, Edge, the Store, winget, Windows Security, Photos, Camera,
        # Calculator, Notepad, Terminal, Snipping Tool, Media Player and the new Teams
        # (MSTeams) are permanent leave-alones. Molt is anti junk, not a Windows shredder.
    )
}
