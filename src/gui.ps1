# Cybin Molt GUI. This file draws the window you see: the moth logo, the
# checklist of junk, the three protection switches, the progress bar, and the
# results page. It is the biggest file because describing how a window looks
# takes a lot of lines, but it makes no decisions about what to remove; it just
# shows the findings and passes your choices to the other files.

# This line loads the Windows tools for drawing a window. It must stay here.
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# WHAT THIS DOES: builds and shows the whole Molt window from start to finish.
# It lays out the logo and heading, makes a card for every piece of junk found
# (with its checkbox, name, maker, and plain description), adds the three
# protection switches, and wires up the "clean it up" button so that clicking it
# runs the removals with a progress bar and then shows the results page. The
# switches near the top (WhatIf, Demo, BuildOnly, SnapshotPath) are for preview
# mode and for the automated tests; a normal run uses none of them.
function Show-MoltGui {
    param(
        [array]   $Findings,
        [pscustomobject] $Lockdown,
        [switch]  $WhatIf,
        [switch]  $Demo,
        [string]  $AppRoot,
        [switch]  $BuildOnly,
        [string]  $SnapshotPath
    )

    $mothPath  = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets\molt_mark.png'
    $mothTint  = '#836A50'
    $coffeeUrl = 'https://buymeacoffee.com/MowingDevil'

    $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Cybin Molt" Width="580" Height="812" WindowStartupLocation="CenterScreen"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent" ResizeMode="NoResize"
        FontFamily="Georgia, serif" TextOptions.TextFormattingMode="Display" TextOptions.TextRenderingMode="ClearType">
  <Window.Resources>
    <Style x:Key="Tick" TargetType="CheckBox">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="VerticalAlignment" Value="Top"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Border x:Name="box" Width="23" Height="23" CornerRadius="6"
                    Background="#FBF5E9" BorderBrush="#CBB899" BorderThickness="1.5">
              <Viewbox x:Name="tick" Width="13" Height="10" Visibility="Collapsed"
                       HorizontalAlignment="Center" VerticalAlignment="Center">
                <Path Data="M2,7 L7,12 L15,2" Stroke="#FFFBF2" StrokeThickness="2.2"
                      StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round"/>
              </Viewbox>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="box" Property="Background" Value="#B0805C"/>
                <Setter TargetName="box" Property="BorderBrush" Value="#C0916C"/>
                <Setter TargetName="tick" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="box" Property="BorderBrush" Value="#B0805C"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="ScrollBar">
      <Setter Property="Width" Value="7"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ScrollBar">
            <Track x:Name="PART_Track" IsDirectionReversed="true">
              <Track.Thumb>
                <Thumb>
                  <Thumb.Template>
                    <ControlTemplate TargetType="Thumb">
                      <Border CornerRadius="3.5" Background="#CBB899" Margin="1,0"/>
                    </ControlTemplate>
                  </Thumb.Template>
                </Thumb>
              </Track.Thumb>
              <Track.IncreaseRepeatButton><RepeatButton Opacity="0" Command="ScrollBar.PageDownCommand"/></Track.IncreaseRepeatButton>
              <Track.DecreaseRepeatButton><RepeatButton Opacity="0" Command="ScrollBar.PageUpCommand"/></Track.DecreaseRepeatButton>
            </Track>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Chrome" TargetType="Button">
      <Setter Property="Foreground" Value="#A2917A"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="FontFamily" Value="Consolas"/><Setter Property="FontSize" Value="14"/>
      <Setter Property="Width" Value="30"/><Setter Property="Height" Value="26"/><Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="6">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Background" Value="#E6DBC6"/>
                <Setter Property="Foreground" Value="#3D3227"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Go" TargetType="Button">
      <Setter Property="Foreground" Value="#2E2418"/>
      <Setter Property="FontFamily" Value="Georgia"/><Setter Property="FontSize" Value="16"/>
      <Setter Property="FontStyle" Value="Italic"/><Setter Property="Padding" Value="26,10"/><Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Background" Value="#B0805C"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" CornerRadius="24" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#C0916C"/></Trigger>
        <Trigger Property="IsEnabled" Value="False"><Setter Property="Background" Value="#D8CDB6"/></Trigger>
      </Style.Triggers>
    </Style>
  </Window.Resources>

  <Border Margin="18" CornerRadius="18" Background="#F4EDE0">
    <Border.Effect><DropShadowEffect BlurRadius="30" ShadowDepth="0" Opacity="0.20" Color="#000000"/></Border.Effect>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/><RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <Grid x:Name="TitleBar" Grid.Row="0" Background="Transparent" Margin="20,14,14,0">
        <TextBlock Text="cybin" FontFamily="Consolas" FontSize="12" Foreground="#766140" VerticalAlignment="Center"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <Button x:Name="BtnMin" Style="{StaticResource Chrome}">
            <Rectangle Width="11" Height="1.5" Fill="#A2917A" VerticalAlignment="Center" HorizontalAlignment="Center"/>
          </Button>
          <Button x:Name="BtnClose" Style="{StaticResource Chrome}" Content="&#10005;"/>
        </StackPanel>
      </Grid>

      <StackPanel Grid.Row="1" Margin="34,6,34,0">
        <StackPanel Orientation="Horizontal">
          <Rectangle x:Name="MothMark" Width="74" Height="40" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="0,0,2,0"/>
          <TextBlock Text="molt" FontSize="52" FontStyle="Italic" Foreground="#362B20" VerticalAlignment="Center" Margin="10,-4,0,0"/>
        </StackPanel>
        <TextBlock x:Name="Tagline" Text="shed what shipped uninvited." FontSize="16"
                   Foreground="#5E4C31" FontStyle="Italic" Margin="2,4,0,0"/>
        <Border Height="1" Margin="0,16,0,0">
          <Border.Background>
            <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
              <GradientStop Color="#C69B6E" Offset="0"/><GradientStop Color="#00000000" Offset="0.85"/>
            </LinearGradientBrush>
          </Border.Background>
        </Border>
      </StackPanel>

      <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" Padding="34,6,24,4">
        <StackPanel>
          <TextBlock x:Name="AppsHeader" Text="found on this pc" FontSize="12" Foreground="#6F5C3D" FontFamily="Consolas" Margin="0,6,0,4"/>
          <TextBlock x:Name="AppsHint" TextWrapping="Wrap" FontSize="12.5" Foreground="#6F5C3D" FontStyle="Italic" Margin="0,0,0,10" LineHeight="18"
                     Text="these came preinstalled or installed themselves. checked means remove. uncheck anything you want to keep. each one tells you what it is."/>
          <StackPanel x:Name="CardStack"/>
          <TextBlock x:Name="EmptyState" Visibility="Collapsed" FontSize="19" Foreground="#5E4C31"
                     FontStyle="Italic" TextWrapping="Wrap" Margin="0,14,0,14"
                     Text="nothing to molt. this pc is clean of the junk i know about."/>
          <TextBlock x:Name="ProtLabel" Text="protection" FontSize="12" Foreground="#6F5C3D" FontFamily="Consolas" Margin="0,26,0,6"/>
          <TextBlock x:Name="ProtHint" TextWrapping="Wrap" FontSize="12.5" Foreground="#6F5C3D" FontStyle="Italic" Margin="0,0,0,12" LineHeight="18"
                     Text="three switches that stop this kind of junk from sneaking back on later. it is best to leave them all on."/>
          <StackPanel x:Name="ProtectStack"/>
          <TextBlock x:Name="ProtUndo" TextWrapping="Wrap" FontSize="12" Foreground="#6F5C3D" Margin="0,10,0,0" LineHeight="18"
                     Text="want them off again someday? double-click Undo in the molt folder. it sets everything back to how Windows had it."/>
          <TextBlock x:Name="Coffee" Margin="0,28,0,6" Cursor="Hand" FontSize="13" Foreground="#6F5C3D">
            <Run Text="&#9749;  liked this? "/><Run Text="buy me a coffee" TextDecorations="Underline"/>
          </TextBlock>
        </StackPanel>
      </ScrollViewer>

      <Border Grid.Row="3" CornerRadius="0,0,18,18" Background="#EAE0CD" Padding="34,14,30,18">
        <StackPanel>
          <ProgressBar x:Name="WorkBar" Height="7" Minimum="0" Maximum="100" Visibility="Collapsed" Margin="0,2,0,12" BorderThickness="0">
            <ProgressBar.Template>
              <ControlTemplate TargetType="ProgressBar">
                <Grid>
                  <Border x:Name="PART_Track" Background="#DCCFB6" CornerRadius="3.5"/>
                  <Border x:Name="PART_Indicator" Background="#B0805C" CornerRadius="3.5" HorizontalAlignment="Left"/>
                </Grid>
              </ControlTemplate>
            </ProgressBar.Template>
          </ProgressBar>
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name="StatusText" Grid.Column="0" VerticalAlignment="Center" Foreground="#6F5C3D"
                       FontFamily="Consolas" FontSize="12" TextTrimming="CharacterEllipsis" Margin="0,0,14,0"/>
            <Button x:Name="GoButton" Grid.Column="1" HorizontalAlignment="Right" Style="{StaticResource Go}" Content="clean it up"/>
          </Grid>
        </StackPanel>
      </Border>
    </Grid>
  </Border>
</Window>
'@

    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
    $win = [Windows.Markup.XamlReader]::Load($reader)

    $cardStack    = $win.FindName('CardStack')
    $protectStack = $win.FindName('ProtectStack')
    $emptyState   = $win.FindName('EmptyState')
    $appsHeader   = $win.FindName('AppsHeader')
    $goButton     = $win.FindName('GoButton')
    $statusText   = $win.FindName('StatusText')
    $workBar      = $win.FindName('WorkBar')
    $tagline      = $win.FindName('Tagline')
    $titleBar     = $win.FindName('TitleBar')
    $tickStyle    = $win.FindResource('Tick')

    # moth mark: recolored via opacity mask (unlocked load), tinted to a natural brown
    try {
        $bi = New-Object Windows.Media.Imaging.BitmapImage
        $bi.BeginInit(); $bi.CacheOption = 'OnLoad'; $bi.UriSource = [Uri]$mothPath; $bi.EndInit()
        $ib = New-Object Windows.Media.ImageBrush $bi; $ib.Stretch = 'Uniform'
        $rect = $win.FindName('MothMark')
        $rect.OpacityMask = $ib
        $rect.Fill = New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString($mothTint))
    } catch {}

    $titleBar.Add_MouseLeftButtonDown({ if ($_.ButtonState -eq 'Pressed') { $win.DragMove() } }.GetNewClosure())
    $win.FindName('BtnClose').Add_Click({ $win.Close() }.GetNewClosure())
    $win.FindName('BtnMin').Add_Click({ $win.WindowState = 'Minimized' }.GetNewClosure())
    $win.FindName('Coffee').Add_MouseLeftButtonUp({ Start-Process $coffeeUrl }.GetNewClosure())

    if ($WhatIf) { $tagline.Text = 'preview. nothing will be removed.' }
    if ($Demo) {
        $tagline.Text = 'demo. made-up examples, NOT what is on your pc.'
        $appsHeader.Text = 'example items (not a real scan)'
    }

    $checks = New-Object System.Collections.ArrayList
    # WHAT THIS DOES: builds one row in the checklist for a single piece of junk.
    # It creates the tick box (pre-checked or not based on the recommendation),
    # the big name, the maker in small text, the plain description, the exact
    # item names it found, and the italic "keep it if" note. One call, one card.
    function New-Row($f) {
        $wrap = New-Object Windows.Controls.StackPanel; $wrap.Margin = '0,0,0,4'
        $dock = New-Object Windows.Controls.DockPanel; $dock.Margin = '0,14,0,14'; $dock.LastChildFill = $true
        $cb = New-Object Windows.Controls.CheckBox
        $cb.Style = $tickStyle; $cb.IsChecked = [bool]$f.Recommend; $cb.Margin = '0,3,16,0'; $cb.Tag = $f
        [void]$checks.Add($cb)
        [Windows.Controls.DockPanel]::SetDock($cb, 'Left'); [void]$dock.Children.Add($cb)
        $text = New-Object Windows.Controls.StackPanel
        $name = New-Object Windows.Controls.TextBlock
        $name.Text = $f.Name; $name.FontSize = 21; $name.Foreground = '#362B20'
        $pub = New-Object Windows.Controls.TextBlock
        $pub.Text = $f.Publisher.ToLower(); $pub.FontSize = 11.5; $pub.FontFamily = 'Consolas'; $pub.Foreground = '#6F5C3D'; $pub.Margin = '0,1,0,7'
        $what = New-Object Windows.Controls.TextBlock
        $what.Text = $f.What; $what.TextWrapping = 'Wrap'; $what.FontSize = 14; $what.Foreground = '#4E3F2A'; $what.LineHeight = 21
        [void]$text.Children.Add($name); [void]$text.Children.Add($pub); [void]$text.Children.Add($what)
        $hitNames = @(@($f.AppxHits) + @($f.UninstallHits) | Where-Object { $_ })
        if ($hitNames.Count) {
            $hits = New-Object Windows.Controls.TextBlock
            $hits.Text = 'found: ' + ($hitNames -join ', ')
            $hits.TextWrapping = 'Wrap'; $hits.FontSize = 11; $hits.FontFamily = 'Consolas'; $hits.Foreground = '#6F5C3D'; $hits.Margin = '0,7,0,0'
            [void]$text.Children.Add($hits)
        }
        if ($f.KeepIf) {
            $keep = New-Object Windows.Controls.TextBlock
            $keep.Text = "keep it if $($f.KeepIf.Substring(0,1).ToLower() + $f.KeepIf.Substring(1))"
            $keep.TextWrapping = 'Wrap'; $keep.FontSize = 12.5; $keep.FontStyle = 'Italic'; $keep.Foreground = '#6F5C3D'; $keep.Margin = '0,7,0,0'
            [void]$text.Children.Add($keep)
        }
        [void]$dock.Children.Add($text); [void]$wrap.Children.Add($dock)
        $rule = New-Object Windows.Controls.Border; $rule.Height = 1; $rule.Background = '#E3D8C3'
        [void]$wrap.Children.Add($rule)
        $wrap
    }
    foreach ($f in $Findings) { [void]$cardStack.Children.Add((New-Row $f)) }
    if (-not $Findings -or $Findings.Count -eq 0) {
        $emptyState.Visibility = 'Visible'; $appsHeader.Visibility = 'Collapsed'
        $win.FindName('AppsHint').Visibility = 'Collapsed'
    }

    # WHAT THIS DOES: builds one of the three protection switches: its tick box,
    # its short title, and the sentence under it explaining what it does. Same
    # idea as New-Row above, but for a switch instead of a piece of junk.
    function New-Toggle($label, $desc, $isOn) {
        $dock = New-Object Windows.Controls.DockPanel; $dock.Margin = '0,0,0,14'; $dock.LastChildFill = $true
        $cb = New-Object Windows.Controls.CheckBox; $cb.Style = $tickStyle; $cb.IsChecked = [bool]$isOn; $cb.Margin = '0,2,16,0'
        [Windows.Controls.DockPanel]::SetDock($cb, 'Left'); [void]$dock.Children.Add($cb)
        $sp = New-Object Windows.Controls.StackPanel
        $t = New-Object Windows.Controls.TextBlock; $t.Text = $label; $t.FontSize = 16; $t.Foreground = '#362B20'
        $d = New-Object Windows.Controls.TextBlock; $d.Text = $desc; $d.TextWrapping = 'Wrap'; $d.FontSize = 12.5; $d.Foreground = '#6F5C3D'; $d.Margin = '0,2,0,0'
        [void]$sp.Children.Add($t); [void]$sp.Children.Add($d); [void]$dock.Children.Add($sp)
        @{ Row = $dock; Check = $cb }
    }
    $tM = New-Toggle 'stop surprise apps from new devices' `
        'when you plug in a monitor, printer, or headset, Windows can quietly install the maker''s app in the background. that is how the LG junk got on. this turns that off. your devices still work exactly the same, you just skip the surprise software.' `
        $Lockdown.BlockMonitorAutoInstall
    $tS = New-Toggle 'stop Windows adding apps on its own' `
        'every so often Windows drops sponsored apps and game trials onto your PC by itself. this switches that off. you can still install anything you want yourself from the Store.' `
        $Lockdown.BlockSilentStoreApps
    $tA = New-Toggle 'stop Start menu and Settings ads' `
        'Windows shows "suggested" apps in your Start menu, tips popups, and promo panels inside Settings. those are ads. this turns them off. your Spotlight wallpapers and everything you pinned stay exactly as they are.' `
        $Lockdown.BlockStartAds
    [void]$protectStack.Children.Add($tM.Row); [void]$protectStack.Children.Add($tS.Row); [void]$protectStack.Children.Add($tA.Row)
    $tMonitor = $tM.Check; $tStore = $tS.Check; $tAds = $tA.Check

    # WHAT THIS DOES: counts how many boxes are ticked right now (junk plus the
    # three switches) so the footer can show a live "N selected" count. The line
    # below it updates that count every time you tick or untick anything.
    $countSel = { @($checks | Where-Object { $_.IsChecked }).Count + @($tMonitor,$tStore,$tAds | Where-Object { $_.IsChecked }).Count }.GetNewClosure()
    $statusText.Text = "$(& $countSel) selected"
    foreach ($c in @($checks + $tMonitor + $tStore + $tAds)) { $c.Add_Click({ $statusText.Text = "$(& $countSel) selected" }.GetNewClosure()) }
    if ($WhatIf) { $goButton.Content = 'preview' }

    $state = @{ Done = $false }
    # WHAT THIS DOES: forces the window to redraw itself in the middle of a job.
    # Without it, Windows would wait until all the removing is finished before
    # painting anything, and the progress bar would look frozen. Calling this
    # between each item lets the bar and the "working on..." text actually move.
    # Pumps the dispatcher so the bar and status text actually PAINT between
    # items. Without this, WPF renders nothing until the click handler returns
    # and the window looks frozen for the whole clean.
    $flushUi = { $win.Dispatcher.Invoke([Windows.Threading.DispatcherPriority]::Background, [action]{}) }.GetNewClosure()
    # WHAT THIS DOES: everything that happens when you click the big button. The
    # first click does the work: it hides the button, shows the progress bar,
    # removes each ticked item one at a time (updating the bar as it goes),
    # applies the protection switches, then wipes the checklist and paints the
    # results page (a clear headline, a plain summary, and a tick or a warning
    # per item). At that point the button becomes "done", and clicking it again
    # closes the window (and self removes molt only if you ticked that box).
    $goButton.Add_Click({
        if ($state.Done) {
            if ($state.SelfDelete -and -not $WhatIf) { Invoke-MoltSelfDelete -AppRoot $AppRoot }
            $win.Close(); return
        }
        $chosen = @($checks | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag })
        $protOn = @($tMonitor, $tStore, $tAds | Where-Object { $_.IsChecked }).Count
        # button leaves the stage while work runs: the bar and the status line
        # get the full footer, nothing overlaps, and there is nothing to click.
        $goButton.IsEnabled = $false
        $goButton.Visibility = 'Collapsed'
        $win.Cursor = 'Wait'

        $total     = $chosen.Count + $(if ($protOn) { 1 } else { 0 })
        $rows      = @()
        $protLines = @()
        if ($total) {
            $workBar.Visibility = 'Visible'; $workBar.Value = 0
            $step = 0
            foreach ($f in $chosen) {
                $step++
                $statusText.Text = "working on $step of ${total}: $($f.Name)"
                $workBar.Value = [math]::Round(100 * ($step - 1) / $total)
                & $flushUi
                $r = @(Invoke-MoltRemoval -Findings @($f) -WhatIf:$WhatIf) | Select-Object -First 1
                $bad  = @($r.Results | Where-Object { $_.Status -in 'failed','error' })
                $okCt = @($r.Results).Count - $bad.Count
                if ($bad.Count -eq 0) {
                    $rows += @{ Name = $f.Name; Ok = $true; Detail = ''
                                Verdict = if ($WhatIf) { 'would be removed' } else { 'removed' } }
                } else {
                    $rows += @{ Name = $f.Name; Ok = $false
                                Verdict = "removed $okCt of $(@($r.Results).Count). still here: $(($bad | ForEach-Object { $_.Target }) -join ', ')"
                                Detail  = 'run molt again, or remove it in Windows Settings under Apps.' }
                }
            }
            if ($protOn) {
                $statusText.Text = "working on $total of ${total}: protection"
                $workBar.Value = [math]::Round(100 * ($total - 1) / $total)
                & $flushUi
                $protLines = @(Set-MoltLockdown -BlockMonitorAutoInstall:$tMonitor.IsChecked -BlockSilentStoreApps:$tStore.IsChecked -BlockStartAds:$tAds.IsChecked -WhatIf:$WhatIf)
            }
            $workBar.Value = 100; & $flushUi
        }

        # results page: one loud headline, one plain sentence, then the receipts.
        $cardStack.Children.Clear(); $protectStack.Children.Clear(); $emptyState.Visibility = 'Collapsed'
        $appsHeader.Visibility = 'Collapsed'
        foreach ($n in 'AppsHint','ProtLabel','ProtHint','ProtUndo') { $e = $win.FindName($n); if ($e) { $e.Visibility = 'Collapsed' } }
        $workBar.Visibility = 'Collapsed'
        $win.Cursor = $null

        $okRows  = @($rows | Where-Object { $_.Ok })
        $badRows = @($rows | Where-Object { -not $_.Ok })
        $headline = New-Object Windows.Controls.TextBlock
        $headline.FontSize = 34; $headline.FontStyle = 'Italic'; $headline.Foreground = '#362B20'; $headline.Margin = '0,8,0,4'
        $sum = New-Object Windows.Controls.TextBlock
        $sum.TextWrapping = 'Wrap'; $sum.FontSize = 14.5; $sum.Foreground = '#4E3F2A'; $sum.LineHeight = 21; $sum.Margin = '0,0,0,16'
        if ($total -eq 0) {
            $headline.Text = 'nothing was selected.'
            $sum.Text = 'no boxes were ticked, so molt changed nothing at all.'
        } elseif ($WhatIf) {
            $headline.Text = 'preview only.'
            $sum.Text = 'nothing has been changed. here is what a real run would do.'
        } elseif ($badRows.Count) {
            $headline.Text = 'mostly done.'
            $sum.Text = "molt finished, but $($badRows.Count) item$(if ($badRows.Count -ne 1) { 's' }) put up a fight. details below."
        } else {
            $headline.Text = 'all done.'
            $parts = @()
            if ($okRows.Count)    { $parts += "removed $($okRows.Count) thing$(if ($okRows.Count -ne 1) { 's' })" }
            if ($protLines.Count) { $parts += "turned on $($protLines.Count) protection$(if ($protLines.Count -ne 1) { 's' })" }
            $sum.Text = ($parts -join ' and ') + '. your pc is molted.'
        }
        [void]$cardStack.Children.Add($headline); [void]$cardStack.Children.Add($sum)

        foreach ($row in $rows) {
            $line = New-Object Windows.Controls.TextBlock
            $line.Text = "$(if ($row.Ok) { [char]0x2713 } else { '!' })  $($row.Name): $($row.Verdict)"
            $line.TextWrapping = 'Wrap'; $line.FontSize = 15; $line.LineHeight = 22; $line.Margin = '0,0,0,6'
            $line.Foreground = if ($row.Ok) { '#4E3F2A' } else { '#7A3B2E' }
            [void]$cardStack.Children.Add($line)
            if ($row.Detail) {
                $d = New-Object Windows.Controls.TextBlock
                $d.Text = $row.Detail; $d.TextWrapping = 'Wrap'; $d.FontSize = 12.5; $d.FontStyle = 'Italic'; $d.Foreground = '#6F5C3D'; $d.Margin = '18,0,0,8'
                [void]$cardStack.Children.Add($d)
            }
        }
        foreach ($l in $protLines) {
            $lineBad = $l -match 'could NOT'
            $line = New-Object Windows.Controls.TextBlock
            $line.Text = "$(if ($lineBad) { '!' } else { [char]0x2713 })  $l"
            $line.TextWrapping = 'Wrap'; $line.FontSize = 15; $line.LineHeight = 22; $line.Margin = '0,0,0,6'
            $line.Foreground = if ($lineBad) { '#7A3B2E' } else { '#4E3F2A' }
            [void]$cardStack.Children.Add($line)
        }
        if ($AppRoot) {
            $szTxt = 'a tiny amount of space'
            try {
                $bytes = (Get-ChildItem $AppRoot -Recurse -File -ErrorAction SilentlyContinue |
                          Where-Object { $_.FullName -notmatch '\\tmp\\|\\\.git\\' } |
                          Measure-Object Length -Sum).Sum
                $mb = [math]::Round(($bytes / 1MB), 1)
                $szTxt = if ($mb -lt 1) { 'under 1 MB' } else { "about $mb MB" }
            } catch {}
            $selfDock = New-Object Windows.Controls.DockPanel; $selfDock.Margin = '0,20,0,0'; $selfDock.LastChildFill = $true
            $selfCb = New-Object Windows.Controls.CheckBox; $selfCb.Style = $tickStyle; $selfCb.IsChecked = $false; $selfCb.Margin = '0,2,16,0'
            [Windows.Controls.DockPanel]::SetDock($selfCb, 'Left'); [void]$selfDock.Children.Add($selfCb)
            $sp = New-Object Windows.Controls.StackPanel
            $st = New-Object Windows.Controls.TextBlock; $st.Text = 'remove cybin molt when i close'; $st.FontSize = 16; $st.Foreground = '#362B20'; $st.Margin = '0,0,0,6'
            [void]$sp.Children.Add($st)
            $lines = @(
                "keeping molt is the default. it uses $szTxt, and keeping it is how you run Undo someday.",
                "tick this box if you want molt to clean itself off your pc when you click done.",
                "either way is fine. you can always download it again from github."
            )
            foreach ($ln in $lines) {
                $t = New-Object Windows.Controls.TextBlock
                $t.Text = [char]0x2022 + '  ' + $ln
                $t.TextWrapping = 'Wrap'; $t.FontSize = 12.5; $t.FontStyle = 'Italic'; $t.Foreground = '#6F5C3D'; $t.Margin = '0,0,0,5'; $t.LineHeight = 18
                [void]$sp.Children.Add($t)
            }
            [void]$selfDock.Children.Add($sp)
            [void]$cardStack.Children.Add($selfDock)
            # State rides on the control, not on scope capture: a GetNewClosure made
            # HERE (inside the Go handler's own closure) does not see the outer
            # function's variables, so $state would resolve to garbage at click time
            # and the property set would crash the whole window. Sender.Tag is immune.
            $selfCb.Tag = $state
            $selfCb.Add_Click({ param($s, $e) $s.Tag.SelfDelete = [bool]$s.IsChecked })
            $state.SelfDelete = $false
        }
        $goButton.Content = 'done'; $goButton.IsEnabled = $true; $goButton.Visibility = 'Visible'
        $statusText.Text = if ($WhatIf) { 'preview. nothing was changed' }
                           elseif ($badRows.Count) { 'check the marked items above' }
                           else { 'all set. click done to finish' }
        $state.Done = $true
    }.GetNewClosure())

    if ($BuildOnly) { return $win }
    if ($SnapshotPath) {
        $win.Add_ContentRendered({
            try {
                $w = [int]$win.ActualWidth; $h = [int]$win.ActualHeight
                $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap($w, $h, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
                $rtb.Render($win)
                $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
                $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rtb))
                $fs = [IO.File]::Create($SnapshotPath); $enc.Save($fs); $fs.Close()
            } catch {}
            $win.Close()
        }.GetNewClosure())
    }
    [void]$win.ShowDialog()
}

# WHAT THIS DOES: if you ticked "remove molt when i close", this deletes molt's
# own folder as it exits. It is extremely careful first: it refuses unless the
# folder clearly looks like a molt install AND contains nothing that is not part
# of molt. That protects someone who unzipped molt loose into their Downloads,
# so it can never take your own files with it. It also refuses on the developer's
# copy (marked by a hidden .molt-dev file).
function Invoke-MoltSelfDelete {
    param([string]$AppRoot)
    if (-not $AppRoot -or -not (Test-Path $AppRoot)) { return }
    if (Test-Path (Join-Path $AppRoot '.molt-dev')) { return }
    # Only delete a folder that is unmistakably a molt install and NOTHING else.
    # Guards the person who used "extract here" and landed us loose in Downloads:
    # if a single foreign file lives beside us, we leave the whole folder alone.
    foreach ($marker in @('Molt.ps1', 'src\gui.ps1', 'data\catalog.psd1')) {
        if (-not (Test-Path (Join-Path $AppRoot $marker))) { return }
    }
    $known = @('Molt.ps1','Run.bat','Undo.bat','README.md','LICENSE','.gitignore','.molt-dev',
               'src','data','assets','docs','tests','tmp','.git')
    $foreign = @(Get-ChildItem $AppRoot -Force -ErrorAction SilentlyContinue |
                 Where-Object { $known -notcontains $_.Name })
    if ($foreign.Count) { return }
    Start-Process cmd.exe -WindowStyle Hidden -ArgumentList '/c', "ping 127.0.0.1 -n 3 >nul & rmdir /s /q `"$AppRoot`""
}
