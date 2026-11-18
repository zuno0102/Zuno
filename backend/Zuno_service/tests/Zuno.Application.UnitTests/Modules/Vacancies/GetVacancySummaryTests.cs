using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Vacancies.Queries.GetVacancySummary;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.UnitTests.Modules.Vacancies;

/// <summary>
/// The business home's Full-time jobs tiles. Total posts counts every vacancy the business has
/// posted, closed ones too, so the section stays once it has hired at least once.
/// </summary>
public class GetVacancySummaryTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 27, 10, 0, 0, TimeSpan.Zero);
    private static readonly Guid UserId = Guid.NewGuid();

    [Fact]
    public async Task Handle_CountsEveryPostOfItsOwn_LiveOrNot()
    {
        var business = new BusinessOwnerProfile { Id = Guid.NewGuid(), UserId = UserId, BusinessName = "Shop" };
        var plan = new VacancyFeePlan { Id = Guid.NewGuid(), Name = "Standard", Amount = 49m, ListingDays = 30 };
        var live = new Vacancy { Id = Guid.NewGuid(), Title = "Receptionist", BusinessOwnerProfileId = business.Id };
        live.PriceWith(plan);
        live.RecordPayment("pay_1", Now.AddDays(-1));
        var stopped = new Vacancy
        {
            Id = Guid.NewGuid(),
            Title = "Cook",
            BusinessOwnerProfileId = business.Id,
            VacancyStatus = VacancyStatus.Stopped,
        };
        var someoneElses = new Vacancy { Id = Guid.NewGuid(), Title = "Driver", BusinessOwnerProfileId = Guid.NewGuid() };

        var db = new Mock<IApplicationDbContext>();
        db.Setup(d => d.BusinessOwnerProfiles).Returns(TestDbSet.From(business));
        db.Setup(d => d.Vacancies).Returns(TestDbSet.From(live, stopped, someoneElses));
        db.Setup(d => d.VacancyApplications).Returns(TestDbSet.From<VacancyApplication>());
        var currentUser = new Mock<ICurrentUserService>();
        currentUser.Setup(c => c.UserId).Returns(UserId);
        var clock = new Mock<IDateTimeProvider>();
        clock.Setup(c => c.UtcNow).Returns(Now);

        var summary = await new GetVacancySummaryQueryHandler(currentUser.Object, clock.Object, db.Object)
            .Handle(new GetVacancySummaryQuery(), CancellationToken.None);

        (summary.TotalPosts, summary.ActivePosts).Should().Be((2, 1), "the stopped one still counts as posted");
    }
}
