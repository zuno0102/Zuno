using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Authentication.Commands.RefreshToken;
using Zuno.Application.Modules.Authentication.Common;
using Zuno.Domain.Entities;

namespace Zuno.Application.UnitTests.Modules.Authentication.Commands;

/// <summary>A refresh token is used once, even when two refreshes with it arrive at the same instant.</summary>
public class RefreshTokenRaceTests
{
    private readonly Mock<IRefreshTokenRepository> _tokens = new();
    private readonly Mock<IApplicationDbContext> _db = new();
    private readonly RefreshTokenCommandHandler _sut;

    public RefreshTokenRaceTests()
    {
        var jwt = new Mock<IJwtTokenService>();
        jwt.Setup(j => j.HashToken("raw")).Returns("hash");
        jwt.Setup(j => j.GenerateRefreshToken()).Returns("new-raw");
        jwt.Setup(j => j.GenerateAccessToken(It.IsAny<User>())).Returns("access");
        var clock = new Mock<IDateTimeProvider>();
        clock.Setup(c => c.UtcNow).Returns(DateTimeOffset.UtcNow);
        var settings = Options.Create(new JwtSettings
        {
            Issuer = "t",
            Audience = "t",
            SigningKey = new string('a', 32),
            AccessTokenExpiryMinutes = 15,
            RefreshTokenExpiryDays = 14,
        });

        _tokens.Setup(t => t.GetByTokenHashAsync("hash", It.IsAny<CancellationToken>()))
            .ReturnsAsync(new RefreshToken
            {
                UserId = Guid.NewGuid(),
                User = new User { Role = new Role { Name = "Worker" } },
                TokenHash = "hash",
                ExpiresAt = DateTimeOffset.UtcNow.AddDays(1),
            });

        _sut = new RefreshTokenCommandHandler(
            _tokens.Object, _db.Object, jwt.Object, clock.Object, settings,
            new RefreshTokenFactory(jwt.Object, clock.Object, settings));
    }

    [Fact]
    public async Task The_refresh_that_loses_the_race_is_refused_not_a_server_error()
    {
        // What the database reports when another request rotated the same token first.
        _db.Setup(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .ThrowsAsync(new DbUpdateConcurrencyException("row changed"));

        var act = () => _sut.Handle(new RefreshTokenCommand { RefreshToken = "raw" }, default);

        await act.Should().ThrowAsync<UnauthorizedAccessException>().WithMessage("*already been used*");
    }

    [Fact]
    public async Task Reuse_while_another_request_is_revoking_is_still_refused_not_a_server_error()
    {
        // A token already rotated is reuse: every session is revoked. When two such requests race,
        // the second one's revoke conflicts with the first's — that must not become a 500.
        _tokens.Setup(t => t.GetByTokenHashAsync("hash", It.IsAny<CancellationToken>()))
            .ReturnsAsync(new RefreshToken { UserId = Guid.NewGuid(), RevokedAt = DateTimeOffset.UtcNow, ExpiresAt = DateTimeOffset.UtcNow.AddDays(1) });
        _tokens.Setup(t => t.GetActiveTokensForUserAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync([new RefreshToken()]);
        _db.Setup(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .ThrowsAsync(new DbUpdateConcurrencyException("row changed"));

        var act = () => _sut.Handle(new RefreshTokenCommand { RefreshToken = "raw" }, default);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Fact]
    public async Task A_refresh_that_wins_gets_a_new_token()
    {
        var result = await _sut.Handle(new RefreshTokenCommand { RefreshToken = "raw" }, default);

        result.AccessToken.Should().Be("access");
        result.RefreshToken.Should().NotBeNullOrEmpty();
    }
}
