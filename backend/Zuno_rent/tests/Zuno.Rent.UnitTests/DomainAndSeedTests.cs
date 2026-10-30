using FluentAssertions;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;
using Zuno.Rent.Domain.Exceptions;
using Zuno.Rent.Infrastructure.Persistence.Seed;

namespace Zuno.Rent.UnitTests;

public class RentalItemRulesTests
{
    [Theory]
    [InlineData(RentalPriceType.Hourly, 80)]
    [InlineData(RentalPriceType.Daily, 12)]
    [InlineData(RentalPriceType.Fixed, 3000)]
    public void A_rate_per_hour_day_or_fixed_is_kept(RentalPriceType type, decimal price)
    {
        var item = new RentalItem();

        item.SetRate(type, price);

        item.PriceType.Should().Be(type);
        item.Price.Should().Be(price);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public void A_rate_of_zero_or_less_is_refused(decimal price)
    {
        var act = () => new RentalItem().SetRate(RentalPriceType.Daily, price);

        act.Should().Throw<DomainException>();
    }

    [Fact]
    public void A_price_type_outside_hour_day_fixed_is_refused()
    {
        var act = () => new RentalItem().SetRate((RentalPriceType)4, 100);

        act.Should().Throw<DomainException>();
    }

    [Theory]
    [InlineData(1)]
    [InlineData(200)]
    public void Quantity_of_one_or_more_is_kept(int quantity)
    {
        var item = new RentalItem();

        item.SetQuantityOwned(quantity);

        item.QuantityOwned.Should().Be(quantity);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-5)]
    public void Quantity_below_one_is_refused(int quantity)
    {
        var act = () => new RentalItem().SetQuantityOwned(quantity);

        act.Should().Throw<DomainException>();
    }
}

public class RentalPricingTests
{
    [Theory]
    [InlineData("Hourly", RentalPriceType.Hourly)]
    [InlineData("daily", RentalPriceType.Daily)]
    [InlineData("FIXED", RentalPriceType.Fixed)]
    public void The_three_rates_are_read_whatever_their_case(string value, RentalPriceType expected) =>
        RentalPricing.Parse(value).Should().Be(expected);

    [Theory]
    [InlineData("PerPerson")]
    [InlineData("3")]
    [InlineData("")]
    [InlineData(null)]
    [InlineData("Weekly")]
    public void Anything_else_is_not_a_rent_rate(string? value) =>
        RentalPricing.Parse(value).Should().BeNull();
}

public class SeedDataTests
{
    [Fact]
    public void District_ids_match_the_service_module()
    {
        // The same ids the Service database holds for these districts. If this fails, a district
        // chosen in the app would mean a different place in Rent than in Service.
        LocationSeedData.DistrictId("Kerala", "Ernakulam").Should().Be(new Guid("106ed900-3319-e16c-796b-a3a11ea1a1e9"));
        LocationSeedData.DistrictId("Kerala", "Thrissur").Should().Be(new Guid("f2a8462b-91c8-a3b9-c33b-58eeda55986e"));
    }

    [Fact]
    public void Every_district_has_a_unique_id_and_a_known_state()
    {
        var states = LocationSeedData.States.Select(s => s.Id).ToHashSet();
        var districts = LocationSeedData.Districts;

        districts.Select(d => d.Id).Should().OnlyHaveUniqueItems();
        districts.Should().OnlyContain(d => states.Contains(d.StateId));
    }

    [Fact]
    public void Categories_and_sub_categories_are_consistent()
    {
        var categories = RentalCategorySeedData.Categories;
        var subs = RentalCategorySeedData.SubCategories;

        categories.Should().HaveCount(7);
        categories.Select(c => c.Slug).Should().OnlyHaveUniqueItems();
        subs.Select(s => s.Id).Should().OnlyHaveUniqueItems();
        subs.Should().OnlyContain(s => categories.Any(c => c.Id == s.RentalCategoryId));
        subs.GroupBy(s => s.RentalCategoryId).Should().OnlyContain(g => g.Select(s => s.Slug).Distinct().Count() == g.Count());
        subs.Should().Contain(s => s.Name == "Cutting machine" && s.RentalCategoryId == RentalCategorySeedData.ToolsMachines);
        subs.Should().Contain(s => s.Name == "Plastic chairs" && s.RentalCategoryId == RentalCategorySeedData.FurnitureSeating);
    }
}
