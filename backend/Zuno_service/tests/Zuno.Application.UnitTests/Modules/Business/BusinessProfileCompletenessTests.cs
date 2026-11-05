using FluentAssertions;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Application.Modules.Worker.Common;
using Zuno.Domain.Entities;

namespace Zuno.Application.UnitTests.Modules.Business;

/// <summary>
/// A business profile is complete once it has a UPI ID — every payment QR is made from it — and the
/// ID is kept in one spelling, so Rent and Service show the same QR.
/// </summary>
public class BusinessProfileCompletenessTests
{
    private static BusinessProfileDto Read(string? upiId) =>
        new BusinessOwnerProfile { BusinessName = "Joy Events", UpiId = upiId }
            .ToDto(new TestPlatformSettings().Current);

    [Fact]
    public void A_profile_without_a_UPI_ID_says_what_is_missing()
    {
        var profile = Read(null);

        profile.MissingDetails.Should().Equal("UPI ID");
        profile.UpiId.Should().BeNull();
    }

    [Fact]
    public void A_profile_with_a_UPI_ID_is_complete_and_shows_it()
    {
        var profile = Read("joyevents@okhdfcbank");

        profile.MissingDetails.Should().BeEmpty();
        profile.UpiId.Should().Be("joyevents@okhdfcbank");
    }

    [Theory]
    [InlineData(" JoyEvents@OkHdfcBank ", "joyevents@okhdfcbank")]
    [InlineData("joy.events@ybl", "joy.events@ybl")]
    public void A_UPI_ID_is_kept_trimmed_and_lower_case(string typed, string kept) =>
        UpiFormat.Normalize(typed).Should().Be(kept);
}
