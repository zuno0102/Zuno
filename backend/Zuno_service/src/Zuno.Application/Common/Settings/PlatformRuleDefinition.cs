namespace Zuno.Application.Common.Settings;

/// <summary>One changeable rule: where it is stored, what it means, and the range it may take.</summary>
public sealed class PlatformRuleDefinition(
    string key,
    string description,
    double min,
    double max,
    Func<PlatformRules, string> format,
    Func<PlatformRules, string, PlatformRules?> apply)
{
    public string Key { get; } = key;

    public string Description { get; } = description;

    public double Min { get; } = min;

    public double Max { get; } = max;

    /// <summary>The rule's value in <paramref name="rules"/>, as it is stored.</summary>
    public string Format(PlatformRules rules) => format(rules);

    public bool TryApply(PlatformRules rules, string raw, out PlatformRules updated)
    {
        var result = apply(rules, raw.Trim());
        updated = result ?? rules;
        return result is not null;
    }
}
