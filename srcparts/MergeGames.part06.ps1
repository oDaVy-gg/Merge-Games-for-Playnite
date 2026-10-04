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
