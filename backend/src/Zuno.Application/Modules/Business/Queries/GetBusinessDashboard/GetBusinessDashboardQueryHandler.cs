using System.Globalization;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;
using Zuno.Domain.Specifications;

namespace Zuno.Application.Modules.Business.Queries.GetBusinessDashboard;

public class GetBusinessDashboardQueryHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext,
    IWorkerScheduleService workerScheduleService,
    IBusinessTrustService trustService)
    : IRequestHandler<GetBusinessDashboardQuery, BusinessDashboardDto>
{
    /// <summary>Months of history on the trend chart.</summary>
    private const int TrendMonths = 6;

    /// <summary>
    /// Rows returned behind each tile. The counts above them are always the true totals — this
    /// only caps how much detail travels, so a long-running business does not ship a thousand
    /// rows to draw one screen.
    /// </summary>
    private const int DetailLimit = 50;

    public async Task<BusinessDashboardDto> Handle(
        GetBusinessDashboardQuery request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var business = await dbContext.BusinessOwnerProfiles
            .FirstOrDefaultAsync(p => p.UserId == userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        // One flat pass over this business's bookings. The category of a booking is the category
        // of the service it was made against; the sub-category is the variant's, which is why the
        // breakdown only works for bookings — a hiring post is a call for workers and has neither.
        var bookings = await dbContext.Bookings
            .Where(b => b.BusinessOwnerProfileId == business.Id)
            .Select(b => new BookingRow
            {
                Id = b.Id,
                Status = b.BookingStatus,
                CompletedAt = b.CompletedAt,
                CancelledAt = b.CancelledAt,
                CancellationReason = b.CancellationReason,
                ScheduledDate = b.ScheduledDate,
                Price = b.PriceQuoted,
                RequiredWorkerCount = b.RequiredWorkerCount,
                City = b.Address.City,
                CustomerName = b.CustomerProfile.User.FirstName
                    + " " + b.CustomerProfile.User.LastName,
                ServiceName = b.BusinessService.Name,
                ServiceCategoryId = b.BusinessService.ServiceCategoryId,
                CategoryName = b.BusinessService.ServiceCategory.Name,
                // Falls back to the service's own name when a booking was made against a service
                // that has no packages — better than an "Uncategorised" bucket nobody can act on.
                SubCategoryName = b.BusinessServiceVariant != null
                        && b.BusinessServiceVariant.ServiceSubCategory != null
                    ? b.BusinessServiceVariant.ServiceSubCategory.Name
                    : b.BusinessService.Name,
                VariantName = b.BusinessServiceVariant != null
                    ? b.BusinessServiceVariant.Name
                    : null,
            })
            .ToListAsync(cancellationToken);

        // Orders closed for good: work done and nobody on the crew still owed. Asked of the
        // database with the same rule that credits the business's record, so the Orders finished
        // card and the record can never disagree.
        var settledIds = (await dbContext.Bookings
                .Where(b => b.BusinessOwnerProfileId == business.Id)
                .Where(BookingWageRules.CountsAsCompleted)
                .Select(b => b.Id)
                .ToListAsync(cancellationToken))
            .ToHashSet();

        var now = dateTimeProvider.UtcNow;
        var byStage = bookings.ToLookup(b =>
            DashboardOrderStages.Of(b.Status, b.ScheduledDate, settledIds.Contains(b.Id), now));

        // Counted, split by category and charted — never listed, so no order is needed.
        var completed = byStage[DashboardOrderStage.Finished].ToList();

        // Newest first: what a business wants from this list is the job they just finished, not
        // the one they finished two years ago. CompletedAt is null on rows completed before it
        // was recorded, so the scheduled date stands in.
        var awaitingPayment = byStage[DashboardOrderStage.AwaitingPayment]
            .OrderByDescending(b => b.CompletedAt ?? b.ScheduledDate)
            .ToList();

        var upcoming = byStage[DashboardOrderStage.Upcoming]
            .OrderBy(b => b.ScheduledDate)
            .ToList();

        var cancelled = byStage[DashboardOrderStage.Cancelled]
            .OrderByDescending(b => b.CancelledAt ?? b.ScheduledDate)
            .ToList();

        var workers = await BuildWorkersAsync(business.Id, cancellationToken);

        // Two counts from one grouped query; deleted services are already filtered out.
        var servicesByActive = await dbContext.BusinessServices
            .Where(s => s.BusinessOwnerProfileId == business.Id)
            .GroupBy(s => s.IsActive)
            .Select(g => new { IsActive = g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.IsActive, g => g.Count, cancellationToken);

        return new BusinessDashboardDto
        {
            EventsCompleted = completed.Count,
            UpcomingEvents = upcoming.Count,
            AwaitingPaymentEvents = awaitingPayment.Count,
            CancelledEvents = cancelled.Count,
            TotalRevenue = completed.Sum(b => b.Price),
            CrewEventsCompleted = await dbContext.HiringPosts
                .Where(p => p.BusinessOwnerProfileId == business.Id)
                .CountAsync(p => p.WorkCompletedAt != null, cancellationToken),
            ActiveWorkers = workers.Count,
            ActiveServices = servicesByActive.GetValueOrDefault(true),
            InactiveServices = servicesByActive.GetValueOrDefault(false),
            ByCategory = BuildBreakdown(completed),
            Trend = BuildTrend(completed, now),
            // Which list a row is on already settles its stage: being on Awaiting payment means
            // finished with a wage owed, which the status alone cannot say.
            AwaitingPayment = awaitingPayment.Take(DetailLimit).Select(b => ToDto(b, OrderStage.AwaitingPayment)).ToList(),
            Upcoming = upcoming.Take(DetailLimit).Select(b => ToDto(b, OrderStages.ForBooking(b.Status))).ToList(),
            Cancelled = cancelled.Take(DetailLimit).Select(b => ToDto(b, OrderStage.Cancelled)).ToList(),
            CrewEvents = await BuildCrewEventsAsync(business.Id, cancellationToken),
            Workers = workers,
            Trust = await trustService.GetAsync(business.Id, cancellationToken),
        };
    }

    private static DashboardEventDto ToDto(BookingRow booking, OrderStage stage) => new()
    {
        Id = booking.Id,
        ServiceName = booking.ServiceName,
        CategoryName = booking.CategoryName,
        // The package as the customer chose it, falling back to how it is filed.
        SubCategoryName = booking.VariantName ?? booking.SubCategoryName,
        CustomerName = booking.CustomerName.Trim(),
        ScheduledDate = booking.ScheduledDate,
        Price = booking.Price,
        RequiredWorkerCount = booking.RequiredWorkerCount,
        Status = booking.Status.ToString(),
        Stage = stage.ToString(),
        CancelledAt = booking.CancelledAt,
        CancellationReason = booking.CancellationReason,
        City = booking.City,
    };

    /// <summary>
    /// Crew events, newest first. Pulled with their applications because "hired" and "settled"
    /// are properties of the whole crew rather than of the post.
    /// </summary>
    private async Task<List<CrewEventDto>> BuildCrewEventsAsync(
        Guid businessId,
        CancellationToken cancellationToken)
    {
        var posts = await dbContext.HiringPosts
            .Include(p => p.Applications)
            .Where(p => p.BusinessOwnerProfileId == businessId)
            .OrderByDescending(p => p.EventDate)
            .Take(DetailLimit)
            .ToListAsync(cancellationToken);

        return posts.Select(p => new CrewEventDto
        {
            Id = p.Id,
            Title = p.Title,
            EventDate = p.EventDate,
            Location = p.Location,
            WorkersNeeded = p.WorkersNeeded,
            WorkersHired = p.FilledCount,
            WorkCompletedAt = p.WorkCompletedAt,
            IsFullySettled = p.IsFullySettled,
            TotalWages = p.TotalPayable,
            OutstandingWages = p.OutstandingAmount,
        }).ToList();
    }

    /// <summary>
    /// The active roster: people who accepted an invitation and were never removed.
    /// </summary>
    /// <remarks>
    /// Invited-but-unanswered and removed workers are left out on purpose. The tile answers "who
    /// can I put on a job", and someone who has not replied yet is not an answer to that.
    /// <para>
    /// Availability is ranked the same way the workers tab ranks it — at work beats booked,
    /// beats free — but counted over <em>this business's own bookings only</em>. The workers tab
    /// counts every business a worker serves, so the two can differ: someone free here may read
    /// as booked there, because they are out on another business's job. Deliberate — this screen
    /// reports the business's own diary — but the difference is real, not an oversight.
    /// </para>
    /// </remarks>
    private async Task<List<DashboardWorkerDto>> BuildWorkersAsync(
        Guid businessId,
        CancellationToken cancellationToken)
    {
        var roster = await dbContext.BusinessWorkers
            .Where(w => w.BusinessOwnerProfileId == businessId
                && w.AssignmentStatus == BusinessWorkerStatus.Active)
            .Select(w => new
            {
                w.WorkerProfileId,
                Name = w.WorkerProfile.User.FirstName + " " + w.WorkerProfile.User.LastName,
                Phone = w.WorkerProfile.User.PhoneNumber,
                Since = w.RespondedAt ?? w.InvitedAt,
            })
            .ToListAsync(cancellationToken);

        if (roster.Count == 0)
        {
            return [];
        }

        var workerIds = roster.Select(w => w.WorkerProfileId).ToList();

        // Availability comes from the schedule service, the one source the workers tab and the
        // schedule screen also read. Counted over every business the worker serves, because
        // someone out on another business's job cannot take yours either.
        var commitments = await workerScheduleService.GetCommitmentsAsync(
            workerIds, cancellationToken);

        var now = dateTimeProvider.UtcNow;

        var atWork = commitments
            .Where(c => c.StartsAt <= now && now < c.EndsAt)
            .Select(c => c.WorkerProfileId)
            .ToHashSet();

        var booked = commitments.Select(c => c.WorkerProfileId).ToHashSet();

        // When the soonest of those starts, so "Booked" can be acted on: someone booked next
        // month is free tomorrow, and a badge with no date cannot say so.
        var busyFrom = commitments
            .GroupBy(c => c.WorkerProfileId)
            .ToDictionary(g => g.Key, g => g.Min(c => c.StartsAt));

        // Experience, unlike availability, *is* scoped to this business: it answers "what have
        // they done for me", and another business's record is not this one's to report.
        var jobsDone = await dbContext.BookingWorkerAssignments
            .Where(a => workerIds.Contains(a.WorkerProfileId)
                && a.Booking.BusinessOwnerProfileId == businessId
                && a.Booking.BookingStatus == BookingStatus.Completed
                && (a.AssignmentStatus == BookingWorkerAssignmentStatus.Accepted
                    || a.AssignmentStatus == BookingWorkerAssignmentStatus.Completed))
            .GroupBy(a => a.WorkerProfileId)
            .Select(g => new { WorkerProfileId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.WorkerProfileId, x => x.Count, cancellationToken);

        return roster
            .Select(w => new DashboardWorkerDto
            {
                WorkerProfileId = w.WorkerProfileId,
                WorkerName = w.Name.Trim(),
                WorkerPhone = w.Phone,
                AvailabilityStatus = atWork.Contains(w.WorkerProfileId)
                    ? "AtWork"
                    : booked.Contains(w.WorkerProfileId)
                        ? "Booked"
                        : "Active",
                JobsCompleted = jobsDone.GetValueOrDefault(w.WorkerProfileId),
                SinceDate = w.Since,
                BusyOn = busyFrom.TryGetValue(w.WorkerProfileId, out var at) ? at : null,
            })
            // Free first, then the most experienced — the order the business reads them in when
            // looking for someone to put on a job.
            .OrderBy(w => w.AvailabilityStatus == "Active" ? 0 : 1)
            .ThenByDescending(w => w.JobsCompleted)
            .ThenBy(w => w.WorkerName)
            .ToList();
    }

    /// <summary>"Painting 2 → Acrylic painting 1, Wall painting 1".</summary>
    private static List<CategoryBreakdownDto> BuildBreakdown(List<BookingRow> completed) => completed
        .GroupBy(b => new { b.ServiceCategoryId, b.CategoryName })
        .Select(categoryGroup => new CategoryBreakdownDto
        {
            ServiceCategoryId = categoryGroup.Key.ServiceCategoryId,
            CategoryName = categoryGroup.Key.CategoryName,
            Count = categoryGroup.Count(),
            Revenue = categoryGroup.Sum(b => b.Price),
            SubCategories = categoryGroup
                .GroupBy(b => b.SubCategoryName)
                .Select(subGroup => new SubCategoryBreakdownDto
                {
                    Name = subGroup.Key,
                    Count = subGroup.Count(),
                    Revenue = subGroup.Sum(b => b.Price),
                })
                .OrderByDescending(s => s.Count)
                .ThenBy(s => s.Name)
                .ToList(),
        })
        .OrderByDescending(c => c.Count)
        .ThenBy(c => c.CategoryName)
        .ToList();

    /// <summary>
    /// Every month in the window, including the empty ones — a chart that silently skips quiet
    /// months makes a business look busier than it was.
    /// </summary>
    private static List<MonthlyActivityDto> BuildTrend(List<BookingRow> completed, DateTimeOffset now)
    {
        var months = new List<MonthlyActivityDto>();

        for (var offset = TrendMonths - 1; offset >= 0; offset--)
        {
            var point = now.AddMonths(-offset);
            var inMonth = completed
                .Where(b => b.CompletedAt is { } at
                    && at.Year == point.Year
                    && at.Month == point.Month)
                .ToList();

            months.Add(new MonthlyActivityDto
            {
                Label = CultureInfo.InvariantCulture.DateTimeFormat
                    .GetAbbreviatedMonthName(point.Month),
                Year = point.Year,
                Month = point.Month,
                Completed = inMonth.Count,
                Revenue = inMonth.Sum(b => b.Price),
            });
        }

        return months;
    }

    /// <summary>Flattened booking, so grouping runs in memory over one query's results.</summary>
    private sealed class BookingRow
    {
        public Guid Id { get; init; }

        public BookingStatus Status { get; init; }

        public DateTimeOffset? CompletedAt { get; init; }

        public DateTimeOffset? CancelledAt { get; init; }

        public string? CancellationReason { get; init; }

        public DateTimeOffset ScheduledDate { get; init; }

        public decimal Price { get; init; }

        public int RequiredWorkerCount { get; init; }

        public string? City { get; init; }

        public string CustomerName { get; init; } = string.Empty;

        public string ServiceName { get; init; } = string.Empty;

        public Guid ServiceCategoryId { get; init; }

        public string CategoryName { get; init; } = string.Empty;

        public string SubCategoryName { get; init; } = string.Empty;

        public string? VariantName { get; init; }
    }
}
