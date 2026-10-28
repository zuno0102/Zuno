using FluentAssertions;
using FluentValidation.TestHelper;
using Zuno.Application.Modules.Business.Commands.UpdateBusinessProfile;

namespace Zuno.Application.UnitTests.Modules.Business.Commands.UpdateBusinessProfile;

public class UpdateBusinessProfileCommandValidatorTests
{
    private readonly UpdateBusinessProfileCommandValidator _sut = new();

    private static UpdateBusinessProfileCommand ValidCommand() => new()
    {
        BusinessName = "Asha Home Services",
    };

    [Fact]
    public async Task Should_Pass_For_Valid_Command()
    {
        var result = await _sut.TestValidateAsync(ValidCommand());
        result.ShouldNotHaveAnyValidationErrors();
    }

    [Fact]
    public async Task Should_Fail_When_BusinessName_Is_Empty()
    {
        var command = ValidCommand();
        command.BusinessName = string.Empty;

        var result = await _sut.TestValidateAsync(command);
        result.ShouldHaveValidationErrorFor(x => x.BusinessName);
    }

    [Theory]
    [InlineData("22AAAAA0000A1Z5")]
    [InlineData("07ABCDE1234F1Z9")]
    public async Task Should_Pass_For_Valid_Gstin(string gstNumber)
    {
        var command = ValidCommand();
        command.GstNumber = gstNumber;

        var result = await _sut.TestValidateAsync(command);
        result.ShouldNotHaveValidationErrorFor(x => x.GstNumber);
    }

    [Theory]
    [InlineData("not-a-gstin")]
    [InlineData("12345")]
    public async Task Should_Fail_For_Invalid_Gstin(string gstNumber)
    {
        var command = ValidCommand();
        command.GstNumber = gstNumber;

        var result = await _sut.TestValidateAsync(command);
        result.ShouldHaveValidationErrorFor(x => x.GstNumber);
    }

    [Fact]
    public async Task Should_Require_City_State_PostalCode_When_AddressLine1_Provided()
    {
        var command = ValidCommand();
        command.AddressLine1 = "12 MG Road";

        var result = await _sut.TestValidateAsync(command);
        result.ShouldHaveValidationErrorFor(x => x.City);
        result.ShouldHaveValidationErrorFor(x => x.State);
        result.ShouldHaveValidationErrorFor(x => x.PostalCode);
    }
}
