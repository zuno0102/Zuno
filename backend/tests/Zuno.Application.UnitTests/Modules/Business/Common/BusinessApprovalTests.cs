using FluentAssertions;
using Microsoft.Extensions.Options;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Business.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.UnitTests.Modules.Business.Common;

/// <summary>
/// Both ways a business is approved go through the same validation: automatically when the flag is
/// on and it passes, otherwise by an admin — whose approval is refused while it does not.
/// </summary>
public class BusinessApprovalTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 28, 9, 0, 0, TimeSpan.Zero);

    private static BusinessApproval Approval(bool autoApprove, params string[] problems)
    {
        var check = new Mock<IBusinessVerificationCheck>();
        check.Setup(c => c.ProblemsAsync(It.IsAny<BusinessOwnerProfile>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(problems);
        var clock = new Mock<IDateTimeProvider>();
        clock.Setup(c => c.UtcNow).Returns(Now);

        return new BusinessApproval(
            check.Object, Options.Create(new VerificationSettings { AutoVerifyBusinesses = autoApprove }), clock.Object);
    }

    private static BusinessOwnerProfile Pending() => new() { VerificationStatus = VerificationStatus.Pending };

    [Fact]
    public async Task Flag_on_and_valid_is_approved_automatically()
    {
        var business = Pending();

        (await Approval(autoApprove: true).TryAutoApproveAsync(business, default)).Should().BeTrue();

        business.VerificationStatus.Should().Be(VerificationStatus.Verified);
        business.VerifiedAt.Should().Be(Now);
    }

    [Fact]
    public async Task Flag_on_but_not_valid_waits_for_an_admin()
    {
        var business = Pending();

        (await Approval(autoApprove: true, "Add your GST number.").TryAutoApproveAsync(business, default))
            .Should().BeFalse();

        business.VerificationStatus.Should().Be(VerificationStatus.Pending);
        business.VerifiedAt.Should().BeNull();
    }

    [Fact]
    public async Task Flag_off_always_waits_for_an_admin()
    {
        var business = Pending();

        (await Approval(autoApprove: false).TryAutoApproveAsync(business, default)).Should().BeFalse();

        business.VerificationStatus.Should().Be(VerificationStatus.Pending);
    }

    [Theory]
    [InlineData(VerificationStatus.Rejected)]
    [InlineData(VerificationStatus.Verified)]
    public async Task Auto_approval_never_overturns_a_decision(VerificationStatus decided)
    {
        // A business an admin rejected must not be approved by simply signing in again.
        var business = new BusinessOwnerProfile { VerificationStatus = decided };

        (await Approval(autoApprove: true).TryAutoApproveAsync(business, default)).Should().BeFalse();

        business.VerificationStatus.Should().Be(decided);
    }

    [Fact]
    public async Task An_admin_approves_a_valid_business()
    {
        var business = Pending();

        (await Approval(autoApprove: false).DecideAsync(business, approve: true, default)).Should().BeEmpty();

        business.VerificationStatus.Should().Be(VerificationStatus.Verified);
        business.VerifiedAt.Should().Be(Now);
    }

    [Fact]
    public async Task An_admin_cannot_approve_a_business_that_fails_validation()
    {
        var business = Pending();

        var problems = await Approval(autoApprove: false, "Upload a shop photo.").DecideAsync(business, approve: true, default);

        problems.Should().Equal("Upload a shop photo.");
        business.VerificationStatus.Should().Be(VerificationStatus.Pending);
    }

    [Fact]
    public async Task An_admin_can_always_reject()
    {
        var business = new BusinessOwnerProfile { VerificationStatus = VerificationStatus.Verified, VerifiedAt = Now };

        (await Approval(autoApprove: false, "anything").DecideAsync(business, approve: false, default)).Should().BeEmpty();

        business.VerificationStatus.Should().Be(VerificationStatus.Rejected);
        business.VerifiedAt.Should().BeNull();
    }

    [Fact]
    public async Task The_placeholder_check_passes_every_business_until_rules_are_written() =>
        (await new BusinessVerificationCheck().ProblemsAsync(Pending(), default)).Should().BeEmpty();
}
