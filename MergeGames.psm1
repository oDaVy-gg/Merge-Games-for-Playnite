# Merge Games for Playnite 10.x
# Select exactly two games in Desktop mode, right-click and choose "Mesclar jogos...".
# Version 0.1.4


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
    return "Presente"
}

function Backup-MGExtraMetadata {
    param($Game, [string]$Destination)

    if ($null -eq $Game) { return }
    try {
        $source = Get-MGExtraMetadataGameDirectory $Game.Id $false
        if ([string]::IsNullOrWhiteSpace([string]$source) -or -not [System.IO.Directory]::Exists($source)) { return }
        [System.IO.Directory]::CreateDirectory($Destination) | Out-Null
        foreach ($file in [System.IO.Directory]::GetFiles($source, "*", [System.IO.SearchOption]::AllDirectories)) {
            $relative = $file.Substring($source.Length).TrimStart([char[]]@('\','/'))
            $dest = Join-Path $Destination $relative
            $parent = [System.IO.Path]::GetDirectoryName($dest)
            if (-not [string]::IsNullOrWhiteSpace($parent)) { [System.IO.Directory]::CreateDirectory($parent) | Out-Null }
            [System.IO.File]::Copy($file, $dest, $true)
        }
    }
    catch { }
}

function Copy-MGExtraMetadataAsset {
    param($SourceGame, $TargetGame, [string]$FileName)

    if ($null -eq $SourceGame -or $null -eq $TargetGame) { return $false }
    try {
        $sourceDir = Get-MGExtraMetadataGameDirectory $SourceGame.Id $false
        if ([string]::IsNullOrWhiteSpace([string]$sourceDir)) { return $false }
        $source = Join-Path $sourceDir $FileName
        if (-not [System.IO.File]::Exists($source)) { return $false }

        $targetDir = Get-MGExtraMetadataGameDirectory $TargetGame.Id $true
        $target = Join-Path $targetDir $FileName
        if ([string]::Equals($source, $target, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        [System.IO.File]::Copy($source, $target, $true)
        return $true
    }
    catch {
        return $false
    }
}

function Merge-MGExtraMetadataOtherFiles {
    param($GameA, $GameB, $TargetGame)

    # EML and compatible themes may place auxiliary files in the per-game
    # directory. Preserve everything that does not conflict. Canonical logo
    # and video files are handled separately according to the user's choice.
    $canonical = @{
        "logo.png" = $true
        "videotrailer.mp4" = $true
        "videomicrotrailer.mp4" = $true
    }

    foreach ($sourceGame in @($GameA, $GameB)) {
        if ($null -eq $sourceGame) { continue }
        try {
            $sourceDir = Get-MGExtraMetadataGameDirectory $sourceGame.Id $false
            if ([string]::IsNullOrWhiteSpace([string]$sourceDir) -or -not [System.IO.Directory]::Exists($sourceDir)) { continue }
            $targetDir = Get-MGExtraMetadataGameDirectory $TargetGame.Id $true
            if ([string]::Equals($sourceDir, $targetDir, [System.StringComparison]::OrdinalIgnoreCase)) { continue }

            foreach ($file in [System.IO.Directory]::GetFiles($sourceDir, "*", [System.IO.SearchOption]::AllDirectories)) {
                $relative = $file.Substring($sourceDir.Length).TrimStart([char[]]@('\','/'))
                if ($canonical.ContainsKey($relative.ToLowerInvariant())) { continue }
                $dest = Join-Path $targetDir $relative
                if ([System.IO.File]::Exists($dest)) { continue }
                $parent = [System.IO.Path]::GetDirectoryName($dest)
                if (-not [string]::IsNullOrWhiteSpace($parent)) { [System.IO.Directory]::CreateDirectory($parent) | Out-Null }
                [System.IO.File]::Copy($file, $dest, $false)
            }
        }
        catch { }
    }
}

function Sync-MGExtraMetadataMissingTags {
    param($Game)

    if ($null -eq $Game -or $null -eq $Game.TagIds) { return }
    $checks = @(
        @("[EMT] Logo Missing", "Logo.png"),
        @("[EMT] Video missing", "VideoTrailer.mp4"),
        @("[EMT] Video Micro missing", "VideoMicrotrailer.mp4")
    )

    $dir = Get-MGExtraMetadataGameDirectory $Game.Id $false
    if ([string]::IsNullOrWhiteSpace([string]$dir)) { return }

    foreach ($check in $checks) {
        $tagName = [string]$check[0]
        $fileName = [string]$check[1]
        $path = Join-Path $dir $fileName
        if (-not [System.IO.File]::Exists($path)) { continue }
        try {
            $tag = $PlayniteApi.Database.Tags | Where-Object { $_.Name -eq $tagName } | Select-Object -First 1
            if ($null -ne $tag -and $Game.TagIds.Contains($tag.Id)) {
                [void]$Game.TagIds.Remove($tag.Id)
            }
        }
        catch { }
    }
}

function Refresh-MGGameCollections {
    param($Game)

    # Re-materialize list fields as List[Guid] so providers that inspect
    # Platforms/Tags immediately after the merge receive a normal Playnite
    # collection rather than a PowerShell-unwrapped scalar/array.
    if ($null -eq $Game) { return }
    foreach ($field in @("PlatformIds","GenreIds","DeveloperIds","PublisherIds","CategoryIds","TagIds","FeatureIds","SeriesIds","RegionIds","AgeRatingIds")) {
        try {
            $list = New-Object 'System.Collections.Generic.List[System.Guid]'
            foreach ($id in @($Game.$field)) {
                if ($null -ne $id) { [void]$list.Add([Guid]$id) }
            }
            $Game.$field = $list
        }
        catch { }
    }
}

function Backup-MGGames {
    param($GameA, $GameB)

    try {
        $root = Join-Path $CurrentExtensionDataPath "Backups"
        [System.IO.Directory]::CreateDirectory($root) | Out-Null
        $stamp = [DateTime]::Now.ToString("yyyyMMdd_HHmmss")
        $dir = Join-Path $root ($stamp + "_" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
        [System.IO.Directory]::CreateDirectory($dir) | Out-Null

        $jsonA = [Playnite.SDK.Data.Serialization]::ToJson($GameA, $true)
        $jsonB = [Playnite.SDK.Data.Serialization]::ToJson($GameB, $true)
        [System.IO.File]::WriteAllText((Join-Path $dir "game_A.json"), $jsonA, [System.Text.Encoding]::UTF8)
        [System.IO.File]::WriteAllText((Join-Path $dir "game_B.json"), $jsonB, [System.Text.Encoding]::UTF8)

        Backup-MGMedia $GameA.CoverImage (Join-Path $dir "A_cover")
        Backup-MGMedia $GameA.BackgroundImage (Join-Path $dir "A_background")
        Backup-MGMedia $GameA.Icon (Join-Path $dir "A_icon")
        Backup-MGMedia $GameB.CoverImage (Join-Path $dir "B_cover")
        Backup-MGMedia $GameB.BackgroundImage (Join-Path $dir "B_background")
        Backup-MGMedia $GameB.Icon (Join-Path $dir "B_icon")
        Backup-MGExtraMetadata $GameA (Join-Path $dir "A_ExtraMetadata")
        Backup-MGExtraMetadata $GameB (Join-Path $dir "B_ExtraMetadata")

        $info = @(
            "Merge Games backup",
            "Created: " + [DateTime]::Now.ToString("s"),
            "A: " + $GameA.Name + " | " + $GameA.Id,
            "B: " + $GameB.Name + " | " + $GameB.Id,
            "The JSON files contain the pre-merge Playnite records."
        ) -join [Environment]::NewLine
        [System.IO.File]::WriteAllText((Join-Path $dir "README.txt"), $info, [System.Text.Encoding]::UTF8)
        return $dir
    }
    catch {
        return $null
    }
}

function Get-MGChoiceSource {
    param([string]$Choice, $A, $B)
    if ($Choice -eq "Jogo B") { return $B }
    return $A
}

function Set-MGObservableCollection {
    param($Target, $SourceItems)

    $Target.Clear()
    foreach ($item in @($SourceItems)) {
        if ($null -eq $item) { continue }
        try { $copy = $item.GetCopy() } catch { $copy = $item }
        [void]$Target.Add($copy)
    }
}

function Merge-MGObjectsUnique {
    param($First, $Second, [scriptblock]$KeySelector)

    $result = @()
    $seen = @{}
    foreach ($item in (@($First) + @($Second))) {
        if ($null -eq $item) { continue }
        $key = & $KeySelector $item
        if ([string]::IsNullOrWhiteSpace([string]$key)) {
            $key = [Guid]::NewGuid().ToString()
        }
        if (-not $seen.ContainsKey([string]$key)) {
            $seen[[string]$key] = $true
            try { $result += $item.GetCopy() } catch { $result += $item }
        }
    }
    return $result
}

function New-MGCombo {
    param([string[]]$Items, [string]$Default)
    $combo = New-Object System.Windows.Controls.ComboBox
    $combo.MinWidth = 120
    $combo.Margin = [System.Windows.Thickness]::new(6, 2, 6, 2)
    foreach ($item in $Items) { [void]$combo.Items.Add($item) }
    $combo.SelectedItem = $Default
    return $combo
}

function Add-MGGridRow {
    param(
        $Grid,
        [int]$Row,
        [string]$Key,
        [string]$Label,
        [string]$AText,
        [string]$BText,
        [string[]]$Choices,
        [string]$Default,
        $ControlMap
    )

    $def = New-Object System.Windows.Controls.RowDefinition
    $def.Height = [System.Windows.GridLength]::Auto
    [void]$Grid.RowDefinitions.Add($def)

    $labelBlock = New-Object System.Windows.Controls.TextBlock
    $labelBlock.Text = $Label
    $labelBlock.Margin = [System.Windows.Thickness]::new(6, 4, 6, 4)
    $labelBlock.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    Set-MGThemeForeground $labelBlock
    $labelBlock.FontWeight = [System.Windows.FontWeights]::SemiBold
    [System.Windows.Controls.Grid]::SetRow($labelBlock, $Row)
    [System.Windows.Controls.Grid]::SetColumn($labelBlock, 0)
    [void]$Grid.Children.Add($labelBlock)

    $aBlock = New-Object System.Windows.Controls.TextBlock
    $aBlock.Text = $AText
    $aBlock.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $aBlock.Margin = [System.Windows.Thickness]::new(6, 4, 6, 4)
    $aBlock.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    Set-MGThemeForeground $aBlock
    $aBlock.ToolTip = $AText
    [System.Windows.Controls.Grid]::SetRow($aBlock, $Row)
    [System.Windows.Controls.Grid]::SetColumn($aBlock, 1)
    [void]$Grid.Children.Add($aBlock)

    $bBlock = New-Object System.Windows.Controls.TextBlock
    $bBlock.Text = $BText
    $bBlock.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $bBlock.Margin = [System.Windows.Thickness]::new(6, 4, 6, 4)
    $bBlock.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    Set-MGThemeForeground $bBlock
    $bBlock.ToolTip = $BText
    [System.Windows.Controls.Grid]::SetRow($bBlock, $Row)
    [System.Windows.Controls.Grid]::SetColumn($bBlock, 2)
    [void]$Grid.Children.Add($bBlock)

    $combo = New-MGCombo $Choices $Default
    [System.Windows.Controls.Grid]::SetRow($combo, $Row)
    [System.Windows.Controls.Grid]::SetColumn($combo, 3)
    [void]$Grid.Children.Add($combo)
    $ControlMap[$Key] = $combo
}

function Get-MGSelected {
    param($ControlMap, [string]$Key)
    if (-not $ControlMap.ContainsKey($Key)) { return $null }
    return [string]$ControlMap[$Key].SelectedItem
}

function Invoke-MGMerge {
    param($A, $B, $Controls, [bool]$PrimaryIsA, [string]$AfterMode)

    $a = $A.GetCopy()
    $b = $B.GetCopy()
    if ($PrimaryIsA) {
        $primary = $A
        $secondary = $B
        $primarySnapshot = $a
    }
    else {
        $primary = $B
        $secondary = $A
        $primarySnapshot = $b
    }

    $backupPath = Backup-MGGames $a $b
    if ($AfterMode -eq "Excluir secundário" -and [string]::IsNullOrWhiteSpace([string]$backupPath)) {
        throw "O backup de segurança falhou. A entrada secundária não será excluída."
    }

    # Core identity is intentionally retained from the chosen primary game.
    # This preserves Steam/GOG/emulator library ownership and its launch integration.

    $source = Get-MGChoiceSource (Get-MGSelected $Controls "Name") $a $b
    $primary.Name = $source.Name

    $source = Get-MGChoiceSource (Get-MGSelected $Controls "SortingName") $a $b
    $primary.SortingName = $source.SortingName

    $choice = Get-MGSelected $Controls "Description"
    if ($choice -eq "Mesclar") { $primary.Description = Join-MGText $a.Description $b.Description "<hr/>" }
    else { $primary.Description = (Get-MGChoiceSource $choice $a $b).Description }

    foreach ($mediaField in @("CoverImage", "BackgroundImage", "Icon")) {
        $choice = Get-MGSelected $Controls $mediaField
        $sourceObj = Get-MGChoiceSource $choice $a $b
        $mediaValue = $sourceObj.$mediaField
        $sourceWasPrimary = ($sourceObj.Id -eq $primarySnapshot.Id)
        if ($sourceWasPrimary) {
            $primary.$mediaField = $mediaValue
        }
        else {
            $primary.$mediaField = Copy-MGMediaToGame $mediaValue $primary.Id
        }
    }

    # Extra Metadata Loader stores logo/video files in a per-game folder keyed
    # by Playnite's database Id. Move/copy the chosen assets to the surviving
    # game before a secondary entry can be hidden or deleted.
    $emlAssets = @{
        "EMLLogo" = "Logo.png"
        "EMLVideoTrailer" = "VideoTrailer.mp4"
        "EMLVideoMicrotrailer" = "VideoMicrotrailer.mp4"
    }
    foreach ($emlKey in $emlAssets.Keys) {
        $choice = Get-MGSelected $Controls $emlKey
        if ($choice -eq "Jogo principal" -or [string]::IsNullOrWhiteSpace($choice)) {
            $sourceObj = $primarySnapshot
        }
        else {
            $sourceObj = Get-MGChoiceSource $choice $a $b
        }
        [void](Copy-MGExtraMetadataAsset $sourceObj $primarySnapshot $emlAssets[$emlKey])
    }
    Merge-MGExtraMetadataOtherFiles $a $b $primarySnapshot

    foreach ($field in @("ReleaseDate", "Version", "CompletionStatusId", "Manual", "InstallDirectory", "InstallSize", "UserScore", "CriticScore", "CommunityScore", "PreScript", "GameStartedScript", "PostScript")) {
        $choice = Get-MGSelected $Controls $field
        $sourceObj = Get-MGChoiceSource $choice $a $b
        $primary.$field = $sourceObj.$field
    }

    foreach ($field in @("PlatformIds", "GenreIds", "DeveloperIds", "PublisherIds", "CategoryIds", "TagIds", "FeatureIds", "SeriesIds", "RegionIds", "AgeRatingIds")) {
        $choice = Get-MGSelected $Controls $field
        if ($choice -eq "Mesclar") {
            $primary.$field = Merge-MGGuidLists $a.$field $b.$field
        }
        else {
            $sourceObj = Get-MGChoiceSource $choice $a $b
            $primary.$field = Merge-MGGuidLists $sourceObj.$field @()
        }
    }

    $choice = Get-MGSelected $Controls "Notes"
    if ($choice -eq "Mesclar") { $primary.Notes = Join-MGText $a.Notes $b.Notes }
    else { $primary.Notes = (Get-MGChoiceSource $choice $a $b).Notes }

    $choice = Get-MGSelected $Controls "Favorite"
    if ($choice -eq "Sim se qualquer um") { $primary.Favorite = ($a.Favorite -or $b.Favorite) }
    else { $primary.Favorite = (Get-MGChoiceSource $choice $a $b).Favorite }

    $choice = Get-MGSelected $Controls "Hidden"
    if ($choice -eq "Visível se qualquer um") { $primary.Hidden = ($a.Hidden -and $b.Hidden) }
    else { $primary.Hidden = (Get-MGChoiceSource $choice $a $b).Hidden }

    $choice = Get-MGSelected $Controls "Playtime"
    switch ($choice) {
        "Somar" { $primary.Playtime = [UInt64]($a.Playtime + $b.Playtime) }
        "Maior" { $primary.Playtime = [UInt64][Math]::Max([double]$a.Playtime, [double]$b.Playtime) }
        "Jogo B" { $primary.Playtime = $b.Playtime }
        default { $primary.Playtime = $a.Playtime }
    }

    $choice = Get-MGSelected $Controls "PlayCount"
    switch ($choice) {
        "Somar" { $primary.PlayCount = [UInt64]($a.PlayCount + $b.PlayCount) }
        "Maior" { $primary.PlayCount = [UInt64][Math]::Max([double]$a.PlayCount, [double]$b.PlayCount) }
        "Jogo B" { $primary.PlayCount = $b.PlayCount }
        default { $primary.PlayCount = $a.PlayCount }
    }

    $choice = Get-MGSelected $Controls "LastActivity"
    if ($choice -eq "Mais recente") {
        if ($null -eq $a.LastActivity) { $primary.LastActivity = $b.LastActivity }
        elseif ($null -eq $b.LastActivity) { $primary.LastActivity = $a.LastActivity }
        elseif ($a.LastActivity -ge $b.LastActivity) { $primary.LastActivity = $a.LastActivity }
        else { $primary.LastActivity = $b.LastActivity }
    }
    else { $primary.LastActivity = (Get-MGChoiceSource $choice $a $b).LastActivity }

    $choice = Get-MGSelected $Controls "Added"
    if ($choice -eq "Mais antiga") {
        if ($null -eq $a.Added) { $primary.Added = $b.Added }
        elseif ($null -eq $b.Added) { $primary.Added = $a.Added }
        elseif ($a.Added -le $b.Added) { $primary.Added = $a.Added }
        else { $primary.Added = $b.Added }
    }
    else { $primary.Added = (Get-MGChoiceSource $choice $a $b).Added }

    $choice = Get-MGSelected $Controls "Links"
    if ($choice -eq "Mesclar") {
        $items = Merge-MGObjectsUnique $a.Links $b.Links { param($x) (($x.Name + "|" + $x.Url).ToLowerInvariant()) }
    }
    else { $items = @((Get-MGChoiceSource $choice $a $b).Links) }
    Set-MGObservableCollection $primary.Links $items

    $choice = Get-MGSelected $Controls "Roms"
    if ($choice -eq "Mesclar") {
        $items = Merge-MGObjectsUnique $a.Roms $b.Roms { param($x) (($x.Name + "|" + $x.Path).ToLowerInvariant()) }
    }
    else { $items = @((Get-MGChoiceSource $choice $a $b).Roms) }
    Set-MGObservableCollection $primary.Roms $items

    $choice = Get-MGSelected $Controls "GameActions"
    if ($choice -eq "Mesclar") {
        $items = Merge-MGObjectsUnique $a.GameActions $b.GameActions { param($x) (($x.Name + "|" + $x.Type + "|" + $x.Path + "|" + $x.Arguments + "|" + $x.EmulatorId + "|" + $x.EmulatorProfileId).ToLowerInvariant()) }
    }
    else { $items = @((Get-MGChoiceSource $choice $a $b).GameActions) }
    Set-MGObservableCollection $primary.GameActions $items

    # Keep provider-facing collections normalized. This is important for
    # extensions such as Extra Metadata Loader that immediately inspect
    # Platforms/Tags after a merge.
    Refresh-MGGameCollections $primary
    Sync-MGExtraMetadataMissingTags $primary

    # Preserve installation/launcher ownership from primary. Only cosmetic/data fields above are merged.
    $primary.PluginId = $primarySnapshot.PluginId
    $primary.GameId = $primarySnapshot.GameId
    $primary.IncludeLibraryPluginAction = $primarySnapshot.IncludeLibraryPluginAction
    $primary.SourceId = $primarySnapshot.SourceId
    $primary.IsInstalled = $primarySnapshot.IsInstalled
    $primary.OverrideInstallState = $primarySnapshot.OverrideInstallState

    $buffer = $PlayniteApi.Database.BufferedUpdate()
    try {
        $PlayniteApi.Database.Games.Update($primary)

        if ($AfterMode -eq "Ocultar secundário (seguro)") {
            $secondary.Hidden = $true
            $PlayniteApi.Database.Games.Update($secondary)
        }
        elseif ($AfterMode -eq "Excluir secundário") {
            $PlayniteApi.Database.Games.Remove($secondary.Id)
        }
    }
    finally {
        if ($null -ne $buffer) { $buffer.Dispose() }
    }

    # Read the object back from the database so other extensions receive a
    # freshly materialized Game instance and its relationship properties.
    try {
        $freshPrimary = $PlayniteApi.Database.Games.Get($primary.Id)
        if ($null -ne $freshPrimary) { $primary = $freshPrimary }
    }
    catch { }

    try { $PlayniteApi.MainView.SelectGames(@($primary.Id)) } catch { }

    return [PSCustomObject]@{
        Primary = $primary
        BackupPath = $backupPath
        SecondaryAction = $AfterMode
    }
}

function Show-MGMergeWindow {
    param($GameA, $GameB)

    $a = $GameA.GetCopy()
    $b = $GameB.GetCopy()
    $controls = @{}

    $options = New-Object Playnite.SDK.WindowCreationOptions
    $options.ShowMinimizeButton = $false
    $options.ShowMaximizeButton = $false
    $window = $PlayniteApi.Dialogs.CreateWindow($options)
    $window.Title = "Merge Games — mesclar duas entradas"
    $window.Width = 1080
    $window.Height = 820
    $window.MinWidth = 900
    $window.MinHeight = 650
    $window.Owner = $PlayniteApi.Dialogs.GetCurrentAppWindow()
    $window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner

    $root = New-Object System.Windows.Controls.DockPanel
    $root.Margin = [System.Windows.Thickness]::new(14)

    $top = New-Object System.Windows.Controls.StackPanel
    [System.Windows.Controls.DockPanel]::SetDock($top, [System.Windows.Controls.Dock]::Top)

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = "Escolha o jogo principal e, campo por campo, o que deve sobreviver."
    $title.FontSize = 18
    $title.FontWeight = [System.Windows.FontWeights]::SemiBold
    $title.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
    Set-MGThemeForeground $title
    [void]$top.Children.Add($title)

    $warning = New-Object System.Windows.Controls.TextBlock
    $warning.Text = "O jogo principal mantém o ID e a integração de biblioteca (Steam/GOG/emulador). Arquivos do Extra Metadata Loader também são preservados/migrados. O tempo e o número de execuções podem ser somados. Um backup é criado automaticamente antes da alteração."
    $warning.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $warning.Opacity = 0.82
    $warning.Margin = [System.Windows.Thickness]::new(0, 0, 0, 10)
    Set-MGThemeForeground $warning
    [void]$top.Children.Add($warning)

    $primaryPanel = New-Object System.Windows.Controls.StackPanel
    $primaryPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $primaryLabel = New-Object System.Windows.Controls.TextBlock
    $primaryLabel.Text = "Jogo principal: "
    $primaryLabel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $primaryLabel.FontWeight = [System.Windows.FontWeights]::SemiBold
    Set-MGThemeForeground $primaryLabel
    [void]$primaryPanel.Children.Add($primaryLabel)

    $radioA = New-Object System.Windows.Controls.RadioButton
    $radioA.GroupName = "PrimaryGame"
    $radioA.Content = "A — " + $a.Name
    $radioA.IsChecked = $true
    $radioA.Margin = [System.Windows.Thickness]::new(6, 0, 18, 0)
    Set-MGThemeForeground $radioA
    [void]$primaryPanel.Children.Add($radioA)

    $radioB = New-Object System.Windows.Controls.RadioButton
    $radioB.GroupName = "PrimaryGame"
    $radioB.Content = "B — " + $b.Name
    Set-MGThemeForeground $radioB
    [void]$primaryPanel.Children.Add($radioB)
    [void]$top.Children.Add($primaryPanel)

    [void]$root.Children.Add($top)

    $bottom = New-Object System.Windows.Controls.StackPanel
    $bottom.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $bottom.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
    $bottom.Margin = [System.Windows.Thickness]::new(0, 10, 0, 0)
    [System.Windows.Controls.DockPanel]::SetDock($bottom, [System.Windows.Controls.Dock]::Bottom)

    $afterLabel = New-Object System.Windows.Controls.TextBlock
    $afterLabel.Text = "Depois de mesclar:"
    $afterLabel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $afterLabel.Margin = [System.Windows.Thickness]::new(0, 0, 6, 0)
    Set-MGThemeForeground $afterLabel
    [void]$bottom.Children.Add($afterLabel)

    $afterCombo = New-MGCombo @("Ocultar secundário (seguro)", "Excluir secundário", "Manter secundário") "Ocultar secundário (seguro)"
    $afterCombo.MinWidth = 200
    [void]$bottom.Children.Add($afterCombo)

    $cancel = New-Object System.Windows.Controls.Button
    $cancel.Content = "Cancelar"
    $cancel.MinWidth = 90
    $cancel.Margin = [System.Windows.Thickness]::new(12, 2, 4, 2)
    $cancel.Add_Click({ $window.DialogResult = $false; $window.Close() })
    [void]$bottom.Children.Add($cancel)

    $merge = New-Object System.Windows.Controls.Button
    $merge.Content = "Mesclar"
    $merge.MinWidth = 110
    $merge.Margin = [System.Windows.Thickness]::new(4, 2, 0, 2)
    $merge.FontWeight = [System.Windows.FontWeights]::SemiBold
    [void]$bottom.Children.Add($merge)
    [void]$root.Children.Add($bottom)

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $scroll.HorizontalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Disabled
    $scroll.Margin = [System.Windows.Thickness]::new(0, 12, 0, 0)

    $grid = New-Object System.Windows.Controls.Grid
    $grid.ShowGridLines = $false
    foreach ($width in @("175", "1*", "1*", "150")) {
        $col = New-Object System.Windows.Controls.ColumnDefinition
        if ($width -eq "1*") { $col.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) }
        else { $col.Width = [System.Windows.GridLength]::new([double]$width) }
        [void]$grid.ColumnDefinitions.Add($col)
    }

    $headerDef = New-Object System.Windows.Controls.RowDefinition
    $headerDef.Height = [System.Windows.GridLength]::Auto
    [void]$grid.RowDefinitions.Add($headerDef)
    foreach ($pair in @(@(0,"Campo"), @(1,"Jogo A"), @(2,"Jogo B"), @(3,"Resultado"))) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = $pair[1]
        $tb.FontWeight = [System.Windows.FontWeights]::Bold
        $tb.Margin = [System.Windows.Thickness]::new(6, 4, 6, 8)
        Set-MGThemeForeground $tb
        [System.Windows.Controls.Grid]::SetRow($tb, 0)
        [System.Windows.Controls.Grid]::SetColumn($tb, [int]$pair[0])
        [void]$grid.Children.Add($tb)
    }

    $row = 1
    Add-MGGridRow $grid $row "Name" "Nome" (Get-MGText $a.Name) (Get-MGText $b.Name) @("Jogo A","Jogo B") "Jogo A" $controls; $row++
    Add-MGGridRow $grid $row "SortingName" "Nome de ordenação" (Get-MGText $a.SortingName) (Get-MGText $b.SortingName) @("Jogo A","Jogo B") "Jogo A" $controls; $row++
    Add-MGGridRow $grid $row "Description" "Descrição" (Get-MGText $a.Description) (Get-MGText $b.Description) @("Jogo A","Jogo B","Mesclar") "Jogo A" $controls; $row++
    Add-MGGridRow $grid $row "CoverImage" "Capa" (Get-MGText $a.CoverImage) (Get-MGText $b.CoverImage) @("Jogo A","Jogo B") "Jogo A" $controls; $row++
    Add-MGGridRow $grid $row "BackgroundImage" "Fundo" (Get-MGText $a.BackgroundImage) (Get-MGText $b.BackgroundImage) @("Jogo A","Jogo B") "Jogo A" $controls; $row++
    Add-MGGridRow $grid $row "Icon" "Ícone" (Get-MGText $a.Icon) (Get-MGText $b.Icon) @("Jogo A","Jogo B") "Jogo A" $controls; $row++
    Add-MGGridRow $grid $row "EMLLogo" "Logo (Extra Metadata)" (Get-MGExtraMetadataAssetText $a "Logo.png") (Get-MGExtraMetadataAssetText $b "Logo.png") @("Jogo principal","Jogo A","Jogo B") "Jogo principal" $controls; $row++
    Add-MGGridRow $grid $row "EMLVideoTrailer" "Trailer (Extra Metadata)" (Get-MGExtraMetadataAssetText $a "VideoTrailer.mp4") (Get-MGExtraMetadataAssetText $b "VideoTrailer.mp4") @("Jogo principal","Jogo A","Jogo B") "Jogo principal" $controls; $row++
    Add-MGGridRow $grid $row "EMLVideoMicrotrailer" "Microtrailer (Extra Metadata)" (Get-MGExtraMetadataAssetText $a "VideoMicrotrailer.mp4") (Get-MGExtraMetadataAssetText $b "VideoMicrotrailer.mp4") @("Jogo principal","Jogo A","Jogo B") "Jogo principal" $controls; $row++
    Add-MGGridRow $grid $row "ReleaseDate" "Lançamento" (Get-MGDateText $a.ReleaseDate) (Get-MGDateText $b.ReleaseDate) @("Jogo A","Jogo B") "Jogo A" $controls; $row++
    Add-MGGridRow $grid $row "Version" "Versão" (Get-MGText $a.Version) (Get-MGText $b.Version) @("Jogo A","Jogo B") "Jogo A" $controls; $row++

    Add-MGGridRow $grid $row "PlatformIds" "Plataformas" (Get-MGNames $a.Platforms) (Get-MGNames $b.Platforms) @("Jogo A","Jogo B","Mesclar") "Mesclar" $controls; $row++
    Add-MGGridRow $grid $row "GenreIds" "Gêneros" (Get-MGNames $a.Genres) (Get-MGNames $b.Genres) @("Jogo A","Jogo B","Mesclar") "Mesclar" $controls; $row++
    Add-MGGridRow $grid $row "DeveloperIds" "Desenvolvedores" (Get-MGNames $a.Developers) (Get-MGNames $b.Developers) @("Jogo A","Jogo B","Mesclar") "Mesclar" $controls; $row++
    Add-MGGridRow $grid $row "PublisherIds" "Editoras" (Get-MGNames $a.Publishers) (Get-MGNames $b.Publishers) @("Jogo A","Jogo B","Mesclar") "Mesclar" $controls; $row++
    Add-MGGridRow $grid $row "CategoryIds" "Categorias" (Get-MGNames $a.Categories) (Get-MGNames $b.Categories) @("Jogo A","Jogo B","Mesclar") "Mesclar" $controls; $row++
    Add-MGGridRow $grid $row "TagIds" "Tags" (Get-MGNames $a.Tags) (Get-MGNames $b.Tags) @("Jogo A","Jogo B","Mesclar") "Mesclar" $controls; $row++
    Add-MGGridRow $grid $row "FeatureIds" "Recursos" (Get-MGNames $a.Features) (Get-MGNames $b.Features) @("Jogo A","Jogo B","Mesclar") "Mesclar" $controls; $row++
    Add-MGGridRow $grid $row "SeriesIds" "Séries" (Get-MGNames $a.Series) (Get-MGNames $b.Series) @("Jogo A","Jogo B","Mesclar") "Mesclar" $controls; $row++
    Add-MGGridRow $grid $row "RegionIds" "Regiões" (Get-MGNames $a.Regions) (Get-MGNames $b.Regions) @("Jogo A","Jogo B","Mesclar") "Mesclar" $controls; $row++
    Add-MGGridRow $grid $row "AgeRatingIds" "Classificação etária" (Get-MGNames $a.AgeRatings) (Get-MGNames $b.AgeRatings) @("Jogo A","Jogo B","Mesclar") "Mesclar" $controls; $row++

    Add-MGGridRow $grid $row "CompletionStatusId" "Estado de conclusão" (Get-MGText $a.CompletionStatus.Name) (Get-MGText $b.CompletionStatus.Name) @("Jogo A","Jogo B") "Jogo A" $controls; $row++
    Add-MGGridRow $grid $row "Notes" "Notas" (Get-MGText $a.Notes) (Get-MGText $b.Notes) @("Jogo A","Jogo B","Mesclar") "Mesclar" $controls; $row++
    Add-MGGridRow $grid $row "Links" "Links" ("{0} link(s)" -f $a.Links.Count) ("{0} link(s)" -f $b.Links.Count) @("Jogo A","Jogo B","Mesclar") "Mesclar" $controls; $row++
    Add-MGGridRow $grid $row "Roms" "ROMs" ("{0} ROM(s)" -f $a.Roms.Count) ("{0} ROM(s)" -f $b.Roms.Count) @("Jogo A","Jogo B","Mesclar") "Mesclar" $controls; $row++
    Add-MGGridRow $grid $row "GameActions" "Ações" ("{0} ação(ões)" -f $a.GameActions.Count) ("{0} ação(ões)" -f $b.GameActions.Count) @("Jogo A","Jogo B","Mesclar") "Mesclar" $controls; $row++

    Add-MGGridRow $grid $row "Playtime" "Tempo jogado" (Get-MGTimeText $a.Playtime) (Get-MGTimeText $b.Playtime) @("Somar","Maior","Jogo A","Jogo B") "Somar" $controls; $row++
    Add-MGGridRow $grid $row "PlayCount" "Nº de execuções" ([string]$a.PlayCount) ([string]$b.PlayCount) @("Somar","Maior","Jogo A","Jogo B") "Somar" $controls; $row++
    Add-MGGridRow $grid $row "LastActivity" "Última execução" (Get-MGDateText $a.LastActivity) (Get-MGDateText $b.LastActivity) @("Mais recente","Jogo A","Jogo B") "Mais recente" $controls; $row++
    Add-MGGridRow $grid $row "Added" "Adicionado" (Get-MGDateText $a.Added) (Get-MGDateText $b.Added) @("Mais antiga","Jogo A","Jogo B") "Mais antiga" $controls; $row++
    Add-MGGridRow $grid $row "Favorite" "Favorito" ([string]$a.Favorite) ([string]$b.Favorite) @("Sim se qualquer um","Jogo A","Jogo B") "Sim se qualquer um" $controls; $row++
    Add-MGGridRow $grid $row "Hidden" "Oculto" ([string]$a.Hidden) ([string]$b.Hidden) @("Visível se qualquer um","Jogo A","Jogo B") "Visível se qualquer um" $controls; $row++

    Add-MGGridRow $grid $row "UserScore" "Nota do usuário" (Get-MGText $a.UserScore) (Get-MGText $b.UserScore) @("Jogo A","Jogo B") "Jogo A" $controls; $row++
    Add-MGGridRow $grid $row "CriticScore" "Nota da crítica" (Get-MGText $a.CriticScore) (Get-MGText $b.CriticScore) @("Jogo A","Jogo B") "Jogo A" $controls; $row++
    Add-MGGridRow $grid $row "CommunityScore" "Nota da comunidade" (Get-MGText $a.CommunityScore) (Get-MGText $b.CommunityScore) @("Jogo A","Jogo B") "Jogo A" $controls; $row++
    Add-MGGridRow $grid $row "Manual" "Manual" (Get-MGText $a.Manual) (Get-MGText $b.Manual) @("Jogo A","Jogo B") "Jogo A" $controls; $row++
    Add-MGGridRow $grid $row "InstallDirectory" "Pasta de instalação" (Get-MGText $a.InstallDirectory) (Get-MGText $b.InstallDirectory) @("Jogo A","Jogo B") "Jogo A" $controls; $row++
    Add-MGGridRow $grid $row "InstallSize" "Tamanho instalado" (Get-MGText $a.InstallSize) (Get-MGText $b.InstallSize) @("Jogo A","Jogo B") "Jogo A" $controls; $row++
    Add-MGGridRow $grid $row "PreScript" "Script pré-jogo" (Get-MGText $a.PreScript) (Get-MGText $b.PreScript) @("Jogo A","Jogo B") "Jogo A" $controls; $row++
    Add-MGGridRow $grid $row "GameStartedScript" "Script ao iniciar" (Get-MGText $a.GameStartedScript) (Get-MGText $b.GameStartedScript) @("Jogo A","Jogo B") "Jogo A" $controls; $row++
    Add-MGGridRow $grid $row "PostScript" "Script pós-jogo" (Get-MGText $a.PostScript) (Get-MGText $b.PostScript) @("Jogo A","Jogo B") "Jogo A" $controls; $row++

    $scroll.Content = $grid
    [void]$root.Children.Add($scroll)
    $window.Content = $root

    $merge.Add_Click({
        $afterMode = [string]$afterCombo.SelectedItem
        if ($afterMode -eq "Excluir secundário") {
            $answer = $PlayniteApi.Dialogs.ShowMessage(
                "Excluir a entrada secundária é definitivo no banco do Playnite. Se ela vier de Steam/GOG/outra integração, ela também pode reaparecer numa atualização da biblioteca. O backup será salvo antes. Deseja continuar?",
                "Merge Games",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning)
            if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }
        }

        try {
            $result = Invoke-MGMerge $GameA $GameB $controls ([bool]$radioA.IsChecked) $afterMode
            $backupText = if ([string]::IsNullOrWhiteSpace([string]$result.BackupPath)) { "Backup: não foi possível criar." } else { "Backup: " + $result.BackupPath }
            $PlayniteApi.Dialogs.ShowMessage(
                "Mesclagem concluída.`r`n`r`nEntrada principal: " + $result.Primary.Name + "`r`n" + $backupText + "`r`n`r`nObservação: integrações como Steam podem sobrescrever o tempo jogado numa sincronização futura se a importação de tempo estiver ativada.",
                "Merge Games")
            $window.DialogResult = $true
            $window.Close()
        }
        catch {
            $PlayniteApi.Dialogs.ShowErrorMessage("Falha ao mesclar jogos:`r`n`r`n" + $_.Exception.Message, "Merge Games")
        }
    })

    [void]$window.ShowDialog()
}


# Snapshot da seleção usada para abrir o menu de contexto.
# Em algumas combinações de versão/tema do Playnite, o argumento da ação pode
# chegar contendo apenas o item clicado, mesmo quando havia múltiplos jogos
# selecionados. Guardamos a seleção do menu e também consultamos MainView.
$script:MGLastMenuGames = @()

function Get-MGUniqueGames {
    param($Games)

    $result = @()
    $seen = @{}
    foreach ($game in @($Games)) {
        if ($null -eq $game) { continue }
        try { $key = [string]$game.Id } catch { $key = "" }
        if ([string]::IsNullOrWhiteSpace($key)) { continue }
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $result += $game
        }
    }
    return @($result)
}

function Resolve-MGSelectedGames {
    param($ActionArgs)

    # 1) Fonte oficial da ação do menu.
    $actionGames = @()
    try { $actionGames = Get-MGUniqueGames @($ActionArgs.Games) } catch { }
    if ($actionGames.Count -eq 2) {
        return [PSCustomObject]@{ Games = $actionGames; Source = "ActionArgs.Games"; ActionCount = $actionGames.Count; MainViewCount = -1; CachedCount = -1 }
    }

    # 2) Seleção atual da interface. Esta é a API oficial para os jogos
    # atualmente selecionados e corrige o caso em que a ação recebe só 1.
    $viewGames = @()
    try { $viewGames = Get-MGUniqueGames @($PlayniteApi.MainView.SelectedGames) } catch { }
    if ($viewGames.Count -eq 2) {
        return [PSCustomObject]@{ Games = $viewGames; Source = "MainView.SelectedGames"; ActionCount = $actionGames.Count; MainViewCount = $viewGames.Count; CachedCount = -1 }
    }

    # 3) Snapshot feito no instante em que o menu de contexto foi criado.
    $cachedGames = Get-MGUniqueGames @($script:MGLastMenuGames)
    if ($cachedGames.Count -eq 2) {
        return [PSCustomObject]@{ Games = $cachedGames; Source = "GetGameMenuItems snapshot"; ActionCount = $actionGames.Count; MainViewCount = $viewGames.Count; CachedCount = $cachedGames.Count }
    }

    # 4) Último recurso: às vezes cada fonte contém apenas parte da seleção.
    # Só aceitamos a união se resultar EXATAMENTE em dois IDs distintos.
    $combined = Get-MGUniqueGames @($actionGames + $viewGames + $cachedGames)
    if ($combined.Count -eq 2) {
        return [PSCustomObject]@{ Games = $combined; Source = "combined fallback"; ActionCount = $actionGames.Count; MainViewCount = $viewGames.Count; CachedCount = $cachedGames.Count }
    }

    return [PSCustomObject]@{ Games = @(); Source = "none"; ActionCount = $actionGames.Count; MainViewCount = $viewGames.Count; CachedCount = $cachedGames.Count; CombinedCount = $combined.Count }
}

function Invoke-MGRepairExtraMetadata {
    param($scriptGameMenuItemActionArgs)

    $games = @()
    try { $games = Get-MGUniqueGames @($PlayniteApi.MainView.SelectedGames) } catch { }
    if ($games.Count -eq 0) {
        try { $games = Get-MGUniqueGames @($scriptGameMenuItemActionArgs.Games) } catch { }
    }
    if ($games.Count -eq 0) {
        $PlayniteApi.Dialogs.ShowMessage("Selecione pelo menos um jogo.", "Merge Games — Extra Metadata")
        return
    }

    $ids = New-Object 'System.Collections.Generic.List[System.Guid]'
    $report = New-Object System.Collections.Generic.List[string]
    foreach ($game in $games) {
        try {
            [void](Get-MGExtraMetadataGameDirectory $game.Id $true)

            # v0.1.0-0.1.3 normally hid the secondary entry. If there is
            # exactly one hidden game with the same displayed name, use it as
            # a conservative recovery source for EML files missing from the
            # surviving entry. Existing files are never overwritten here.
            $recovered = New-Object System.Collections.Generic.List[string]
            $hiddenMatches = @($PlayniteApi.Database.Games | Where-Object { $_.Id -ne $game.Id -and $_.Hidden -and $_.Name -eq $game.Name })
            if ($hiddenMatches.Count -eq 1) {
                $candidate = $hiddenMatches[0]
                foreach ($fileName in @("Logo.png","VideoTrailer.mp4","VideoMicrotrailer.mp4")) {
                    $targetDir = Get-MGExtraMetadataGameDirectory $game.Id $true
                    $targetFile = Join-Path $targetDir $fileName
                    if (-not [System.IO.File]::Exists($targetFile)) {
                        if (Copy-MGExtraMetadataAsset $candidate $game $fileName) {
                            [void]$recovered.Add($fileName)
                        }
                    }
                }
                Merge-MGExtraMetadataOtherFiles $candidate $candidate $game
            }

            Refresh-MGGameCollections $game
            Sync-MGExtraMetadataMissingTags $game
            $PlayniteApi.Database.Games.Update($game)
            [void]$ids.Add($game.Id)

            $dir = Get-MGExtraMetadataGameDirectory $game.Id $false
            $logo = Get-MGExtraMetadataAssetText $game "Logo.png"
            $trailer = Get-MGExtraMetadataAssetText $game "VideoTrailer.mp4"
            $micro = Get-MGExtraMetadataAssetText $game "VideoMicrotrailer.mp4"
            $recoveryText = if ($recovered.Count -gt 0) { "`r`n  Recuperado da entrada oculta: " + ($recovered -join ", ") } elseif ($hiddenMatches.Count -gt 1) { "`r`n  Recuperação automática ignorada: há mais de uma entrada oculta com o mesmo nome." } else { "" }
            [void]$report.Add(($game.Name + "`r`n  ID: " + $game.Id + "`r`n  GameId: " + [string]$game.GameId + "`r`n  Pasta EML: " + $dir + "`r`n  Logo: " + $logo + " | Trailer: " + $trailer + " | Micro: " + $micro + $recoveryText))
        }
        catch {
            [void]$report.Add(($game.Name + " — falha: " + $_.Exception.Message))
        }
    }

    try { $PlayniteApi.MainView.SelectGames($ids) } catch { }
    $PlayniteApi.Dialogs.ShowMessage(
        "Reparo concluído. O registro foi regravado sem mudar o ID, GameId, PluginId ou SourceId e a pasta do Extra Metadata Loader foi normalizada.`r`n`r`n" + ($report -join "`r`n`r`n"),
        "Merge Games — Extra Metadata")
}

function Invoke-MergeGames {
    param($scriptGameMenuItemActionArgs)

    $resolved = Resolve-MGSelectedGames $scriptGameMenuItemActionArgs
    $games = @($resolved.Games)
    if ($games.Count -ne 2) {
        $details = "Ação: {0} | Seleção atual: {1} | Snapshot do menu: {2}" -f $resolved.ActionCount, $resolved.MainViewCount, $resolved.CachedCount
        $PlayniteApi.Dialogs.ShowMessage(
            "Não consegui obter exatamente os dois jogos selecionados.`r`n`r`n" +
            "Mantenha Ctrl pressionado, selecione os dois jogos e clique com o botão direito em um deles sem desfazer a seleção.`r`n`r`n" +
            "Diagnóstico: " + $details,
            "Merge Games")
        return
    }

    if ($games[0].IsRunning -or $games[1].IsRunning) {
        $PlayniteApi.Dialogs.ShowMessage("Feche os dois jogos antes de mesclar as entradas.", "Merge Games")
        return
    }

    Show-MGMergeWindow $games[0] $games[1]
}

function GetGameMenuItems {
    param($getGameMenuItemsArgs)

    # Guarde a seleção recebida no momento em que o menu é aberto.
    # Isso serve como fallback caso o ActionArgs.Games venha incompleto.
    try {
        $menuGames = Get-MGUniqueGames @($getGameMenuItemsArgs.Games)
        if ($menuGames.Count -gt 0) { $script:MGLastMenuGames = @($menuGames) }
    } catch { }

    try {
        $currentSelection = Get-MGUniqueGames @($PlayniteApi.MainView.SelectedGames)
        if ($currentSelection.Count -eq 2) { $script:MGLastMenuGames = @($currentSelection) }
    } catch { }

    $item = New-Object Playnite.SDK.Plugins.ScriptGameMenuItem
    $item.Description = "Mesclar jogos..."
    $item.FunctionName = "Invoke-MergeGames"
    $item.MenuSection = "Merge Games"

    $repairItem = New-Object Playnite.SDK.Plugins.ScriptGameMenuItem
    $repairItem.Description = "Reparar integração Extra Metadata Loader"
    $repairItem.FunctionName = "Invoke-MGRepairExtraMetadata"
    $repairItem.MenuSection = "Merge Games"

    return @($item, $repairItem)
}

# Playnite resolves menu actions by exported command name. In v0.1.1 only the two
# public entry points were exported. On some Playnite 10 builds the exported
# action is invoked outside the module-private command lookup, so helper
# functions (for example Resolve-MGSelectedGames) were not visible at runtime.
# Export every module-scope function so the whole helper chain is resolvable.
Export-ModuleMember -Function *
