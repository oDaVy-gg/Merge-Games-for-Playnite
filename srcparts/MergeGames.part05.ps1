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
