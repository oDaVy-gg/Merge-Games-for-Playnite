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
