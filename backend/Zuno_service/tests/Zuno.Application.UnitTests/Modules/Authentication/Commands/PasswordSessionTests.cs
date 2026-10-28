using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Authentication.Commands.ChangePassword;
using Zuno.Application.Modules.Authentication.Commands.ResetPassword;
using Zuno.Domain.Entities;

namespace Zuno.Application.UnitTests.Modules.Authentication.Commands;

/// <summary>
/// A reset link works once, and a new password ends every session — so neither a leaked link nor a
/// stolen session outlives the owner taking their account back.
/// </summary>
public class PasswordSessionTests
{
    private static readonly DateTimeOffset Now = new(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);

    private readonly User _user = new() { Id = Guid.NewGuid(), PasswordHash = "old-hash" };
    private readonly Mock<IUserRepository> _users = new();
    private readonly Mock<IRefreshTokenRepository> _refreshTokens = new();
    private readonly Mock<IPasswordHasher> _hasher = new();
    private readonly Mock<IJwtTokenService> _jwt = new();
    private readonly Mock<IDateTimeProvider> _clock = new();
    private readonly Mock<IApplicationDbContext> _db = new();
    private readonly List<RefreshToken> _sessions;

    public PasswordSessionTests()
    {
        _users.Setup(u => u.GetByIdAsync(_user.Id, It.IsAny<CancellationToken>())).ReturnsAsync(_user);
        _hasher.Setup(h => h.Hash("New@12345")).Returns("new-hash");
        _hasher.Setup(h => h.Verify("Old@12345", "old-hash")).Returns(true);
        _clock.Setup(c => c.UtcNow).Returns(Now);
        _jwt.Setup(j => j.PasswordStamp(It.IsAny<string>())).Returns((string hash) => "stamp-of-" + hash);

        _sessions = [new RefreshToken { UserId = _user.Id }, new RefreshToken { UserId = _user.Id }];
        _refreshTokens.Setup(r => r.GetActiveTokensForUserAsync(_user.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_sessions);
    }

    private ResetPasswordCommandHandler Reset() =>
        new(_jwt.Object, _users.Object, _refreshTokens.Object, _hasher.Object, _clock.Object, _db.Object);

    private void TokenIssuedAgainst(string passwordHash) =>
        _jwt.Setup(j => j.ValidatePasswordResetToken("link"))
            .Returns(new PasswordResetClaims(_user.Id, "stamp-of-" + passwordHash));

    [Fact]
    public async Task A_reset_link_issued_for_the_current_password_works_and_ends_every_session()
    {
        TokenIssuedAgainst("old-hash");

        await Reset().Handle(new ResetPasswordCommand { Token = "link", NewPassword = "New@12345" }, CancellationToken.None);

        _user.PasswordHash.Should().Be("new-hash");
        _sessions.Should().OnlyContain(s => s.RevokedAt == Now);
    }

    [Fact]
    public async Task A_reset_link_cannot_be_used_twice()
    {
        // Issued against the old password; the password has since changed (by this very link).
        TokenIssuedAgainst("old-hash");
        _user.PasswordHash = "already-changed";

        var replay = () => Reset().Handle(
            new ResetPasswordCommand { Token = "link", NewPassword = "New@12345" }, CancellationToken.None);

        await replay.Should().ThrowAsync<UnauthorizedAccessException>();
        _user.PasswordHash.Should().Be("already-changed");
        _sessions.Should().OnlyContain(s => s.RevokedAt == null);
    }

    [Fact]
    public async Task An_invalid_reset_link_changes_nothing()
    {
        _jwt.Setup(j => j.ValidatePasswordResetToken("link")).Returns((PasswordResetClaims?)null);

        var act = () => Reset().Handle(
            new ResetPasswordCommand { Token = "link", NewPassword = "New@12345" }, CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        _user.PasswordHash.Should().Be("old-hash");
    }

    [Fact]
    public async Task Changing_the_password_ends_every_session()
    {
        var current = new Mock<ICurrentUserService>();
        current.Setup(c => c.UserId).Returns(_user.Id);
        var sut = new ChangePasswordCommandHandler(
            current.Object, _users.Object, _hasher.Object, _refreshTokens.Object, _clock.Object, _db.Object);

        await sut.Handle(
            new ChangePasswordCommand { CurrentPassword = "Old@12345", NewPassword = "New@12345" }, CancellationToken.None);

        _user.PasswordHash.Should().Be("new-hash");
        _sessions.Should().OnlyContain(s => s.RevokedAt == Now && s.ReasonRevoked == "PasswordChanged");
    }

    [Fact]
    public async Task A_wrong_current_password_changes_nothing_and_keeps_sessions()
    {
        var current = new Mock<ICurrentUserService>();
        current.Setup(c => c.UserId).Returns(_user.Id);
        var sut = new ChangePasswordCommandHandler(
            current.Object, _users.Object, _hasher.Object, _refreshTokens.Object, _clock.Object, _db.Object);

        var act = () => sut.Handle(
            new ChangePasswordCommand { CurrentPassword = "Wrong@1234", NewPassword = "New@12345" }, CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        _user.PasswordHash.Should().Be("old-hash");
        _sessions.Should().OnlyContain(s => s.RevokedAt == null);
    }
}
