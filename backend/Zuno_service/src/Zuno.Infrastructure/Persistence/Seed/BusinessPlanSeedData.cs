using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Infrastructure.Persistence.Seed;

/// <summary>
/// The plans a business starts with: free Basic (1 live listing in total), and each area and mix of
/// areas monthly and yearly. Starting values only — the Super Admin edits the rows; ids never change.
/// </summary>
public static class BusinessPlanSeedData
{
    private static readonly DateTimeOffset SeedDate = new(2026, 11, 21, 0, 0, 0, TimeSpan.Zero);

    public static readonly Guid BasicPlanId = new("c6666666-0000-0000-0000-000000000001");

    public static SubscriptionPlan[] Plans =>
    [
        new()
        {
            Id = BasicPlanId, Code = "basic", Name = "Basic", IncludesService = true, IncludesRent = true,
            IncludesMarketplace = true, MaxLiveListings = 1, Price = 0m, Period = PlanPeriod.Free,
            IsDefault = true, IsActive = true, SortOrder = 1, CreatedDate = SeedDate,
        },
        .. Paid(2, "service", "Service", s: true, r: false, m: false, 199m, 1999m),
        .. Paid(4, "rent", "Rent", s: false, r: true, m: false, 199m, 1999m),
        .. Paid(6, "marketplace", "Marketplace", s: false, r: false, m: true, 399m, 3999m),
        .. Paid(8, "service-rent", "Service + Rent", s: true, r: true, m: false, 349m, 3499m),
        .. Paid(10, "service-marketplace", "Service + Marketplace", s: true, r: false, m: true, 499m, 4999m),
        .. Paid(12, "rent-marketplace", "Rent + Marketplace", s: false, r: true, m: true, 549m, 5499m),
        .. Paid(14, "all3", "All 3", s: true, r: true, m: true, 699m, 6999m),
    ];

    /// <summary>A plan's monthly and annual rows; ids encode the order (…0002 monthly, …0003 annual).</summary>
    private static SubscriptionPlan[] Paid(int order, string code, string name, bool s, bool r, bool m, decimal monthly, decimal annual) =>
    [
        Row(order, $"{code}-monthly", name, s, r, m, monthly, 30, PlanPeriod.Monthly),
        Row(order + 1, $"{code}-annual", name, s, r, m, annual, 365, PlanPeriod.Annual),
    ];

    private static SubscriptionPlan Row(int order, string code, string name, bool s, bool r, bool m, decimal price, int days, PlanPeriod period) => new()
    {
        Id = new Guid($"c6666666-0000-0000-0000-{order:D12}"),
        Code = code,
        Name = name,
        IncludesService = s,
        IncludesRent = r,
        IncludesMarketplace = m,
        Price = price,
        DurationDays = days,
        Period = period,
        IsActive = true,
        SortOrder = (short)order,
        CreatedDate = SeedDate,
    };
}
