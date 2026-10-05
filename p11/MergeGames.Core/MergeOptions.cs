namespace MergeGames.Playnite11;

public enum ValueChoice
{
    GameA,
    GameB,
    Merge
}

public enum SecondaryDisposition
{
    Keep,
    Hide,
    Delete
}

public sealed class MergeOptions
{
    public bool PrimaryIsA { get; set; } = true;
    public ValueChoice Name { get; set; } = ValueChoice.GameA;
    public ValueChoice SortingName { get; set; } = ValueChoice.GameA;
    public ValueChoice Platforms { get; set; } = ValueChoice.Merge;
    public ValueChoice Genres { get; set; } = ValueChoice.Merge;
    public ValueChoice Developers { get; set; } = ValueChoice.Merge;
    public ValueChoice Publishers { get; set; } = ValueChoice.Merge;
    public ValueChoice Categories { get; set; } = ValueChoice.Merge;
    public ValueChoice Tags { get; set; } = ValueChoice.Merge;
    public ValueChoice Features { get; set; } = ValueChoice.Merge;
    public ValueChoice Series { get; set; } = ValueChoice.Merge;
    public ValueChoice Regions { get; set; } = ValueChoice.Merge;
    public ValueChoice AgeRatings { get; set; } = ValueChoice.Merge;
    public ValueChoice Links { get; set; } = ValueChoice.Merge;
    public ValueChoice MediaFiles { get; set; } = ValueChoice.Merge;
    public bool SumPlayTime { get; set; } = true;
    public bool UseMostRecentLastPlayed { get; set; } = true;
    public bool UseOldestAddedDate { get; set; } = true;
    public SecondaryDisposition SecondaryDisposition { get; set; } = SecondaryDisposition.Hide;
}
