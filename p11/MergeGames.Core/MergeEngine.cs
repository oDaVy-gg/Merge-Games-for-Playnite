using System.Collections.ObjectModel;

namespace MergeGames.Playnite11;

/// <summary>
/// Pure merge logic for Playnite 11's Game model. Database writes, UI and
/// extension-specific file migration stay outside this class.
/// </summary>
public static class MergeEngine
{
    public static Playnite.Game Merge(Playnite.Game gameA, Playnite.Game gameB, MergeOptions options)
    {
        ArgumentNullException.ThrowIfNull(gameA);
        ArgumentNullException.ThrowIfNull(gameB);
        ArgumentNullException.ThrowIfNull(options);

        var primarySource = options.PrimaryIsA ? gameA : gameB;
        var result = primarySource.GetCopy();

        result.Name = Pick(gameA.Name, gameB.Name, options.Name);
        result.SortingName = Pick(gameA.SortingName, gameB.SortingName, options.SortingName);

        result.PlatformIds = MergeIds(gameA.PlatformIds, gameB.PlatformIds, options.Platforms);
        result.GenreIds = MergeIds(gameA.GenreIds, gameB.GenreIds, options.Genres);
        result.DeveloperIds = MergeIds(gameA.DeveloperIds, gameB.DeveloperIds, options.Developers);
        result.PublisherIds = MergeIds(gameA.PublisherIds, gameB.PublisherIds, options.Publishers);
        result.CategoryIds = MergeIds(gameA.CategoryIds, gameB.CategoryIds, options.Categories);
        result.TagIds = MergeIds(gameA.TagIds, gameB.TagIds, options.Tags);
        result.FeatureIds = MergeIds(gameA.FeatureIds, gameB.FeatureIds, options.Features);
        result.SeriesIds = MergeIds(gameA.SeriesIds, gameB.SeriesIds, options.Series);
        result.RegionIds = MergeIds(gameA.RegionIds, gameB.RegionIds, options.Regions);
        result.AgeRatingIds = MergeIds(gameA.AgeRatingIds, gameB.AgeRatingIds, options.AgeRatings);

        result.Links = MergeCollection(
            gameA.Links,
            gameB.Links,
            options.Links,
            static x => $"{x.Name}\u001f{x.Url}");

        result.MediaFiles = MergeCollection(
            gameA.MediaFiles,
            gameB.MediaFiles,
            options.MediaFiles,
            static x => $"{x.Type}\u001f{x.Path}");

        if (options.SumPlayTime)
        {
            var sum = (ulong)gameA.PlayTime + gameB.PlayTime;
            result.PlayTime = sum > uint.MaxValue ? uint.MaxValue : (uint)sum;
        }

        if (options.UseMostRecentLastPlayed)
        {
            result.LastPlayedDate = Latest(gameA.LastPlayedDate, gameB.LastPlayedDate);
        }

        if (options.UseOldestAddedDate)
        {
            result.AddedDate = Earliest(gameA.AddedDate, gameB.AddedDate);
        }

        result.Favorite = gameA.Favorite || gameB.Favorite;

        // Playnite 11 replaced P10's PluginId/GameId pair with LibraryId and
        // LibraryGameId. Keep those from the chosen primary entry.
        result.LibraryId = primarySource.LibraryId;
        result.LibraryGameId = primarySource.LibraryGameId;
        result.SourceId = primarySource.SourceId;
        result.InstallState = primarySource.InstallState;
        result.OverrideInstallState = primarySource.OverrideInstallState;
        result.IncludePluginActions = primarySource.IncludePluginActions;

        return result;
    }

    private static T? Pick<T>(T? a, T? b, ValueChoice choice) =>
        choice == ValueChoice.GameB ? b : a;

    private static HashSet<string>? MergeIds(
        HashSet<string>? a,
        HashSet<string>? b,
        ValueChoice choice)
    {
        if (choice == ValueChoice.GameA)
            return a is null ? null : new HashSet<string>(a, StringComparer.Ordinal);
        if (choice == ValueChoice.GameB)
            return b is null ? null : new HashSet<string>(b, StringComparer.Ordinal);

        if (a is null && b is null)
            return null;

        var result = new HashSet<string>(StringComparer.Ordinal);
        if (a is not null) result.UnionWith(a);
        if (b is not null) result.UnionWith(b);
        return result;
    }

    private static ObservableCollection<T>? MergeCollection<T>(
        ObservableCollection<T>? a,
        ObservableCollection<T>? b,
        ValueChoice choice,
        Func<T, string> keySelector)
    {
        if (choice == ValueChoice.GameA)
            return a is null ? null : new ObservableCollection<T>(a);
        if (choice == ValueChoice.GameB)
            return b is null ? null : new ObservableCollection<T>(b);

        if (a is null && b is null)
            return null;

        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var result = new ObservableCollection<T>();

        foreach (var item in (a ?? []).Concat(b ?? []))
        {
            if (seen.Add(keySelector(item)))
                result.Add(item);
        }

        return result;
    }

    private static DateTimeOffset? Latest(DateTimeOffset? a, DateTimeOffset? b)
    {
        if (a is null) return b;
        if (b is null) return a;
        return a >= b ? a : b;
    }

    private static DateTimeOffset? Earliest(DateTimeOffset? a, DateTimeOffset? b)
    {
        if (a is null) return b;
        if (b is null) return a;
        return a <= b ? a : b;
    }
}
