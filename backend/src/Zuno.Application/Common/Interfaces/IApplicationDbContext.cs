using Microsoft.EntityFrameworkCore;
using Zuno.Domain.Entities;

namespace Zuno.Application.Common.Interfaces;

public interface IApplicationDbContext
{
    DbSet<User> Users { get; }

    DbSet<Role> Roles { get; }

    DbSet<RefreshToken> RefreshTokens { get; }

    DbSet<Address> Addresses { get; }

    DbSet<CustomerProfile> CustomerProfiles { get; }

    DbSet<BusinessOwnerProfile> BusinessOwnerProfiles { get; }

    DbSet<WorkerProfile> WorkerProfiles { get; }

    DbSet<AdminProfile> AdminProfiles { get; }

    DbSet<ServiceCategory> ServiceCategories { get; }

    DbSet<ServiceSubCategory> ServiceSubCategories { get; }

    DbSet<State> States { get; }

    DbSet<District> Districts { get; }

    DbSet<BusinessService> BusinessServices { get; }

    DbSet<BusinessServiceMedia> BusinessServiceMedia { get; }

    DbSet<BusinessServiceDistrict> BusinessServiceDistricts { get; }

    DbSet<BusinessServiceVariant> BusinessServiceVariants { get; }

    DbSet<BusinessServiceQuestion> BusinessServiceQuestions { get; }

    DbSet<BookingServiceAnswer> BookingServiceAnswers { get; }

    DbSet<BookingAgreementProposal> BookingAgreementProposals { get; }

    DbSet<BookingMessage> BookingMessages { get; }

    DbSet<BookingThreadClear> BookingThreadClears { get; }

    DbSet<WorkMessage> WorkMessages { get; }

    DbSet<BusinessWorker> BusinessWorkers { get; }

    DbSet<Booking> Bookings { get; }

    DbSet<BookingWorkerAssignment> BookingWorkerAssignments { get; }

    DbSet<HiringPost> HiringPosts { get; }

    DbSet<HiringPostApplication> HiringPostApplications { get; }

    DbSet<HiringPostSalaryAdjustment> HiringPostSalaryAdjustments { get; }


    DbSet<WorkerPayoutDetail> WorkerPayoutDetails { get; }

    DbSet<PayoutBatch> PayoutBatches { get; }

    DbSet<PayoutBatchItem> PayoutBatchItems { get; }

    DbSet<Rating> Ratings { get; }

    DbSet<Notification> Notifications { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken);
}
