using FluentAssertions;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Infrastructure.Persistence.Seed;

namespace Zuno.Rent.UnitTests;

public class RentalItemValidatorTests : IDisposable
{
    private readonly TestRent _rent = new();

    public void Dispose() => _rent.Dispose();

    [Fact]
    public async Task A_complete_item_passes()
    {
        var result = await Validate(TestRent.Machine());

        result.IsValid.Should().BeTrue(string.Join("; ", result.Errors));
    }

    [Fact]
    public async Task No_sub_category_is_allowed()
    {
        (await Validate(TestRent.Machine(c => c.RentalSubCategoryId = null))).IsValid.Should().BeTrue();
    }

    public static TheoryData<string, Action<CreateRentalItemCommand>> Invalid => new()
    {
        { "RentalCategoryId", c => c.RentalCategoryId = Guid.Empty },
        { "RentalCategoryId", c => { c.RentalCategoryId = Guid.NewGuid(); c.RentalSubCategoryId = null; } },
        { "RentalSubCategoryId", c => c.RentalSubCategoryId = TestRent.PlasticChairs },
        { "RentalSubCategoryId", c => c.RentalSubCategoryId = Guid.NewGuid() },
        { "Name", c => c.Name = "   " },
        { "Name", c => c.Name = new string('x', 201) },
        { "Description", c => c.Description = new string('x', 1001) },
        { "PriceType", c => c.PriceType = "PerPerson" },
        { "PriceType", c => c.PriceType = "2" },
        { "PriceType", c => c.PriceType = "" },
        { "Price", c => c.Price = 0 },
        { "Price", c => c.Price = 10_000_001 },
        { "QuantityOwned", c => c.QuantityOwned = 0 },
        { "QuantityOwned", c => c.QuantityOwned = 100_001 },
        { "DistrictIds", c => c.DistrictIds = [] },
        { "DistrictIds", c => c.DistrictIds = [Guid.NewGuid()] },
        { "DistrictIds", c => c.DistrictIds = [TestRent.Ernakulam, Guid.NewGuid()] },
    };

    [Theory]
    [MemberData(nameof(Invalid))]
    public async Task Each_rule_names_its_field(string field, Action<CreateRentalItemCommand> breakIt)
    {
        var result = await Validate(TestRent.Machine(breakIt));

        result.Errors.Select(e => e.PropertyName).Should().Contain(field);
    }

    [Theory]
    [InlineData(1)]
    [InlineData(100_000)]
    public async Task Quantity_limits_are_inclusive(int quantity)
    {
        (await Validate(TestRent.Machine(c => c.QuantityOwned = quantity))).IsValid.Should().BeTrue();
    }

    [Fact]
    public async Task Price_at_the_maximum_is_allowed()
    {
        (await Validate(TestRent.Machine(c => c.Price = 10_000_000))).IsValid.Should().BeTrue();
    }

    [Fact]
    public async Task An_inactive_category_is_refused()
    {
        var category = _rent.Db.RentalCategories.Single(c => c.Id == RentalCategorySeedData.ToolsMachines);
        category.IsActive = false;
        await _rent.Db.SaveChangesAsync();

        var result = await Validate(TestRent.Machine());

        result.Errors.Select(e => e.PropertyName).Should().Contain("RentalCategoryId");
    }

    [Fact]
    public async Task An_inactive_sub_category_is_refused()
    {
        var sub = _rent.Db.RentalSubCategories.Single(s => s.Id == TestRent.CuttingMachine);
        sub.IsActive = false;
        await _rent.Db.SaveChangesAsync();

        var result = await Validate(TestRent.Machine());

        result.Errors.Select(e => e.PropertyName).Should().Contain("RentalSubCategoryId");
    }

    [Fact]
    public async Task The_same_district_twice_counts_once()
    {
        (await Validate(TestRent.Machine(c => c.DistrictIds = [TestRent.Ernakulam, TestRent.Ernakulam]))).IsValid.Should().BeTrue();
    }

    [Fact]
    public async Task Edit_needs_an_item_id_and_the_same_field_rules()
    {
        var validator = new UpdateRentalItemCommandValidator(_rent.Db, _rent.Settings);

        var result = await validator.ValidateAsync(TestRent.Edit(Guid.Empty, c => c.QuantityOwned = 0));

        result.Errors.Select(e => e.PropertyName).Should().Contain(["Id", "QuantityOwned"]);
    }

    [Theory]
    [InlineData(-1, false)]
    [InlineData(0, true)]
    [InlineData(2, true)]
    [InlineData(3, false)]
    public void Photo_slots_run_from_0_to_2(int slot, bool valid)
    {
        var validator = new SetRentalItemImageCommandValidator(_rent.Settings);

        validator.Validate(new SetRentalItemImageCommand { RentalItemId = Guid.NewGuid(), SlotIndex = slot }).IsValid.Should().Be(valid);
    }

    private Task<FluentValidation.Results.ValidationResult> Validate(CreateRentalItemCommand command) =>
        new CreateRentalItemCommandValidator(_rent.Db, _rent.Settings).ValidateAsync(command);
}
