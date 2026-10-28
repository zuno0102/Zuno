using FluentAssertions;
using FluentValidation.TestHelper;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.Commands.CreateBusinessService;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.UnitTests.Modules.Business.Commands.CreateBusinessService;

/// <summary>
/// The crew-size rule, which now depends on how the service is priced.
/// </summary>
/// <remarks>
/// A per-person service carries a crew size of 0, meaning "agreed with the customer for each
/// order" — the catering case, where ₹500 a head means nothing until somebody says how many.
/// Every other price type still needs a real number, because 0 there would be a job nobody works.
/// </remarks>
public class CreateBusinessServiceCommandValidatorTests
{
    private static readonly Guid CategoryId = Guid.NewGuid();
    private static readonly Guid DistrictId = Guid.NewGuid();

    private readonly CreateBusinessServiceCommandValidator _sut;

    public CreateBusinessServiceCommandValidatorTests()
    {
        var dbContextMock = new Mock<IApplicationDbContext>();
        dbContextMock.Setup(d => d.ServiceCategories).Returns(
            TestDbSet.From(new ServiceCategory { Id = CategoryId, Name = "Catering", IsActive = true }));
        dbContextMock.Setup(d => d.Districts).Returns(
            TestDbSet.From(new District { Id = DistrictId, Name = "Ernakulam" }));

        _sut = new CreateBusinessServiceCommandValidator(dbContextMock.Object);
    }

    private static CreateBusinessServiceCommand Command(
        string priceType,
        int requiredWorkerCount) => new()
    {
        ServiceCategoryId = CategoryId,
        Name = "Wedding catering",
        PriceType = priceType,
        Price = 500,
        RequiredWorkerCount = requiredWorkerCount,
        DistrictIds = [DistrictId],
    };

    [Fact]
    public async Task Should_Accept_Zero_Workers_When_Priced_Per_Person()
    {
        var result = await _sut.TestValidateAsync(
            Command(nameof(PriceType.PerPerson), requiredWorkerCount: 0));

        result.ShouldNotHaveValidationErrorFor(x => x.RequiredWorkerCount);
    }

    [Fact]
    public async Task Should_Refuse_A_Fixed_Crew_Size_On_A_Per_Person_Service()
    {
        // Both numbers would then claim to decide the crew, and the order would contradict one.
        var result = await _sut.TestValidateAsync(
            Command(nameof(PriceType.PerPerson), requiredWorkerCount: 15));

        result.ShouldHaveValidationErrorFor(x => x.RequiredWorkerCount)
            .WithErrorMessage(
                "A per-person service has no fixed crew size — leave it at 0 and agree the number "
                + "with the customer when the order comes in.");
    }

    /// <summary>
    /// Zero is a real answer for any price type, not a missing one.
    /// </summary>
    /// <remarks>
    /// It means "depends on the event — agreed with the customer when the order comes in". A
    /// wedding package can be a flat ₹50,000 and still need a crew that only the guest count
    /// decides, so refusing 0 outside per-person pricing forced businesses to invent a number
    /// their very first order would contradict.
    /// </remarks>
    [Theory]
    [InlineData(nameof(PriceType.Fixed))]
    [InlineData(nameof(PriceType.Hourly))]
    [InlineData(nameof(PriceType.Daily))]
    public async Task Should_Accept_Zero_Workers_For_Every_Price_Type(string priceType)
    {
        var result = await _sut.TestValidateAsync(Command(priceType, requiredWorkerCount: 0));

        result.ShouldNotHaveValidationErrorFor(x => x.RequiredWorkerCount);
    }

    [Theory]
    [InlineData(nameof(PriceType.Fixed))]
    [InlineData(nameof(PriceType.PerPerson))]
    public async Task Should_Refuse_A_Negative_Crew_Size(string priceType)
    {
        var result = await _sut.TestValidateAsync(Command(priceType, requiredWorkerCount: -1));

        result.ShouldHaveValidationErrorFor(x => x.RequiredWorkerCount);
    }

    [Theory]
    [InlineData(nameof(PriceType.Fixed))]
    [InlineData(nameof(PriceType.Hourly))]
    [InlineData(nameof(PriceType.Daily))]
    public async Task Should_Accept_A_Real_Crew_Size_For_Every_Other_Price_Type(string priceType)
    {
        var result = await _sut.TestValidateAsync(Command(priceType, requiredWorkerCount: 15));

        result.ShouldNotHaveValidationErrorFor(x => x.RequiredWorkerCount);
    }

    [Fact]
    public async Task Should_Accept_PerPerson_Whatever_Its_Casing()
    {
        // The wire carries the enum name, and the handler parses it case-insensitively. The
        // crew-size rule has to agree with the handler or the two disagree about what was sent.
        var result = await _sut.TestValidateAsync(Command("perperson", requiredWorkerCount: 0));

        result.ShouldNotHaveValidationErrorFor(x => x.RequiredWorkerCount);
    }

    [Fact]
    public async Task Should_Blame_The_Price_Type_Not_The_Crew_Size_When_It_Is_Nonsense()
    {
        var result = await _sut.TestValidateAsync(Command("Fortnightly", requiredWorkerCount: 3));

        // An unparseable price type must fail as a price type, and take nothing else down with
        // it — a complaint about the crew size would send the business off fixing the wrong field.
        result.ShouldHaveValidationErrorFor(x => x.PriceType);
        result.ShouldNotHaveValidationErrorFor(x => x.RequiredWorkerCount);
    }

    [Fact]
    public void Should_List_PerPerson_As_A_Choice()
    {
        // The validator's message is generated from the enum, so this is really asserting that
        // PerPerson was added to it at all.
        Enum.GetNames<PriceType>().Should().Contain(nameof(PriceType.PerPerson));
    }
}
