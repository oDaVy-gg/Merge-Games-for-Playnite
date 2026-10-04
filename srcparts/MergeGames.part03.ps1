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
