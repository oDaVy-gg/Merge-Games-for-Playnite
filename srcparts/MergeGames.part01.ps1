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
