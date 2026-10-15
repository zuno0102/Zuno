using FluentValidation.TestHelper;
using Zuno.Application.Modules.Authentication.Commands.Login;

namespace Zuno.Application.UnitTests.Modules.Authentication.Commands.Login;

public class LoginCommandValidatorTests
{
    private readonly LoginCommandValidator _sut = new();

    [Fact]
    public async Task Should_Pass_For_Valid_Command()
    {
        var result = await _sut.TestValidateAsync(new LoginCommand
        {
            EmailOrPhone = "customer@example.com",
            Password = "whatever",
        });

        result.ShouldNotHaveAnyValidationErrors();
    }

    [Fact]
    public async Task Should_Fail_When_EmailOrPhone_Is_Empty()
    {
        var result = await _sut.TestValidateAsync(new LoginCommand { EmailOrPhone = "", Password = "whatever" });
        result.ShouldHaveValidationErrorFor(x => x.EmailOrPhone);
    }

    [Fact]
    public async Task Should_Fail_When_Password_Is_Empty()
    {
        var result = await _sut.TestValidateAsync(new LoginCommand { EmailOrPhone = "customer@example.com", Password = "" });
        result.ShouldHaveValidationErrorFor(x => x.Password);
    }
}
