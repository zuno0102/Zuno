using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Common;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence.Interceptors;

namespace Zuno.Infrastructure.Persistence;

public class ZunoDbContext(
    DbContextOptions<ZunoDbContext> options,
    AuditableEntitySaveChangesInterceptor auditInterceptor) : DbContext(options), IApplicationDbContext
{
    public DbSet<User> Users => Set<User>();

    public DbSet<Role> Roles => Set<Role>();

    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

    public DbSet<Address> Addresses => Set<Address>();

    public DbSet<CustomerProfile> CustomerProfiles => Set<CustomerProfile>();

    public DbSet<BusinessOwnerProfile> BusinessOwnerProfiles => Set<BusinessOwnerProfile>();

    public DbSet<WorkerProfile> WorkerProfiles => Set<WorkerProfile>();

    public DbSet<AdminProfile> AdminProfiles => Set<AdminProfile>();

    public DbSet<ServiceCategory> ServiceCategories => Set<ServiceCategory>();

    public DbSet<OrderStageDefinition> OrderStages => Set<OrderStageDefinition>();

    public DbSet<ServiceSubCategory> ServiceSubCategories => Set<ServiceSubCategory>();

    public DbSet<State> States => Set<State>();

    public DbSet<District> Districts => Set<District>();

    public DbSet<BusinessService> BusinessServices => Set<BusinessService>();

    public DbSet<BusinessServiceMedia> BusinessServiceMedia => Set<BusinessServiceMedia>();

    public DbSet<BusinessServiceDistrict> BusinessServiceDistricts => Set<BusinessServiceDistrict>();

    public DbSet<BusinessServiceVariant> BusinessServiceVariants => Set<BusinessServiceVariant>();

    public DbSet<BusinessServiceQuestion> BusinessServiceQuestions => Set<BusinessServiceQuestion>();

    public DbSet<BookingServiceAnswer> BookingServiceAnswers => Set<BookingServiceAnswer>();

    public DbSet<BookingAgreementProposal> BookingAgreementProposals => Set<BookingAgreementProposal>();

    public DbSet<BookingMessage> BookingMessages => Set<BookingMessage>();

    public DbSet<BookingThreadClear> BookingThreadClears => Set<BookingThreadClear>();

    public DbSet<WorkMessage> WorkMessages => Set<WorkMessage>();

    public DbSet<BusinessWorker> BusinessWorkers => Set<BusinessWorker>();

    public DbSet<Booking> Bookings => Set<Booking>();

    public DbSet<BookingWorkerAssignment> BookingWorkerAssignments => Set<BookingWorkerAssignment>();

    public DbSet<HiringPost> HiringPosts => Set<HiringPost>();

    public DbSet<HiringPostApplication> HiringPostApplications => Set<HiringPostApplication>();

    public DbSet<HiringPostSalaryAdjustment> HiringPostSalaryAdjustments => Set<HiringPostSalaryAdjustment>();

    public DbSet<BookingAssignmentSalaryAdjustment> BookingAssignmentSalaryAdjustments => Set<BookingAssignmentSalaryAdjustment>();


    public DbSet<WorkerPayoutDetail> WorkerPayoutDetails => Set<WorkerPayoutDetail>();

    public DbSet<PayoutBatch> PayoutBatches => Set<PayoutBatch>();

    public DbSet<PayoutBatchItem> PayoutBatchItems => Set<PayoutBatchItem>();

    public DbSet<Rating> Ratings => Set<Rating>();

    public DbSet<Notification> Notifications => Set<Notification>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(ZunoDbContext).Assembly);

        foreach (var entityType in modelBuilder.Model.GetEntityTypes())
        {
            if (typeof(IAuditableEntity).IsAssignableFrom(entityType.ClrType))
            {
                modelBuilder.Entity(entityType.ClrType)
                    .HasQueryFilter(BuildSoftDeleteFilter(entityType.ClrType));
            }
        }

        base.OnModelCreating(modelBuilder);
    }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        optionsBuilder.AddInterceptors(auditInterceptor);
        base.OnConfiguring(optionsBuilder);
    }

    private static System.Linq.Expressions.LambdaExpression BuildSoftDeleteFilter(Type clrType)
    {
        var parameter = System.Linq.Expressions.Expression.Parameter(clrType, "entity");
        var property = System.Linq.Expressions.Expression.Property(parameter, nameof(IAuditableEntity.IsDeleted));
        var condition = System.Linq.Expressions.Expression.Equal(property, System.Linq.Expressions.Expression.Constant(false));
        return System.Linq.Expressions.Expression.Lambda(condition, parameter);
    }
}
