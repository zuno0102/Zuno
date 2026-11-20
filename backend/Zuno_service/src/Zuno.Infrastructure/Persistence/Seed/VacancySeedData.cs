using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Seed;

/// <summary>
/// The starting job types and listing fee for full-time vacancies. Edit the rows, not this file, to
/// change them on a live system — the super admin screen will manage them.
/// </summary>
public static class VacancySeedData
{
    private static readonly DateTimeOffset SeedDate = new(2026, 10, 27, 0, 0, 0, TimeSpan.Zero);

    public static VacancyJobType[] JobTypes =>
    [
        JobType("c3333333-0000-0000-0000-000000000001", "Full-time", hasFixedLength: false, 1),
        JobType("c3333333-0000-0000-0000-000000000002", "Part-time", hasFixedLength: false, 2),
        JobType("c3333333-0000-0000-0000-000000000003", "Contract", hasFixedLength: true, 3),
        JobType("c3333333-0000-0000-0000-000000000004", "Internship", hasFixedLength: true, 4),
    ];

    public static VacancyFeePlan[] FeePlans =>
    [
        FeePlan("c5555555-0000-0000-0000-000000000001", "1 month", 99m, 30, 1),
        FeePlan("c5555555-0000-0000-0000-000000000002", "2 months", 149m, 60, 2),
        FeePlan("c5555555-0000-0000-0000-000000000003", "6 months", 249m, 180, 3),
    ];

    private static VacancyFeePlan FeePlan(string id, string name, decimal amount, int days, short sortOrder) => new()
    {
        Id = new Guid(id),
        Name = name,
        Amount = amount,
        ListingDays = days,
        SortOrder = sortOrder,
        IsActive = true,
        CreatedDate = SeedDate,
    };

    private static VacancyJobType JobType(string id, string name, bool hasFixedLength, short sortOrder) => new()
    {
        Id = new Guid(id),
        Name = name,
        HasFixedLength = hasFixedLength,
        SortOrder = sortOrder,
        IsActive = true,
        CreatedDate = SeedDate,
    };
}
