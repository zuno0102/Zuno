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
        new()
        {
            Id = new Guid("c5555555-0000-0000-0000-000000000001"),
            Name = "Standard listing",
            Amount = 49m,
            ListingDays = 30,
            SortOrder = 1,
            IsActive = true,
            CreatedDate = SeedDate,
        },
    ];

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
