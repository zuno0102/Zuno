using FluentAssertions;
using Microsoft.Extensions.Options;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Authentication.Commands.Login;
using Zuno.Application.Modules.Authentication.Common;
using Zuno.Application.Modules.Business.Common;
using Zuno.Domain.Entities;

namespace Zuno.Application.UnitTests.Modules.Authentication.Commands.Login;

public class LoginCommandHandlerTests
{
    private readonly Mock<IUserRepository> _userRepositoryMock = new();
    private readonly Mock<IRefreshTokenRepository> _refreshTokenRepositoryMock = new();
    private readonly Mock<IApplicationDbContext> _dbContextMock = new();
    private readonly Mock<IPasswordHasher> _passwordHasherMock = new();
    private readonly Mock<IJwtTokenService> _jwtTokenServiceMock = new();
    private readonly Mock<IDateTimeProvider> _dateTimeProviderMock = new();
    private readonly DateTimeOffset _now = new(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);

    private readonly LoginCommandHandler _sut;

    public LoginCommandHandlerTests()
    {
        _dateTimeProviderMock.Setup(p => p.UtcNow).Returns(_now);

        var jwtSettings = Options.Create(new JwtSettings
        {
            Issuer = "test",
            Audience = "test",
            SigningKey = new string('a', 32),
            AccessTokenExpiryMinutes = 15,
            RefreshTokenExpiryDays = 14,
        });

        var refreshTokenFactory = new RefreshTokenFactory(_jwtTokenServiceMock.Object, _dateTimeProviderMock.Object, jwtSettings);

        _sut = new LoginCommandHandler(
            _userRepositoryMock.Object,
            _refreshTokenRepositoryMock.Object,
            _dbContextMock.Object,
            _passwordHasherMock.Object,
            _jwtTokenServiceMock.Object,
            _dateTimeProviderMock.Object,
            jwtSettings,
            new BusinessApproval(
                new BusinessVerificationCheck(), Options.Create(new VerificationSettings()), _dateTimeProviderMock.Object),
            refreshTokenFactory);
    }

    private static User CreateUser(bool isActive = true, short failedAttempts = 0, DateTimeOffset? lockoutEndDate = null) => new()
    {
        Id = Guid.NewGuid(),
        Email = "customer@example.com",
        PasswordHash = "hashed-password",
        FirstName = "Asha",
        LastName = "Rao",
        IsActive = isActive,
        FailedLoginAttempts = failedAttempts,
        LockoutEndDate = lockoutEndDate,
        Role = new Role { Id = Guid.NewGuid(), Name = "Customer" },
    };

    [Fact]
    public async Task Should_Return_AuthResponse_On_Successful_Login()
    {
        var user = CreateUser();
        _userRepositoryMock
            .Setup(r => r.GetByEmailOrPhoneAsync("customer@example.com", It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);
        _passwordHasherMock.Setup(h => h.Verify("correct-password", user.PasswordHash)).Returns(true);
        _jwtTokenServiceMock.Setup(j => j.GenerateAccessToken(user)).Returns("access-token");
        _jwtTokenServiceMock.Setup(j => j.GenerateRefreshToken()).Returns("raw-refresh-token");
        _jwtTokenServiceMock.Setup(j => j.HashToken("raw-refresh-token")).Returns("hashed-refresh-token");

        var result = await _sut.Handle(
            new LoginCommand { EmailOrPhone = "customer@example.com", Password = "correct-password" },
            CancellationToken.None);

        result.AccessToken.Should().Be("access-token");
        result.RefreshToken.Should().Be("raw-refresh-token");
        user.FailedLoginAttempts.Should().Be(0);
        user.LastLoginDate.Should().Be(_now);
        _refreshTokenRepositoryMock.Verify(r => r.Add(It.IsAny<RefreshToken>()), Times.Once);
        _dbContextMock.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Should_Throw_When_User_Not_Found()
    {
        _userRepositoryMock
            .Setup(r => r.GetByEmailOrPhoneAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((User?)null);

        var act = () => _sut.Handle(
            new LoginCommand { EmailOrPhone = "unknown@example.com", Password = "whatever" },
            CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Fact]
    public async Task Should_Throw_And_Increment_FailedAttempts_On_Wrong_Password()
    {
        var user = CreateUser(failedAttempts: 2);
        _userRepositoryMock
            .Setup(r => r.GetByEmailOrPhoneAsync("customer@example.com", It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);
        _passwordHasherMock.Setup(h => h.Verify("wrong-password", user.PasswordHash)).Returns(false);

        var act = () => _sut.Handle(
            new LoginCommand { EmailOrPhone = "customer@example.com", Password = "wrong-password" },
            CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        user.FailedLoginAttempts.Should().Be(3);
        user.LockoutEndDate.Should().BeNull();
    }

    [Fact]
    public async Task Should_Lock_Account_After_Fifth_Failed_Attempt()
    {
        var user = CreateUser(failedAttempts: 4);
        _userRepositoryMock
            .Setup(r => r.GetByEmailOrPhoneAsync("customer@example.com", It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);
        _passwordHasherMock.Setup(h => h.Verify("wrong-password", user.PasswordHash)).Returns(false);

        var act = () => _sut.Handle(
            new LoginCommand { EmailOrPhone = "customer@example.com", Password = "wrong-password" },
            CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        user.FailedLoginAttempts.Should().Be(5);
        user.LockoutEndDate.Should().Be(_now.AddMinutes(15));
    }

    [Fact]
    public async Task Should_Throw_When_Account_Is_Locked_Out()
    {
        // User.IsLockedOut compares against the real system clock, not IDateTimeProvider,
        // so the lockout must be set relative to actual UtcNow to simulate an active lockout.
        var user = CreateUser(lockoutEndDate: DateTimeOffset.UtcNow.AddMinutes(10));
        _userRepositoryMock
            .Setup(r => r.GetByEmailOrPhoneAsync("customer@example.com", It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);

        var act = () => _sut.Handle(
            new LoginCommand { EmailOrPhone = "customer@example.com", Password = "whatever" },
            CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        _passwordHasherMock.Verify(h => h.Verify(It.IsAny<string>(), It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task Should_Throw_When_User_Is_Inactive()
    {
        var user = CreateUser(isActive: false);
        _userRepositoryMock
            .Setup(r => r.GetByEmailOrPhoneAsync("customer@example.com", It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);

        var act = () => _sut.Handle(
            new LoginCommand { EmailOrPhone = "customer@example.com", Password = "whatever" },
            CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }
}
