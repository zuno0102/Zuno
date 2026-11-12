using FluentAssertions;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Application.Posts;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.UnitTests;

/// <summary>The category and kind rules, checked without a database.</summary>
public class PostRulesTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 11, 12, 0, 0, TimeSpan.Zero);
    private static readonly MarketplaceSettings Limits = new();

    private static MarketplaceCategory CategoryOf(Guid id)
    {
        var category = MarketplaceCatalogSeedData.Categories.Single(c => c.Id == id);
        category.SubCategories = MarketplaceCatalogSeedData.SubCategories.Where(s => s.CategoryId == id).ToList();
        category.Fields = MarketplaceCatalogSeedData.Fields.Where(f => f.CategoryId == id).ToList();
        return category;
    }

    private static List<string> Errors(Guid categoryId, CreateMarketplacePostCommand command, MarketplaceSettings? limits = null) =>
        MarketplacePostRules.Check(CategoryOf(categoryId), command, Now, limits ?? Limits)
            .Select(f => $"{f.PropertyName}: {f.ErrorMessage}")
            .ToList();

    private static CreateMarketplacePostCommand Food(Action<CreateMarketplacePostCommand>? change = null)
    {
        var command = new CreateMarketplacePostCommand
        {
            Title = "Veg biryani",
            Price = 99,
            OriginalPrice = 180,
            Quantity = 20,
            StartsAt = Now,
            EndsAt = Now.AddHours(2),
            SubCategoryId = MarketplaceCatalogSeedData.SubId(5, 1),
            Attributes = new() { ["food_type"] = "Veg" },
        };
        change?.Invoke(command);
        return command;
    }

    [Fact]
    public void Check_ValidCar_HasNoErrors() =>
        Errors(MarketplaceCatalogSeedData.Products, TestMarketplace.Car()).Should().BeEmpty();

    [Fact]
    public void Check_ListingWithoutPrice_AsksForPrice() =>
        Errors(MarketplaceCatalogSeedData.Products, TestMarketplace.Car(c => c.Price = null))
            .Should().ContainSingle(e => e.StartsWith("Price:"));

    [Fact]
    public void Check_RequiredDetailMissing_NamesTheDetail() =>
        Errors(MarketplaceCatalogSeedData.Products, TestMarketplace.Car(c => c.Attributes.Remove("km_driven")))
            .Should().ContainSingle().Which.Should().Be("Attributes.km_driven: KM driven is required.");

    [Fact]
    public void Check_RequiredDetailBlank_CountsAsMissing() =>
        Errors(MarketplaceCatalogSeedData.Products, TestMarketplace.Car(c => c.Attributes["brand"] = "   "))
            .Should().ContainSingle(e => e.StartsWith("Attributes.brand:"));

    [Theory]
    [InlineData("forty")]
    [InlineData("12,34abc")]
    [InlineData("<script>")]
    public void Check_NumberDetailNotANumber_IsRefused(string value) =>
        Errors(MarketplaceCatalogSeedData.Products, TestMarketplace.Car(c => c.Attributes["km_driven"] = value))
            .Should().ContainSingle().Which.Should().Contain("must be a number");

    [Fact]
    public void Check_SelectValueOutsideOptions_IsRefused() =>
        Errors(MarketplaceCatalogSeedData.Products, TestMarketplace.Car(c => c.Attributes["fuel"] = "Steam"))
            .Should().ContainSingle().Which.Should().Contain("Choose Fuel from the list");

    [Fact]
    public void Check_SelectValueOtherCase_IsRefused() =>
        Errors(MarketplaceCatalogSeedData.Products, TestMarketplace.Car(c => c.Attributes["fuel"] = "petrol"))
            .Should().ContainSingle();

    [Fact]
    public void Check_UnknownDetailKey_IsRefused() =>
        Errors(MarketplaceCatalogSeedData.Products, TestMarketplace.Car(c => c.Attributes["colour"] = "Red"))
            .Should().ContainSingle(e => e.StartsWith("Attributes.colour:"));

    [Fact]
    public void Check_SwitchedOffField_IsNoLongerAsked()
    {
        var category = CategoryOf(MarketplaceCatalogSeedData.Products);
        category.Fields.Single(f => f.Key == "km_driven").IsActive = false;

        MarketplacePostRules.Check(category, TestMarketplace.Car(c => c.Attributes.Remove("km_driven")), Now, Limits)
            .Should().BeEmpty();
    }

    [Fact]
    public void Check_WholesaleInRetailOnlyCategory_IsRefused() =>
        Errors(MarketplaceCatalogSeedData.Products, TestMarketplace.Car(c => { c.TradeType = "Wholesale"; c.MinOrderQuantity = 2; }))
            .Should().ContainSingle(e => e.StartsWith("TradeType:"));

    [Fact]
    public void Check_ValidWholesale_HasNoErrors() =>
        Errors(MarketplaceCatalogSeedData.B2BWholesale, TestMarketplace.Bananas()).Should().BeEmpty();

    [Fact]
    public void Check_WholesaleWithoutMinimumOrder_AsksForIt() =>
        Errors(MarketplaceCatalogSeedData.B2BWholesale, TestMarketplace.Bananas(c => c.MinOrderQuantity = null))
            .Should().ContainSingle(e => e.StartsWith("MinOrderQuantity:"));

    [Theory]
    [InlineData(2000, true)]
    [InlineData(2001, false)]
    public void Check_MinimumOrderAgainstQuantity_BoundaryIsInclusive(int minimum, bool allowed) =>
        Errors(MarketplaceCatalogSeedData.B2BWholesale, TestMarketplace.Bananas(c => c.MinOrderQuantity = minimum))
            .Should().HaveCount(allowed ? 0 : 1);

    [Fact]
    public void Check_ValidFoodOffer_HasNoErrors() =>
        Errors(MarketplaceCatalogSeedData.NearbyFood, Food()).Should().BeEmpty();

    [Theory]
    [InlineData(180)]
    [InlineData(200)]
    public void Check_FoodOfferNotCheaper_IsRefused(decimal offer) =>
        Errors(MarketplaceCatalogSeedData.NearbyFood, Food(c => c.Price = offer))
            .Should().ContainSingle().Which.Should().Contain("less than the usual price");

    [Fact]
    public void Check_FoodOfferWithoutUsualPriceOrPortions_AsksForBoth() =>
        Errors(MarketplaceCatalogSeedData.NearbyFood, Food(c => { c.OriginalPrice = null; c.Quantity = null; }))
            .Should().HaveCount(2);

    [Fact]
    public void Check_FoodOfferWithoutTimes_AsksForThem() =>
        Errors(MarketplaceCatalogSeedData.NearbyFood, Food(c => c.EndsAt = null))
            .Should().ContainSingle().Which.Should().Contain("starts and ends");

    [Fact]
    public void Check_EndBeforeStart_IsRefused() =>
        Errors(MarketplaceCatalogSeedData.NearbyFood, Food(c => c.EndsAt = c.StartsAt))
            .Should().Contain(e => e.Contains("after the start"));

    [Theory]
    [InlineData(24, true)]
    [InlineData(25, false)]
    public void Check_FoodOfferLength_BoundaryIsTheConfiguredHours(int hours, bool allowed) =>
        Errors(MarketplaceCatalogSeedData.NearbyFood, Food(c => c.EndsAt = Now.AddHours(hours)))
            .Should().HaveCount(allowed ? 0 : 1);

    [Fact]
    public void Check_FoodOfferLength_FollowsTheSetting()
    {
        var longer = new MarketplaceSettings { MaxFoodOfferHours = 48 };

        Errors(MarketplaceCatalogSeedData.NearbyFood, Food(c => c.EndsAt = Now.AddHours(30)), longer).Should().BeEmpty();
    }

    [Fact]
    public void Check_EndAlreadyPassed_IsRefused() =>
        Errors(MarketplaceCatalogSeedData.NearbyFood, Food(c => { c.StartsAt = Now.AddHours(-3); c.EndsAt = Now.AddHours(-1); }))
            .Should().ContainSingle().Which.Should().Contain("in the future");

    [Fact]
    public void Check_StartTooFarAhead_IsRefused() =>
        Errors(MarketplaceCatalogSeedData.NearbyFood, Food(c => { c.StartsAt = Now.AddDays(31); c.EndsAt = Now.AddDays(31).AddHours(1); }))
            .Should().ContainSingle(e => e.StartsWith("StartsAt:"));

    [Theory]
    [InlineData(60, true)]
    [InlineData(61, false)]
    public void Check_AdvertisementLength_BoundaryIsTheConfiguredDays(int days, bool allowed)
    {
        var ad = new CreateMarketplacePostCommand
        {
            Title = "Aadi sale",
            StartsAt = Now,
            EndsAt = Now.AddDays(days),
            SubCategoryId = MarketplaceCatalogSeedData.SubId(6, 1),
        };

        Errors(MarketplaceCatalogSeedData.Advertisements, ad).Should().HaveCount(allowed ? 0 : 1);
    }

    [Fact]
    public void Attributes_KeepsOnlyFilledDetails_InFieldOrder_WithNumbersPlain()
    {
        var category = CategoryOf(MarketplaceCatalogSeedData.Products);
        var command = TestMarketplace.Car(c =>
        {
            c.Attributes["km_driven"] = " 48000.50 ";
            c.Attributes["owners"] = "";
        });

        MarketplacePostRules.Attributes(category, command)
            .Select(a => $"{a.Key}={a.Value}")
            .Should().Equal("brand=Maruti", "model_year=2019", "km_driven=48000.50", "fuel=Petrol");
    }

    [Theory]
    [InlineData(null, "Retail")]
    [InlineData("", "Retail")]
    [InlineData("wholesale", "Wholesale")]
    [InlineData("99", "Retail")]
    public void RequestedTradeType_ReadsNameCaseInsensitively(string? sent, string expected) =>
        MarketplacePostRules.RequestedTradeType(new CreateMarketplacePostCommand { TradeType = sent }).ToString().Should().Be(expected);

    [Fact]
    public void Validator_FieldRules_EachReportOnTheirOwn()
    {
        var validator = new CreateMarketplacePostCommandValidator(Options.Create(Limits));
        var command = new CreateMarketplacePostCommand
        {
            Title = new string('t', 121),
            Price = 0,
            Quantity = 0,
            TradeType = "Barter",
            ContactPhone = "12ab",
            Latitude = 8.3,
            Description = new string('d', 2001),
            Attributes = new() { ["brand"] = new string('b', 201) },
        };

        validator.Validate(command).Errors.Select(e => e.PropertyName).Distinct()
            .Should().Contain(["CategoryId", "DistrictId", "Title", "Price", "Quantity", "TradeType", "ContactPhone", "Location", "Description", "Attributes[0]"]);
    }

    [Theory]
    [InlineData(1_000_000_000, true)]
    [InlineData(1_000_000_001, false)]
    public void Validator_Price_BoundaryIsTheConfiguredMaximum(decimal price, bool allowed)
    {
        var validator = new CreateMarketplacePostCommandValidator(Options.Create(Limits));

        validator.Validate(TestMarketplace.Car(c => c.Price = price)).IsValid.Should().Be(allowed);
    }

    [Fact]
    public void Validator_UpdateWithoutId_IsRefused()
    {
        var validator = new UpdateMarketplacePostCommandValidator(Options.Create(Limits));
        var command = new UpdateMarketplacePostCommand { CategoryId = Guid.NewGuid(), DistrictId = Guid.NewGuid(), Title = "x" };

        validator.Validate(command).Errors.Should().ContainSingle(e => e.PropertyName == "Id");
    }
}
