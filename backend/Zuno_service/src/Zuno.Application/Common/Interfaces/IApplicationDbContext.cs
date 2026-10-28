using Microsoft.EntityFrameworkCore;
using Zuno.Domain.Entities;

namespace Zuno.Application.Common.Interfaces;

public interface IApplicationDbContext
{
    public DbSet<User> Users { get; }

    public DbSet<Role> Roles { get; }

    public DbSet<RefreshToken> RefreshTokens { get; }

    public DbSet<Address> Addresses { get; }

    public DbSet<CustomerProfile> CustomerProfiles { get; }

    public DbSet<BusinessOwnerProfile> BusinessOwnerProfiles { get; }

    public DbSet<WorkerProfile> WorkerProfiles { get; }

    public DbSet<AdminProfile> AdminProfiles { get; }

    public DbSet<ServiceCategory> ServiceCategories { get; }

    public DbSet<OrderStageDefinition> OrderStages { get; }

    public DbSet<ServiceSubCategory> ServiceSubCategories { get; }

    public DbSet<State> States { get; }

    public DbSet<District> Districts { get; }

    public DbSet<BusinessService> BusinessServices { get; }

    public DbSet<BusinessServiceMedia> BusinessServiceMedia { get; }

    public DbSet<BusinessServiceDistrict> BusinessServiceDistricts { get; }

    public DbSet<BusinessServiceVariant> BusinessServiceVariants { get; }

    public DbSet<BusinessServiceQuestion> BusinessServiceQuestions { get; }

    public DbSet<BookingServiceAnswer> BookingServiceAnswers { get; }

    public DbSet<BookingAgreementProposal> BookingAgreementProposals { get; }

    public DbSet<BookingMessage> BookingMessages { get; }

    public DbSet<BookingThreadClear> BookingThreadClears { get; }

    public DbSet<WorkMessage> WorkMessages { get; }

    public DbSet<BusinessWorker> BusinessWorkers { get; }

    public DbSet<Booking> Bookings { get; }

    public DbSet<BookingWorkerAssignment> BookingWorkerAssignments { get; }

    public DbSet<HiringPost> HiringPosts { get; }

    public DbSet<HiringPostApplication> HiringPostApplications { get; }

    public DbSet<HiringPostSalaryAdjustment> HiringPostSalaryAdjustments { get; }

    public DbSet<BookingAssignmentSalaryAdjustment> BookingAssignmentSalaryAdjustments { get; }


    public DbSet<WorkerPayoutDetail> WorkerPayoutDetails { get; }

    public DbSet<PayoutBatch> PayoutBatches { get; }

    public DbSet<PayoutBatchItem> PayoutBatchItems { get; }

    public DbSet<Rating> Ratings { get; }

    public DbSet<Notification> Notifications { get; }

    public DbSet<VacancyJobType> VacancyJobTypes { get; }

    public DbSet<VacancyFeePlan> VacancyFeePlans { get; }

    public DbSet<Vacancy> Vacancies { get; }

    public DbSet<VacancyRequirement> VacancyRequirements { get; }

    public DbSet<VacancyApplication> VacancyApplications { get; }

    public DbSet<VacancyApplicationAnswer> VacancyApplicationAnswers { get; }

    public DbSet<PlatformSetting> PlatformSettings { get; }

    public DbSet<LevelDefinition> LevelDefinitions { get; }

    public DbSet<DisplayLabel> DisplayLabels { get; }

    public DbSet<ThemeColor> ThemeColors { get; }

    public Task<int> SaveChangesAsync(CancellationToken cancellationToken);
}
