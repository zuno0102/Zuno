using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

/// <summary>One colour the apps paint with, for light and for dark mode, as <c>#AARRGGBB</c>.</summary>
public class ThemeColor : BaseEntity
{
    /// <summary>What it colours, such as <c>status.success</c> or <c>role.worker.seed</c>.</summary>
    public string Key { get; set; } = string.Empty;

    public string LightValue { get; set; } = string.Empty;

    public string DarkValue { get; set; } = string.Empty;
}
