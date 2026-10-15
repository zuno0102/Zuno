using FluentAssertions;
using FluentValidation.TestHelper;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Authentication.Commands.Register;
using Zuno.Domain.Enums;

namespace Zuno.Application.UnitTests.Modules.Authentication.Commands.Register;

public class RegisterUserCommandValidatorTests
{
    private readonly Mock<IUserRepository> _userRepositoryMock = new();
    private readonly RegisterUserCommandValidator _sut;

    public RegisterUserCommandValidatorTests()
    {
        _userRepositoryMock
            .Setup(r => r.ExistsByEmailAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);
        _userRepositoryMock
            .Setup(r => r.ExistsByPhoneNumberAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);

        _sut = new RegisterUserCommandValidator(_userRepositoryMock.Object);
    }

    private static RegisterUserCommand ValidCommand() => new()
    {
        Email = "customer@example.com",
        Password = "Str0ng!Pass",
        FirstName = "Asha",
        LastName = "Rao",
        Role = nameof(UserRoleType.Customer),
    };

    [Fact]
    public async Task Should_Pass_For_Valid_Command()
    {
        var result = await _sut.TestValidateAsync(ValidCommand());
        result.ShouldNotHaveAnyValidationErrors();
    }

    [Fact]
    public async Task Should_Fail_When_Email_And_Phone_Are_Both_Missing()
    {
        var command = ValidCommand();
        command.Email = null;
        command.PhoneNumber = null;

        var result = await _sut.TestValidateAsync(command);
        result.Errors.Should().Contain(e => e.ErrorMessage.Contains("Email or PhoneNumber"));
    }

    [Theory]
    [InlineData("short1!")]
    [InlineData("alllowercase1!")]
    [InlineData("ALLUPPERCASE1!")]
    [InlineData("NoDigitsHere!")]
    [InlineData("NoSpecialChars123")]
    public async Task Should_Fail_For_Weak_Password(string weakPassword)
    {
        var command = ValidCommand();
        command.Password = weakPassword;

        var result = await _sut.TestValidateAsync(command);
        result.ShouldHaveValidationErrorFor(x => x.Password);
    }

    [Fact]
    public async Task Should_Fail_When_Role_Is_SuperAdmin()
    {
        var command = ValidCommand();
        command.Role = nameof(UserRoleType.SuperAdmin);

        var result = await _sut.TestValidateAsync(command);
        result.ShouldHaveValidationErrorFor(x => x.Role);
    }

    [Fact]
    public async Task Should_Fail_When_Email_Already_Exists()
    {
        _userRepositoryMock
            .Setup(r => r.ExistsByEmailAsync("customer@example.com", It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        var result = await _sut.TestValidateAsync(ValidCommand());
        result.ShouldHaveValidationErrorFor(x => x.Email);
    }

    [Fact]
    public async Task Should_Fail_For_Invalid_Indian_Mobile_Number()
    {
        var command = ValidCommand();
        command.Email = null;
        command.PhoneNumber = "12345";

        var result = await _sut.TestValidateAsync(command);
        result.ShouldHaveValidationErrorFor(x => x.PhoneNumber);
    }
}
