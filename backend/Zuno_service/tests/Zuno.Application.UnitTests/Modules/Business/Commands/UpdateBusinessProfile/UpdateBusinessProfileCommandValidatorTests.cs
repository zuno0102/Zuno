using FluentAssertions;
using FluentValidation.TestHelper;
using Zuno.Application.Modules.Business.Commands;
using Zuno.Application.Modules.Business.Commands.SetBusinessUpiId;
using Zuno.Application.Modules.Business.Commands.UpdateBusinessProfile;

namespace Zuno.Application.UnitTests.Modules.Business.Commands.UpdateBusinessProfile;

public class UpdateBusinessProfileCommandValidatorTests
{
    private readonly UpdateBusinessProfileCommandValidator _sut = new();

    private static UpdateBusinessProfileCommand ValidCommand() => new()
    {
        BusinessName = "Asha Home Services",
        UpiId = "asha.home@okhdfcbank",
    };

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task Should_Fail_When_UpiId_Is_Missing(string upiId)
    {
        var command = ValidCommand();
        command.UpiId = upiId;

        var result = await _sut.TestValidateAsync(command);
        result.ShouldHaveValidationErrorFor(x => x.UpiId).WithErrorMessage(BusinessUpiIdRule.Required);
    }

    [Fact]
    public async Task Should_Pass_When_An_Older_App_Leaves_The_UpiId_Out()
    {
        var command = ValidCommand();
        command.UpiId = null;

        var result = await _sut.TestValidateAsync(command);
        result.ShouldNotHaveAnyValidationErrors();
    }

    [Theory]
    [InlineData("ravi-99@ybl")]
    [InlineData("9876543210@paytm")]
    [InlineData("asha_home@axis1")]
    public async Task Should_Pass_For_Ids_Rent_Also_Accepts(string upiId)
    {
        var command = ValidCommand();
        command.UpiId = upiId;

        var result = await _sut.TestValidateAsync(command);
        result.ShouldNotHaveValidationErrorFor(x => x.UpiId);
    }

    [Theory]
    [InlineData("asha")]
    [InlineData("आशा@okaxis")]
    [InlineData("asha@")]
    [InlineData("@okaxis")]
    [InlineData("asha@12")]
    [InlineData("asha home@okaxis")]
    public async Task Should_Fail_For_A_Malformed_UpiId(string upiId)
    {
        var command = ValidCommand();
        command.UpiId = upiId;

        var result = await _sut.TestValidateAsync(command);
        result.ShouldHaveValidationErrorFor(x => x.UpiId);
    }

    [Fact]
    public async Task Should_Pass_For_A_UpiId_With_Spaces_Around_It()
    {
        var command = ValidCommand();
        command.UpiId = "  asha.home@okhdfcbank ";

        var result = await _sut.TestValidateAsync(command);
        result.ShouldNotHaveValidationErrorFor(x => x.UpiId);
    }

    [Fact]
    public async Task Should_Fail_For_A_Too_Long_UpiId()
    {
        var command = ValidCommand();
        command.UpiId = new string('a', 95) + "@okaxis";

        var result = await _sut.TestValidateAsync(command);
        result.ShouldHaveValidationErrorFor(x => x.UpiId);
    }

    [Fact]
    public async Task The_quick_Add_UPI_ID_follows_the_same_rule()
    {
        var quick = new SetBusinessUpiIdCommandValidator();

        (await quick.TestValidateAsync(new SetBusinessUpiIdCommand { UpiId = "" }))
            .ShouldHaveValidationErrorFor(x => x.UpiId).WithErrorMessage(BusinessUpiIdRule.Required);
        (await quick.TestValidateAsync(new SetBusinessUpiIdCommand { UpiId = "asha" }))
            .ShouldHaveValidationErrorFor(x => x.UpiId);
        (await quick.TestValidateAsync(new SetBusinessUpiIdCommand { UpiId = "asha.home@okhdfcbank" }))
            .ShouldNotHaveAnyValidationErrors();
    }

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
