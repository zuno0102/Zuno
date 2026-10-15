using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using FluentAssertions;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Services;

namespace Zuno.Infrastructure.UnitTests.Services;

/// <summary>
/// What the tokens this application hands out actually contain, and how long they last.
/// </summary>
/// <remarks>
/// Expiry was the part nobody could check. The HTTP tests prove the API refuses a token whose
/// lifetime has run out, but the token they use is forged by the test — so the one link never
/// covered was whether the app's own tokens expire when the configuration says they should. The
/// only way to watch a real one expire used to be to wait fifteen minutes, so nothing did. With
/// the clock injected, these set it where they need it.
/// </remarks>
public class JwtTokenServiceTests
{
    private const string SigningKey = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    private const string Issuer = "Zuno.Tests";
    private const string Audience = "Zuno.Tests.Client";

    private readonly Mock<IDateTimeProvider> _clock = new();
    private readonly JwtSettings _settings = new()
    {
        Issuer = Issuer,
        Audience = Audience,
        SigningKey = SigningKey,
        AccessTokenExpiryMinutes = 15,
        RefreshTokenExpiryDays = 14,
    };

    private JwtTokenService Service() => new(Options.Create(_settings), _clock.Object);

    private static User AUser(string role = "Customer") => new()
    {
        Id = Guid.NewGuid(),
        Email = "asha@example.com",
        FirstName = "Asha",
        LastName = "Rao",
        Role = new Role { Name = role },
    };

    /// <summary>The validation the API itself applies, so these tests agree with production.</summary>
    private static TokenValidationParameters ValidationParameters() => new()
    {
        ValidateIssuer = true,
        ValidIssuer = Issuer,
        ValidateAudience = true,
        ValidAudience = Audience,
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(SigningKey)),
        ValidateLifetime = true,
        ClockSkew = TimeSpan.Zero,
    };

    [Fact]
    public void An_access_token_lasts_exactly_as_long_as_the_setting_says()
    {
        var issuedAt = new DateTimeOffset(2026, 3, 1, 9, 0, 0, TimeSpan.Zero);
        _clock.Setup(c => c.UtcNow).Returns(issuedAt);
        _settings.AccessTokenExpiryMinutes = 15;

        var token = new JwtSecurityTokenHandler().ReadJwtToken(Service().GenerateAccessToken(AUser()));

        token.ValidTo.Should().Be(issuedAt.UtcDateTime.AddMinutes(15));
    }

    [Fact]
    public void Changing_the_setting_changes_the_lifetime()
    {
        var issuedAt = new DateTimeOffset(2026, 3, 1, 9, 0, 0, TimeSpan.Zero);
        _clock.Setup(c => c.UtcNow).Returns(issuedAt);
        _settings.AccessTokenExpiryMinutes = 60;

        var token = new JwtSecurityTokenHandler().ReadJwtToken(Service().GenerateAccessToken(AUser()));

        token.ValidTo.Should().Be(issuedAt.UtcDateTime.AddHours(1));
    }

    [Fact]
    public void A_fresh_access_token_passes_the_validation_the_api_applies()
    {
        _clock.Setup(c => c.UtcNow).Returns(DateTimeOffset.UtcNow);

        var raw = Service().GenerateAccessToken(AUser());

        var act = () => new JwtSecurityTokenHandler().ValidateToken(raw, ValidationParameters(), out _);

        act.Should().NotThrow();
    }

    /// <remarks>
    /// Issued as though a quarter of an hour ago, so a fifteen-minute token has just run out. The
    /// validator uses the real clock, which is what makes this a genuine expiry rather than a
    /// simulated one.
    /// </remarks>
    [Fact]
    public void An_access_token_past_its_expiry_is_refused()
    {
        _clock.Setup(c => c.UtcNow).Returns(DateTimeOffset.UtcNow.AddMinutes(-16));
        _settings.AccessTokenExpiryMinutes = 15;

        var raw = Service().GenerateAccessToken(AUser());

        var act = () => new JwtSecurityTokenHandler().ValidateToken(raw, ValidationParameters(), out _);

        act.Should().Throw<SecurityTokenExpiredException>();
    }

    [Fact]
    public void An_access_token_says_who_the_person_is_and_what_they_may_do()
    {
        _clock.Setup(c => c.UtcNow).Returns(DateTimeOffset.UtcNow);
        var user = AUser("BusinessOwner");

        var token = new JwtSecurityTokenHandler().ReadJwtToken(Service().GenerateAccessToken(user));

        token.Issuer.Should().Be(Issuer);
        token.Audiences.Should().Contain(Audience);
        token.Claims.Should().Contain(c => c.Type == ClaimTypes.Role && c.Value == "BusinessOwner");
        token.Claims.Should().Contain(c => c.Type == ClaimTypes.NameIdentifier && c.Value == user.Id.ToString());
        token.Claims.Should().Contain(c => c.Type == "sub" && c.Value == user.Id.ToString());
        token.Claims.Should().Contain(c => c.Type == "email" && c.Value == user.Email);
        token.Claims.Should().Contain(c => c.Type == "jti");
    }

    [Fact]
    public void Two_tokens_for_the_same_person_are_still_distinguishable()
    {
        // The jti is what makes one token tellable from another; without it two tokens issued in
        // the same second are byte-identical and nothing could ever single one out.
        _clock.Setup(c => c.UtcNow).Returns(DateTimeOffset.UtcNow);
        var user = AUser();
        var service = Service();
        var handler = new JwtSecurityTokenHandler();

        var first = handler.ReadJwtToken(service.GenerateAccessToken(user));
        var second = handler.ReadJwtToken(service.GenerateAccessToken(user));

        first.Claims.First(c => c.Type == "jti").Value
            .Should().NotBe(second.Claims.First(c => c.Type == "jti").Value);
    }

    [Fact]
    public void An_account_with_no_email_still_gets_a_token()
    {
        // Signing up with a phone number only is allowed, so this must not throw or emit an empty
        // email claim.
        _clock.Setup(c => c.UtcNow).Returns(DateTimeOffset.UtcNow);
        var user = AUser();
        user.Email = null;

        var token = new JwtSecurityTokenHandler().ReadJwtToken(Service().GenerateAccessToken(user));

        token.Claims.Should().NotContain(c => c.Type == "email");
        token.Claims.Should().Contain(c => c.Type == ClaimTypes.NameIdentifier);
    }

    [Fact]
    public void Refresh_tokens_are_random_and_url_safe()
    {
        var service = Service();

        var tokens = Enumerable.Range(0, 50).Select(_ => service.GenerateRefreshToken()).ToList();

        tokens.Distinct().Should().HaveCount(50);
        tokens.Should().OnlyContain(t => !t.Contains('+') && !t.Contains('/') && !t.Contains('='));
        tokens.Should().OnlyContain(t => t.Length >= 32);
    }

    [Fact]
    public void A_refresh_token_is_stored_as_a_hash_not_as_itself()
    {
        var service = Service();
        var raw = service.GenerateRefreshToken();

        var hash = service.HashToken(raw);

        hash.Should().NotBe(raw);
        hash.Should().HaveLength(64).And.MatchRegex("^[0-9A-F]+$");
        service.HashToken(raw).Should().Be(hash, "the same token must always hash the same way");
        service.HashToken(service.GenerateRefreshToken()).Should().NotBe(hash);
    }

    [Fact]
    public void A_password_reset_token_names_the_person_it_was_issued_for()
    {
        _clock.Setup(c => c.UtcNow).Returns(DateTimeOffset.UtcNow);
        var userId = Guid.NewGuid();
        var service = Service();

        service.ValidatePasswordResetToken(service.GeneratePasswordResetToken(userId))
            .Should().Be(userId);
    }

    [Fact]
    public void A_password_reset_token_stops_working_after_half_an_hour()
    {
        _clock.Setup(c => c.UtcNow).Returns(DateTimeOffset.UtcNow.AddMinutes(-31));
        var service = Service();

        service.ValidatePasswordResetToken(service.GeneratePasswordResetToken(Guid.NewGuid()))
            .Should().BeNull();
    }

    [Fact]
    public void An_access_token_cannot_be_used_to_reset_a_password()
    {
        // Both are signed with the same key, so what separates them is the purpose claim. Without
        // that check, anyone holding a normal sign-in token could change the password on the
        // account — which is the whole point of a reset token being a different thing.
        _clock.Setup(c => c.UtcNow).Returns(DateTimeOffset.UtcNow);
        var service = Service();

        service.ValidatePasswordResetToken(service.GenerateAccessToken(AUser()))
            .Should().BeNull();
    }

    [Theory]
    [InlineData("")]
    [InlineData("not-a-token")]
    [InlineData("a.b.c")]
    public void Rubbish_is_not_a_password_reset_token(string value)
    {
        Service().ValidatePasswordResetToken(value).Should().BeNull();
    }

    [Fact]
    public void A_password_reset_token_signed_with_another_key_is_refused()
    {
        _clock.Setup(c => c.UtcNow).Returns(DateTimeOffset.UtcNow);
        var forger = new JwtTokenService(
            Options.Create(new JwtSettings
            {
                Issuer = Issuer,
                Audience = Audience,
                SigningKey = new string('b', 32),
                AccessTokenExpiryMinutes = 15,
                RefreshTokenExpiryDays = 14,
            }),
            _clock.Object);

        var forged = forger.GeneratePasswordResetToken(Guid.NewGuid());

        Service().ValidatePasswordResetToken(forged).Should().BeNull();
    }

    [Fact]
    public void A_password_reset_token_from_another_issuer_is_refused()
    {
        _clock.Setup(c => c.UtcNow).Returns(DateTimeOffset.UtcNow);
        var elsewhere = new JwtTokenService(
            Options.Create(new JwtSettings
            {
                Issuer = "Somebody.Else",
                Audience = Audience,
                SigningKey = SigningKey,
                AccessTokenExpiryMinutes = 15,
                RefreshTokenExpiryDays = 14,
            }),
            _clock.Object);

        var foreign = elsewhere.GeneratePasswordResetToken(Guid.NewGuid());

        Service().ValidatePasswordResetToken(foreign).Should().BeNull();
    }
}
