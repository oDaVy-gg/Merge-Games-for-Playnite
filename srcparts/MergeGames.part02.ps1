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

