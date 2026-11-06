using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Customer;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.UnitTests;

/// <summary>
/// A customer's mobile is checked with a one-time code before they book rent items with it — once per
/// number. The code expires, allows a few wrong tries, and cannot be sent again and again.
/// </summary>
public class PhoneVerificationTests : IDisposable
{
    private static readonly Guid Customer = Guid.NewGuid();
    private static readonly Guid Other = Guid.NewGuid();

    private readonly TestRent _rent = new(Customer);
    private readonly FakeSender _sender = new();
    private readonly SettableClock _clock = new(new DateTimeOffset(2026, 11, 6, 10, 0, 0, TimeSpan.Zero));
    private readonly PhoneOtpSettings _settings = new();

    public void Dispose() => _rent.Dispose();

    private RentalPhoneVerificationHandlers Handlers => new(_rent.User, _rent.Db, _sender, Options.Create(_settings), _clock);

    private Task<RentalPhoneCodeSentDto> SendAsync(string phone = "98765 43210") =>
        Handlers.Handle(new SendRentalPhoneCodeCommand { Phone = phone }, default);

    private Task<RentalPhoneDto> VerifyAsync(string code, string phone = "9876543210") =>
        Handlers.Handle(new VerifyRentalPhoneCodeCommand { Phone = phone, Code = code }, default);

    private static string Wrong(string code) => code == "000000" ? "111111" : "000000";

    [Fact]
    public async Task The_right_code_verifies_the_number_and_the_code_is_not_kept()
    {
        var sent = await SendAsync();

        sent.Phone.Should().Be("9876543210", "kept as its 10 digits however it was typed");
        sent.TestCode.Should().MatchRegex("^[0-9]{6}$", "the test sender hands the code back to show");
        sent.ExpiresInSeconds.Should().Be(300);
        _sender.Sent.Should().Equal(("9876543210", sent.TestCode));

        var row = await _rent.Db.RentalPhoneVerifications.AsNoTracking().SingleAsync();
        row.CodeHash.Should().NotBeNullOrEmpty().And.NotContain(sent.TestCode!, "only a hash is stored");

        (await VerifyAsync(sent.TestCode!)).IsVerified.Should().BeTrue();

        row = await _rent.Db.RentalPhoneVerifications.AsNoTracking().SingleAsync();
        row.VerifiedAt.Should().NotBeNull();
        row.CodeHash.Should().BeNull();
        (await Handlers.Handle(new GetRentalPhoneQuery(), default)).Phone.Should().Be("9876543210");
    }

    [Fact]
    public async Task A_verified_number_needs_no_new_code()
    {
        var sent = await SendAsync();
        await VerifyAsync(sent.TestCode!);
        _clock.Now = _clock.Now.AddDays(30);

        var again = await SendAsync();

        again.AlreadyVerified.Should().BeTrue();
        again.TestCode.Should().BeNull();
        _sender.Sent.Should().HaveCount(1);
    }

    [Fact]
    public async Task A_wrong_code_counts_down_the_tries_then_a_new_code_is_needed()
    {
        var code = (await SendAsync()).TestCode!;

        await FluentActions.Awaiting(() => VerifyAsync(Wrong(code)))
            .Should().ThrowAsync<DomainException>().WithMessage("That code is not right. 2 tries left.");
        await FluentActions.Awaiting(() => VerifyAsync(Wrong(code)))
            .Should().ThrowAsync<DomainException>().WithMessage("That code is not right. 1 try left.");
        await FluentActions.Awaiting(() => VerifyAsync(Wrong(code)))
            .Should().ThrowAsync<DomainException>().WithMessage("That code is not right. Ask for a new one.");

        // Even the right code now: the tries are used up.
        await FluentActions.Awaiting(() => VerifyAsync(code))
            .Should().ThrowAsync<DomainException>().WithMessage("Too many wrong codes. Ask for a new one.");

        _clock.Now = _clock.Now.AddSeconds(31);
        var fresh = (await SendAsync()).TestCode!;
        (await VerifyAsync(fresh)).IsVerified.Should().BeTrue();
    }

    [Fact]
    public async Task A_code_stops_working_after_five_minutes()
    {
        var code = (await SendAsync()).TestCode!;
        _clock.Now = _clock.Now.AddMinutes(5).AddSeconds(1);

        await FluentActions.Awaiting(() => VerifyAsync(code))
            .Should().ThrowAsync<DomainException>().WithMessage("This code has expired. Ask for a new one.");
    }

    [Fact]
    public async Task A_new_code_waits_thirty_seconds_and_replaces_the_old_one()
    {
        var first = (await SendAsync()).TestCode!;

        await FluentActions.Awaiting(() => SendAsync())
            .Should().ThrowAsync<DomainException>().WithMessage("Wait 30 seconds before asking for a new code.");

        _clock.Now = _clock.Now.AddSeconds(30);
        var second = (await SendAsync()).TestCode!;

        if (first != second)
        {
            await FluentActions.Awaiting(() => VerifyAsync(first))
                .Should().ThrowAsync<DomainException>().WithMessage("That code is not right*");
        }

        (await VerifyAsync(second)).IsVerified.Should().BeTrue();
    }

    [Fact]
    public async Task No_more_than_five_codes_an_hour_even_over_different_numbers()
    {
        foreach (var phone in new[] { "9876543210", "9876543211", "9876543212", "9876543213", "9876543214" })
        {
            await SendAsync(phone);
        }

        await FluentActions.Awaiting(() => SendAsync("9876543215"))
            .Should().ThrowAsync<DomainException>().WithMessage("Too many codes asked for. Try again in an hour.");

        _clock.Now = _clock.Now.AddHours(1).AddSeconds(1);
        (await SendAsync("9876543215")).TestCode.Should().NotBeNull();
    }

    [Fact]
    public async Task Ask_for_a_code_first_and_another_customers_code_does_not_count()
    {
        await FluentActions.Awaiting(() => VerifyAsync("123456"))
            .Should().ThrowAsync<DomainException>().WithMessage("Ask for a code first.");

        var code = (await SendAsync()).TestCode!;
        _rent.As(Other);

        await FluentActions.Awaiting(() => VerifyAsync(code))
            .Should().ThrowAsync<DomainException>().WithMessage("Ask for a code first.");
        (await Handlers.Handle(new GetRentalPhoneQuery(), default)).IsVerified.Should().BeFalse();
    }

    [Fact]
    public async Task Many_accounts_together_cannot_flood_one_number()
    {
        // Ten customers, one code each, to the same number.
        for (var i = 0; i < 10; i++)
        {
            _rent.As(Guid.NewGuid());
            await SendAsync();
        }

        _rent.As(Guid.NewGuid());
        await FluentActions.Awaiting(() => SendAsync())
            .Should().ThrowAsync<DomainException>().WithMessage("Too many codes were sent to this number. Try again in an hour.");

        _clock.Now = _clock.Now.AddHours(1).AddSeconds(1);
        (await SendAsync()).TestCode.Should().NotBeNull();
    }

    [Fact]
    public async Task A_guess_racing_another_for_the_same_code_is_turned_away_not_given_a_free_try()
    {
        var code = (await SendAsync()).TestCode!;

        // Two requests read the row at once; the other one counts its try first.
        using var racing = _rent.NewContext();
        var row = await racing.RentalPhoneVerifications.SingleAsync();
        var mine = new RentalPhoneVerificationHandlers(_rent.User, _rent.Db, _sender, Options.Create(_settings), _clock);
        var stale = await _rent.Db.RentalPhoneVerifications.SingleAsync();
        row.Attempts++;
        row.ConcurrencyStamp = Guid.NewGuid();
        await racing.SaveChangesAsync();

        // This request still holds the row as it was: its try cannot be counted, so it is not tried.
        stale.Attempts.Should().Be(0);
        await FluentActions.Awaiting(() => mine.Handle(new VerifyRentalPhoneCodeCommand { Phone = "9876543210", Code = code }, default))
            .Should().ThrowAsync<DomainException>().WithMessage("Another request for this number came in at the same time. Try again.");

        using var check = _rent.NewContext();
        var saved = await check.RentalPhoneVerifications.SingleAsync();
        saved.Attempts.Should().Be(1, "only the try that was counted first");
        saved.VerifiedAt.Should().BeNull("the racing request never got to check its code");
    }

    [Fact]
    public async Task The_right_code_also_uses_a_try_so_tries_never_exceed_the_limit()
    {
        var code = (await SendAsync()).TestCode!;
        await FluentActions.Awaiting(() => VerifyAsync(Wrong(code))).Should().ThrowAsync<DomainException>();
        await FluentActions.Awaiting(() => VerifyAsync(Wrong(code))).Should().ThrowAsync<DomainException>();

        (await VerifyAsync(code)).IsVerified.Should().BeTrue("the third and last try may still be the right one");
    }

    [Theory]
    [InlineData("", "Enter your mobile number*")]
    [InlineData("12345", "Enter a 10-digit mobile number*")]
    [InlineData("5876543210", "Enter a 10-digit mobile number*")]
    public async Task Only_an_indian_mobile_is_sent_a_code(string phone, string message)
    {
        var result = await new SendRentalPhoneCodeCommandValidator()
            .ValidateAsync(new SendRentalPhoneCodeCommand { Phone = phone });

        result.Errors.Should().ContainSingle().Which.ErrorMessage.Should().Match(message);
    }

    [Fact]
    public async Task Booking_with_a_number_not_verified_is_refused()
    {
        var verified = await _rent.Db.RentalPhoneVerifications.AnyAsync();
        verified.Should().BeFalse();

        (await RentalPhoneVerificationHandlers.IsVerifiedAsync(_rent.Db, Customer, "9876543210", default)).Should().BeFalse();

        var code = (await SendAsync()).TestCode!;
        (await RentalPhoneVerificationHandlers.IsVerifiedAsync(_rent.Db, Customer, "9876543210", default))
            .Should().BeFalse("a code sent is not a code typed");

        await VerifyAsync(code);
        (await RentalPhoneVerificationHandlers.IsVerifiedAsync(_rent.Db, Customer, "9876543210", default)).Should().BeTrue();
        (await RentalPhoneVerificationHandlers.IsVerifiedAsync(_rent.Db, Other, "9876543210", default))
            .Should().BeFalse("verified by one customer is not verified for another");
    }

    private sealed class FakeSender : IPhoneOtpSender
    {
        public bool ShowsCode => true;

        public List<(string Phone, string? Code)> Sent { get; } = [];

        public Task SendAsync(string phone, string code, CancellationToken cancellationToken)
        {
            Sent.Add((phone, code));
            return Task.CompletedTask;
        }
    }

    private sealed class SettableClock(DateTimeOffset now) : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = now;

        public override DateTimeOffset GetUtcNow() => Now;
    }
}
