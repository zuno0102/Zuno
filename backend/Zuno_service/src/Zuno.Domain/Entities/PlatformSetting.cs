using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

/// <summary>
/// One business rule the app owner can change without a release — a radius, a limit, a default.
/// </summary>
/// <remarks>
/// Stored as text against a well-known key and read through the platform settings store, which
/// checks each value against its allowed range and falls back to the built-in default for anything
/// missing or out of range. A bad row can therefore never take a rule outside what the code supports.
/// </remarks>
public class PlatformSetting : BaseEntity
{
    public string Key { get; set; } = string.Empty;

    public string Value { get; set; } = string.Empty;

    /// <summary>What the rule controls, in words the admin screen can show.</summary>
    public string Description { get; set; } = string.Empty;
}
