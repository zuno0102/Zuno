using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Application.Modules.Worker.Commands.UpdateMyWorkerProfile;
using Zuno.Application.Modules.Worker.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.UnitTests.Modules.Worker;

/// <summary>
/// A new or changed UPI is verified again before wages can go to it; an unchanged one is left alone;
/// and the worker is told when it changes, in case it was not them.
/// </summary>
public class PayoutDestinationTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 28, 9, 0, 0, TimeSpan.Zero);

    private readonly Guid _userId = Guid.NewGuid();
    private readonly Mock<IPayoutDestinationCheck> _check = new();
    private readonly Mock<INotificationSender> _notifications = new();
    private readonly List<WorkerPayoutDetail> _added = [];
    private readonly WorkerProfile _profile;
    private readonly UpdateMyWorkerProfileCommandHandler _sut;

    public PayoutDestinationTests()
    {
        _profile = new WorkerProfile { Id = Guid.NewGuid(), UserId = _userId, User = new User { Id = _userId } };

        var currentUser = new Mock<ICurrentUserService>();
        currentUser.Setup(c => c.UserId).Returns(_userId);
        var clock = new Mock<IDateTimeProvider>();
        clock.Setup(c => c.UtcNow).Returns(Now);
        var earnings = new Mock<IWorkerEarningsService>();
        earnings.Setup(e => e.GetAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>())).ReturnsAsync(default(WorkerEarningsRollup));

        var payouts = new Mock<DbSet<WorkerPayoutDetail>>();
        payouts.Setup(p => p.Add(It.IsAny<WorkerPayoutDetail>()))
            .Callback<WorkerPayoutDetail>(_added.Add);
        var db = new Mock<IApplicationDbContext>();
        db.Setup(d => d.WorkerProfiles).Returns(() => TestDbSet.From(_profile));
        db.Setup(d => d.WorkerPayoutDetails).Returns(payouts.Object);

        _sut = new UpdateMyWorkerProfileCommandHandler(
            currentUser.Object,
            new Mock<IUserRepository>().Object,
            earnings.Object,
            db.Object,
            clock.Object,
            new TestPlatformSettings(),
            _check.Object,
            _notifications.Object);
    }

    private void CheckSays(bool verified) =>
        _check.Setup(c => c.CheckUpiAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new PayoutCheckResult(verified, verified ? null : "bad"));

    private Task Save(string upi) => _sut.Handle(new UpdateMyWorkerProfileCommand { UpiVpa = upi }, default);

    [Fact]
    public async Task A_first_UPI_that_passes_the_check_can_be_paid()
    {
        CheckSays(verified: true);

        await Save("ravi@okaxis");

        _added.Should().ContainSingle().Which.Should().Match<WorkerPayoutDetail>(p =>
            p.UpiVpa == "ravi@okaxis" && p.VerificationStatus == VerificationStatus.Verified && p.VerifiedAt == Now);
    }

    [Fact]
    public async Task A_changed_UPI_that_fails_the_check_cannot_be_paid()
    {
        _profile.PayoutDetail = new WorkerPayoutDetail
        {
            UpiVpa = "ravi@okaxis",
            VerificationStatus = VerificationStatus.Verified,
            VerifiedAt = Now.AddDays(-30),
            ProviderFundAccountId = "fa_old",
        };
        CheckSays(verified: false);

        await Save("ravi@newbank");

        var payout = _profile.PayoutDetail;
        payout.UpiVpa.Should().Be("ravi@newbank");
        payout.VerificationStatus.Should().Be(VerificationStatus.Pending);
        payout.VerifiedAt.Should().BeNull();
        payout.ProviderFundAccountId.Should().BeNull();
        payout.CanReceivePayouts.Should().BeFalse();
    }

    [Fact]
    public async Task An_unchanged_UPI_is_not_checked_again_and_not_announced()
    {
        _profile.PayoutDetail = new WorkerPayoutDetail { UpiVpa = "ravi@okaxis", VerificationStatus = VerificationStatus.Verified };

        await Save("RAVI@okaxis");

        _check.Verify(c => c.CheckUpiAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Never);
        _notifications.Verify(n => n.NotifyAsync(
            It.IsAny<Guid>(), It.IsAny<NotificationKind>(), It.IsAny<string>(), It.IsAny<string>(),
            It.IsAny<NotificationTarget>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task The_worker_is_told_when_the_UPI_changes_with_the_address_masked()
    {
        _profile.PayoutDetail = new WorkerPayoutDetail { UpiVpa = "ravi@okaxis", VerificationStatus = VerificationStatus.Verified };
        CheckSays(verified: true);

        await Save("anu@okhdfcbank");

        _notifications.Verify(n => n.NotifyAsync(
            _userId,
            NotificationKind.PayoutDestinationChanged,
            It.IsAny<string>(),
            It.Is<string>(body => body.Contains("an***@okhdfcbank") && !body.Contains("anu@")),
            NotificationTarget.Profile,
            Guid.Empty,
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Theory]
    [InlineData("ravi@okaxis", true)]
    [InlineData("r.k-1@ybl", true)]
    [InlineData("ravi", false)]
    [InlineData("@okaxis", false)]
    [InlineData("ravi@", false)]
    [InlineData("ravi@12", false)]
    public async Task The_placeholder_check_is_the_format_rule(string upi, bool verified) =>
        (await new PayoutDestinationCheck().CheckUpiAsync(upi, default)).IsVerified.Should().Be(verified);

    [Theory]
    [InlineData(null, null, "None")]
    [InlineData("ravi@okaxis", VerificationStatus.Pending, "NotVerified")]
    [InlineData("ravi@okaxis", VerificationStatus.Verified, "Ready")]
    public void The_business_is_told_why_a_worker_cannot_be_paid(string? upi, VerificationStatus? status, string expected)
    {
        var workerId = Guid.NewGuid();
        var booking = new Domain.Entities.Booking
        {
            CustomerProfile = new CustomerProfile { User = new User() },
            BusinessOwnerProfile = new BusinessOwnerProfile { User = new User() },
            BusinessService = new BusinessService { ServiceCategory = new ServiceCategory() },
            Address = new Address(),
            WorkerAssignments =
            [
                new BookingWorkerAssignment
                {
                    WorkerProfileId = workerId,
                    WorkerProfile = new WorkerProfile
                    {
                        User = new User { FirstName = "Ravi" },
                        PayoutDetail = upi is null ? null : new WorkerPayoutDetail { UpiVpa = upi, VerificationStatus = status!.Value },
                    },
                    AgreedSalaryAmount = 800,
                },
            ],
        };

        var row = booking.ToDto().AssignedWorkers.Single();

        row.PayoutState.Should().Be(expected);
        row.HasPayoutDetails.Should().Be(expected == "Ready");
    }
}
