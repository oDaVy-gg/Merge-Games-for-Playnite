using System.Collections.Generic;
using System.Threading.Tasks;

namespace MergeGames.Playnite11;

/// <summary>
/// Playnite 11 integration layer.
/// 
/// P11 changed the SDK substantially: .NET 10, async initialization, string
/// library IDs and a redesigned menu system. This class intentionally keeps
/// Playnite-specific wiring separate from MergeEngine.
/// </summary>
public sealed class MergeGamesPlugin : Playnite.Plugin
{
    private Playnite.IPlayniteApi? api;
    private Playnite.ILogger? logger;

    public override async Task InitializeAsync(Playnite.Plugin.InitializeArgs args)
    {
        api = args.Api;
        logger = api.GetLogger("Merge Games", "MergeGames.log");
        await Task.CompletedTask;
    }

    public override IEnumerable<Playnite.MenuItemDescriptor> GetGameMenuItemDescriptors(
        Playnite.Plugin.GetGameMenuItemDescriptorsArgs args)
    {
        yield return new Playnite.MenuItemDescriptor(
            "merge-games.merge",
            "Merge Games > Mesclar jogos...");

        yield return new Playnite.MenuItemDescriptor(
            "merge-games.repair-extra-metadata",
            "Merge Games > Reparar Extra Metadata");
    }

    public override IEnumerable<Playnite.MenuItemImpl> GetGameMenuItems(
        Playnite.Plugin.GetGameMenuItemsArgs args)
    {
        if (api is null)
            yield break;

        yield return new Playnite.MenuItemImpl("merge-games.merge")
        {
            InvokeAsync = async invokeArgs =>
            {
                var games = args.Games;
                if (games is null || games.Count != 2)
                {
                    await api.Dialogs.ShowMessageAsync(
                        "Selecione exatamente dois jogos para mesclar.",
                        "Merge Games");
                    return;
                }

                // TODO P11 UI: ligar a janela de seleção campo a campo.
                // O motor C# já está portado; esta integração será preenchida
                // usando o template oficial do Toolbox da versão P11 instalada.
                var options = new MergeOptions();
                var merged = MergeEngine.Merge(games[0], games[1], options);

                await api.Dialogs.ShowMessageAsync(
                    $"Migração C# ativa. Resultado em memória: {merged.Name}.\n" +
                    "A gravação no banco ficará habilitada após validar os métodos " +
                    "de escrita da SDK P11 usada na sua instalação.",
                    "Merge Games — Playnite 11");
            }
        };
    }
}
