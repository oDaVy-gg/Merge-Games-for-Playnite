# Merge Games for Playnite 10.x
# Select exactly two games in Desktop mode, right-click and choose "Mesclar jogos...".
# Version 0.1.6

# Short ROM labels in Playnite's native action selector.
#
# Playnite 10 builds multi-ROM action labels as "<action name>: <ROM name>".
# Merge Games keeps the native ROM/action model intact and only changes the
# temporary selector presentation. Desktop and Fullscreen use different
# selector windows, so the hook handles both without writing anything back to
# the game database.
function Get-MGRomPathKey {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    try {
        return $Path.Trim().Trim([char]34).Replace("/", [string][System.IO.Path]::DirectorySeparatorChar).ToLowerInvariant()
    }
    catch {
        return ([string]$Path).ToLowerInvariant()
    }
}

function Get-MGActionRomPath {
    param($Action)

    if ($null -eq $Action) { return $null }
    try {
        $property = $Action.PSObject.Properties["SelectedRomPath"]
        if ($null -eq $property) { return $null }
        return [string]$property.Value
    }
    catch {
        return $null
    }
}

function Get-MGActionFromSelectorEntry {
    param($Entry)

    if ($null -eq $Entry) { return $null }

    try {
        $property = $Entry.PSObject.Properties["Item"]
        if ($null -ne $property) { return $property.Value }
    }
    catch { }

    try {
        $property = $Entry.PSObject.Properties["Value"]
        if ($null -ne $property) { return $property.Value }
    }
    catch { }

    return $null
}

function Get-MGSelectorActions {
    param($Window)

    $result = @()
    if ($null -eq $Window) { return @($result) }

    try {
        $windowType = $Window.GetType().FullName
        $dataContext = $Window.DataContext
        if ($null -eq $dataContext) { return @($result) }

        if ($windowType -eq "Playnite.DesktopApp.Windows.ActionSelectionWindow") {
            foreach ($entry in @($dataContext.Actions)) {
                $action = Get-MGActionFromSelectorEntry $entry
                if ($null -ne $action) { $result += $action }
            }
        }
        elseif ($windowType -eq "Playnite.FullscreenApp.Windows.SingleItemSelectionWindow") {
            foreach ($entry in @($dataContext.Items)) {
                $action = Get-MGActionFromSelectorEntry $entry
                if ($null -ne $action) { $result += $action }
            }
        }
    }
    catch { }

    return @($result)
}

function Get-MGRomShortDisplayName {
    param($Action, $Window)

    $romPath = Get-MGActionRomPath $Action
    $romPathKey = Get-MGRomPathKey $romPath
    if ([string]::IsNullOrWhiteSpace($romPathKey)) { return $null }

    # If one ROM path appears more than once in the selector, the prefix is
    # carrying useful information (for example, two emulator profiles).
    # Keep Playnite's original labels instead of creating ambiguous duplicates.
    $pathCounts = @{}
    foreach ($candidateAction in @(Get-MGSelectorActions $Window)) {
        $candidatePath = Get-MGActionRomPath $candidateAction
        $candidateKey = Get-MGRomPathKey $candidatePath
        if ([string]::IsNullOrWhiteSpace($candidateKey)) { continue }

        if ($pathCounts.ContainsKey($candidateKey)) {
            $pathCounts[$candidateKey] = [int]$pathCounts[$candidateKey] + 1
        }
        else {
            $pathCounts[$candidateKey] = 1
        }
    }

    if ($pathCounts.Count -lt 2) { return $null }
    foreach ($count in $pathCounts.Values) {
        if ([int]$count -ne 1) { return $null }
    }

    $names = @{}

    # The currently selected game is normally the one being launched. Prefer
    # it first so the common path does not scan the entire library.
    $selectedGames = @()
    try { $selectedGames = @($PlayniteApi.MainView.SelectedGames) } catch { }

    foreach ($game in $selectedGames) {
        try {
            if (@($game.Roms).Count -le 1) { continue }
            foreach ($rom in @($game.Roms)) {
                if ((Get-MGRomPathKey ([string]$rom.Path)) -eq $romPathKey) {
                    $name = [string]$rom.Name
                    if (-not [string]::IsNullOrWhiteSpace($name)) {
                        $names[$name.ToLowerInvariant()] = $name
                    }
                }
            }
        }
        catch { }
    }

    # Fallback for cases where the launched game is not the sole current
    # MainView selection (possible in Desktop mode).
    if ($names.Count -eq 0) {
        try {
            foreach ($game in $PlayniteApi.Database.Games) {
                if (@($game.Roms).Count -le 1) { continue }
                foreach ($rom in @($game.Roms)) {
                    if ((Get-MGRomPathKey ([string]$rom.Path)) -eq $romPathKey) {
                        $name = [string]$rom.Name
                        if (-not [string]::IsNullOrWhiteSpace($name)) {
                            $names[$name.ToLowerInvariant()] = $name
                        }
                    }
                }
            }
        }
        catch { }
    }

    if ($names.Count -ne 1) { return $null }
    return [string]($names.Values | Select-Object -First 1)
}

function Invoke-MGRomDisplayButtonLoaded {
    param($Button)

    if ($null -eq $Button) { return }

    try {
        $window = [System.Windows.Window]::GetWindow($Button)
        if ($null -eq $window) { return }

        $windowType = $window.GetType().FullName
        if ($windowType -ne "Playnite.DesktopApp.Windows.ActionSelectionWindow" -and
            $windowType -ne "Playnite.FullscreenApp.Windows.SingleItemSelectionWindow") {
            return
        }

        $action = Get-MGActionFromSelectorEntry $Button.DataContext
        $shortName = Get-MGRomShortDisplayName $action $window
        if ([string]::IsNullOrWhiteSpace([string]$shortName)) { return }

        if ($windowType -eq "Playnite.DesktopApp.Windows.ActionSelectionWindow") {
            # ActionSelectionWindow binds its text directly to Item.Name.
            # The action object is a temporary clone produced for this launch;
            # changing its Name does not change the stored Playnite GameAction.
            try { $action.Name = $shortName } catch { }
        }
        else {
            # Fullscreen copies action.Name into a read-only wrapper before
            # showing the selector. Override only the realized button content;
            # virtualized buttons receive the same hook when they are loaded.
            try { $Button.Content = $shortName } catch { }
        }
    }
    catch { }
}

function Register-MGRomDisplayHook {
    $flagName = "MergeGames.RomOnlySelectorLabels.v016"
    try {
        $domain = [System.AppDomain]::CurrentDomain
        if ($domain.GetData($flagName)) { return }

        $script:MGRomDisplayButtonLoadedHandler = [System.Windows.RoutedEventHandler]{
            param($sender, $eventArgs)
            try { Invoke-MGRomDisplayButtonLoaded $sender } catch { }
        }

        [System.Windows.EventManager]::RegisterClassHandler(
            [System.Windows.Controls.Button],
            [System.Windows.FrameworkElement]::LoadedEvent,
            $script:MGRomDisplayButtonLoadedHandler,
            $true)

        $domain.SetData($flagName, $true)
    }
    catch { }
}



function Get-MGThemeBrush {
    param([string]$Key = "TextBrush")

    # Some desktop themes expose TextBrush as a dark brush even while their
    # extension/dialog surface is dark. That made the 0.1.3 window render
    # black-on-black. Prefer the theme brush only when it is visibly light;
    # otherwise use a deterministic high-contrast foreground.
    try {
        $brush = [System.Windows.Application]::Current.TryFindResource($Key)
        if ($brush -is [System.Windows.Media.SolidColorBrush]) {
            $c = $brush.Color
            $luma = (0.2126 * [double]$c.R) + (0.7152 * [double]$c.G) + (0.0722 * [double]$c.B)
            if ($luma -ge 145) { return $brush }
        }
    }
    catch { }

    return New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(238,238,238))
}

function Set-MGThemeForeground {
    param($Control, [string]$BrushKey = "TextBrush")
    if ($null -eq $Control) { return }
    try { $Control.Foreground = (Get-MGThemeBrush $BrushKey) } catch { }
}

function Set-MGSecondaryForeground {
    param($Control)
    if ($null -eq $Control) { return }
    try {
        $Control.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(195,195,195))
    }
    catch { }
}

function Get-MGText {
    param($Value, [int]$Max = 48)

    if ($null -eq $Value) { return "(vazio)" }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return "(vazio)" }
    $text = $text -replace "`r", " " -replace "`n", " "
    if ($text.Length -gt $Max) {
        return $text.Substring(0, $Max - 1) + "…"
    }
    return $text
}

function Get-MGNames {
    param($Items, [int]$Max = 48)

    if ($null -eq $Items -or $Items.Count -eq 0) { return "(vazio)" }
    $text = (($Items | ForEach-Object { $_.Name }) -join ", ")
    return (Get-MGText $text $Max)
}

function Get-MGDateText {
    param($Value)
    if ($null -eq $Value) { return "(vazio)" }
    try { return $Value.ToString() } catch { return [string]$Value }
}

function Get-MGTimeText {
    param([UInt64]$Seconds)
    $ts = [TimeSpan]::FromSeconds([double]$Seconds)
    if ($ts.TotalHours -ge 1) {
        return ("{0}h {1:00}min" -f [math]::Floor($ts.TotalHours), $ts.Minutes)
    }
    return ("{0}min {1:00}s" -f $ts.Minutes, $ts.Seconds)
}

function Merge-MGGuidLists {
    param($First, $Second)
    $result = New-Object 'System.Collections.Generic.List[System.Guid]'
    $seen = @{}
    foreach ($value in (@($First) + @($Second))) {
        if ($null -eq $value) { continue }
        $key = $value.ToString()
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            [void]$result.Add([Guid]$value)
        }
    }
    # Unary comma prevents PowerShell from enumerating List[Guid] into a
    # scalar/array on return. Playnite fields expect List[Guid].
    return ,$result
}

function Join-MGText {
    param($First, $Second, [string]$Separator = "`r`n`r`n")
    if ([string]::IsNullOrWhiteSpace([string]$First)) { return $Second }
    if ([string]::IsNullOrWhiteSpace([string]$Second)) { return $First }
    if ([string]$First -eq [string]$Second) { return $First }
    return ([string]$First) + $Separator + ([string]$Second)
}

function Copy-MGMediaToGame {
    param([string]$MediaPath, [Guid]$TargetGameId)

    if ([string]::IsNullOrWhiteSpace($MediaPath)) { return $null }
    if ($MediaPath -match '^https?://') { return $MediaPath }

    try {
        if ([System.IO.Path]::IsPathRooted($MediaPath)) {
            if ([System.IO.File]::Exists($MediaPath)) {
                return $PlayniteApi.Database.AddFile($MediaPath, $TargetGameId)
            }
            return $MediaPath
        }

        $full = $PlayniteApi.Database.GetFullFilePath($MediaPath)
        if ([System.IO.File]::Exists($full)) {
            return $PlayniteApi.Database.AddFile($full, $TargetGameId)
        }
    }
    catch {
        # If a media file cannot be copied, keep the original reference instead of aborting the whole merge.
    }

    return $MediaPath
}

function Backup-MGMedia {
    param([string]$MediaPath, [string]$DestinationBase)

    if ([string]::IsNullOrWhiteSpace($MediaPath)) { return }
    if ($MediaPath -match '^https?://') { return }

    try {
        if ([System.IO.Path]::IsPathRooted($MediaPath)) {
            $full = $MediaPath
        }
        else {
            $full = $PlayniteApi.Database.GetFullFilePath($MediaPath)
        }

        if ([System.IO.File]::Exists($full)) {
            $ext = [System.IO.Path]::GetExtension($full)
            [System.IO.File]::Copy($full, $DestinationBase + $ext, $true)
        }
    }
    catch { }
}

function Get-MGExtraMetadataGameDirectory {
    param([Guid]$GameId, [bool]$Create = $false)

    try {
        $base = Join-Path $PlayniteApi.Paths.ConfigurationPath "ExtraMetadata"
        $gamesRoot = Join-Path $base "games"
        $dir = Join-Path $gamesRoot $GameId.ToString()
        if ($Create) {
            [System.IO.Directory]::CreateDirectory($dir) | Out-Null
        }
        return $dir
    }
    catch {
        return $null
    }
}

function Get-MGExtraMetadataAssetText {
    param($Game, [string]$FileName)

    if ($null -eq $Game) { return "(ausente)" }
    $dir = Get-MGExtraMetadataGameDirectory $Game.Id $false
    if ([string]::IsNullOrWhiteSpace([string]$dir)) { return "(ausente)" }
    $path = Join-Path $dir $FileName
    if (-not [System.IO.File]::Exists($path)) { return "(ausente)" }
    try {
        $size = [System.IO.FileInfo]::new($path).Length
        if ($size -ge 1048576) { return ("Presente — {0:N1} MB" -f ($size / 1MB)) }
        if ($size -ge 1024) { return ("Presente — {0:N0} KB" -f ($size / 1KB)) }
    }
    catch { }
