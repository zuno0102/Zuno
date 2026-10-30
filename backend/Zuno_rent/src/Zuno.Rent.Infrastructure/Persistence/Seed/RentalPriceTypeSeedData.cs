using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;

namespace Zuno.Rent.Infrastructure.Persistence.Seed;

/// <summary>The rate types a business can pick, as the form shows them. Per day first: most rentals are by the day.</summary>
public static class RentalPriceTypeSeedData
{
    public static RentalPriceTypeOption[] Options =>
    [
        new() { Code = RentalPriceType.Daily, Name = "Per day", Detail = "Charged for each day", UnitSuffix = "/day", DisplayOrder = 1 },
        new() { Code = RentalPriceType.Fixed, Name = "Per item", Detail = "One price for each item", UnitSuffix = "/item", DisplayOrder = 2 },
        new() { Code = RentalPriceType.Hourly, Name = "Per hour", Detail = "Charged by the hour", UnitSuffix = "/hr", DisplayOrder = 3 },
    ];
}
