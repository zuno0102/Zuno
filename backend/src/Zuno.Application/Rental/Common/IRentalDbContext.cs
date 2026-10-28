using Microsoft.EntityFrameworkCore;
using Zuno.Domain.Rental;

namespace Zuno.Application.Rental.Common;

/// <summary>
/// The Rent module's own data: its tables live in the <c>rental</c> schema, behind their own
/// database context and migrations, so nothing here can change the rest of the app's data.
/// </summary>
public interface IRentalDbContext
{
    DbSet<RentalItem> RentalItems { get; }

    DbSet<RentalItemMedia> RentalItemMedia { get; }

    DbSet<RentalItemDistrict> RentalItemDistricts { get; }

    DbSet<RentalCategory> RentalCategories { get; }

    DbSet<RentalSubCategory> RentalSubCategories { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
