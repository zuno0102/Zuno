namespace Zuno.Domain.Common;

/// <summary>
/// The largest amount any money column can hold. A fact about the storage — numeric(10,2) — not a
/// business rule, so it lives here once instead of being retyped in every validator.
/// </summary>
public static class MoneyLimits
{
    public const decimal MaxAmount = 99_999_999.99m;
}
