using FluentAssertions;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Application.Posts;
using Zuno.Marketplace.Domain.Exceptions;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.UnitTests;

/// <summary>
/// A product put up like on a shopping site: colours and sizes each with their stock, an MRP, the
/// business's own details, an address with a pin, and where it ships.
/// </summary>
public class ProductDetailsTests
{
    private static readonly Guid Clothing = MarketplaceCatalogSeedData.SubId(3, 2);

    private static CreateMarketplacePostCommand Shirt(Action<CreateMarketplacePostCommand>? change = null) =>
        TestMarketplace.Car(c =>
        {
            c.SubCategoryId = Clothing;
            c.Title = "Cotton shirt";
            c.Price = 499m;
            c.Condition = "New";
            c.Quantity = null;
            c.Attributes = new() { ["fabric"] = "Cotton", ["for"] = "Men" };
            c.Variants =
            [
                new() { Colour = "Red", Size = "M", Stock = 4 },
                new() { Colour = "Red", Size = "L", Stock = 0 },
                new() { Colour = "Blue", Size = "M", Stock = 6, Price = 549m },
            ];
            change?.Invoke(c);
        });

    private static async Task<IEnumerable<string>> FailedAsync(Func<Task> act) =>
        (await act.Should().ThrowAsync<ValidationException>()).Which.Errors.Select(e => e.ErrorMessage);

    [Fact]
    public async Task Create_WithColoursAndSizes_KeepsEachStock_AndTheTotal()
    {
        using var test = new TestMarketplace();

        var dto = await test.SaveHandlers.Handle(Shirt(), default);

        dto.Variants.Select(v => (v.Name, v.Stock, v.Price)).Should().Equal(
            ("Red · M", 4, (decimal?)null), ("Red · L", 0, null), ("Blue · M", 6, 549m));
        dto.Quantity.Should().Be(10, "the colours and sizes added up");
        dto.IsOutOfStock.Should().BeFalse();
        dto.Attributes.Should().Contain("fabric", "Cotton");
    }

    [Fact]
    public async Task Create_EveryVariantAtZero_IsOutOfStock()
    {
        using var test = new TestMarketplace();

        var dto = await test.SaveHandlers.Handle(Shirt(c => c.Variants.ForEach(v => v.Stock = 0)), default);

        dto.IsOutOfStock.Should().BeTrue();
    }

    [Fact]
    public async Task Create_TheSameColourAndSizeTwice_IsRefused()
    {
        using var test = new TestMarketplace();

        var failed = await FailedAsync(() => test.SaveHandlers.Handle(
            Shirt(c => c.Variants.Add(new() { Colour = "red ", Size = "m", Stock = 1 })), default));

        failed.Should().Contain("Red · M is listed twice.");
    }

    [Fact]
    public void Create_AVariantWithNeitherColourNorSize_IsRefused()
    {
        var validator = new CreateMarketplacePostCommandValidator(Options.Create(new MarketplaceSettings()));

        var result = validator.Validate(Shirt(c => c.Variants = [new() { Stock = 1 }]));

        result.Errors.Select(e => e.ErrorMessage).Should().Contain("Give a colour, a size, or both.");
    }

    [Fact]
    public async Task Create_UsedProductWithColours_IsRefused()
    {
        using var test = new TestMarketplace();

        var failed = await FailedAsync(() => test.SaveHandlers.Handle(Shirt(c => c.Condition = "Used"), default));

        failed.Should().Contain("Only a new product has colours and sizes, each with its stock.");
    }

    [Fact]
    public async Task Update_KeepsNamedVariants_RemovesTheRest_AddsNewOnes()
    {
        using var test = new TestMarketplace();
        var created = await test.SaveHandlers.Handle(Shirt(), default);
        var redM = created.Variants.Single(v => v.Name == "Red · M");
        var update = new UpdateMarketplacePostCommand { Id = created.Id };
        Copy(Shirt(), update);
        update.Variants =
        [
            new() { Id = redM.Id, Colour = "Red", Size = "M", Stock = 9 },
            new() { Colour = "Green", Size = "S", Stock = 2 },
        ];

        var dto = await test.SaveHandlers.Handle(update, default);

        dto.Variants.Select(v => v.Name).Should().Equal("Red · M", "Green · S");
        dto.Variants[0].Id.Should().Be(redM.Id, "an edit keeps the row an order may name");
        dto.Quantity.Should().Be(11);
        (await test.NewContext().PostVariants.CountAsync()).Should().Be(2, "removed ones leave the list");
    }

    [Fact]
    public async Task UpdateStock_OneVariant_ChangesItAndTheTotal()
    {
        using var test = new TestMarketplace();
        var created = await test.SaveHandlers.Handle(Shirt(), default);
        var redL = created.Variants.Single(v => v.Name == "Red · L");

        var dto = await test.StockHandler.Handle(
            new UpdateMarketplacePostStockCommand { Id = created.Id, VariantId = redL.Id, Quantity = 5 }, default);

        dto.Variants.Single(v => v.Id == redL.Id).Stock.Should().Be(5);
        dto.Quantity.Should().Be(15);
    }

    [Fact]
    public async Task UpdateStock_WithoutSayingWhichVariant_IsRefused()
    {
        using var test = new TestMarketplace();
        var created = await test.SaveHandlers.Handle(Shirt(), default);

        var act = () => test.StockHandler.Handle(new UpdateMarketplacePostStockCommand { Id = created.Id, Quantity = 5 }, default);

        await act.Should().ThrowAsync<DomainException>().WithMessage("Choose which colour or size to update.");
    }

    [Fact]
    public async Task Create_MrpBelowThePrice_IsRefused_AndAboveIsKept()
    {
        using var test = new TestMarketplace();

        var failed = await FailedAsync(() => test.SaveHandlers.Handle(Shirt(c => c.OriginalPrice = 300m), default));
        failed.Should().Contain("The MRP cannot be less than the price.");

        var dto = await test.SaveHandlers.Handle(Shirt(c => c.OriginalPrice = 799m), default);
        dto.OriginalPrice.Should().Be(799m);
    }

    [Fact]
    public async Task Create_OwnDetails_AreKeptInOrder_ButNotTwiceOrBesideAnAskedOne()
    {
        using var test = new TestMarketplace();

        var twice = await FailedAsync(() => test.SaveHandlers.Handle(Shirt(c => c.CustomDetails =
            [new() { Name = "Fit", Value = "Slim" }, new() { Name = "fit", Value = "Regular" }]), default));
        twice.Should().Contain("fit is added twice.");

        var asked = await FailedAsync(() => test.SaveHandlers.Handle(Shirt(c => c.CustomDetails =
            [new() { Name = "Fabric", Value = "Khadi" }]), default));
        asked.Should().Contain("Fabric is already asked above.");

        var dto = await test.SaveHandlers.Handle(Shirt(c => c.CustomDetails =
            [new() { Name = " Fit ", Value = "Slim" }, new() { Name = "Sleeve", Value = "Full" }]), default);
        dto.CustomDetails.Select(d => (d.Name, d.Value)).Should().Equal(("Fit", "Slim"), ("Sleeve", "Full"));
    }

    [Fact]
    public async Task Create_ShippingToChosenDistricts_NeedsKnownOnes()
    {
        using var test = new TestMarketplace();

        var none = await FailedAsync(() => test.SaveHandlers.Handle(Shirt(c => c.DeliversEverywhere = false), default));
        none.Should().Contain("Choose the districts it ships to, or ship everywhere.");

        var unknown = await FailedAsync(() => test.SaveHandlers.Handle(
            Shirt(c => { c.DeliversEverywhere = false; c.DeliveryDistrictIds = [Guid.NewGuid()]; }), default));
        unknown.Should().Contain("Choose the districts it ships to from the list.");

        var dto = await test.SaveHandlers.Handle(
            Shirt(c => { c.DeliversEverywhere = false; c.DeliveryDistrictIds = [TestMarketplace.Kanyakumari, TestMarketplace.Kanyakumari]; c.AddressLine = "12 Main Road"; c.Latitude = 8.3; c.Longitude = 77.2; }),
            default);
        dto.DeliversEverywhere.Should().BeFalse();
        dto.DeliveryDistrictIds.Should().Equal(TestMarketplace.Kanyakumari);
        dto.AddressLine.Should().Be("12 Main Road");
    }

    [Fact]
    public async Task Create_OutsideProducts_AlwaysShipsAnywhere_WithNoColours()
    {
        using var test = new TestMarketplace();

        var dto = await test.SaveHandlers.Handle(test.Biryani(c => { c.DeliversEverywhere = false; c.DeliveryDistrictIds = [TestMarketplace.Kanyakumari]; }), default);

        dto.DeliversEverywhere.Should().BeTrue();
        dto.DeliveryDistrictIds.Should().BeEmpty();
        dto.Variants.Should().BeEmpty();
    }

    private static void Copy(CreateMarketplacePostCommand from, UpdateMarketplacePostCommand to)
    {
        to.CategoryId = from.CategoryId;
        to.SubCategoryId = from.SubCategoryId;
        to.Title = from.Title;
        to.Price = from.Price;
        to.Condition = from.Condition;
        to.DistrictId = from.DistrictId;
        to.Attributes = new(from.Attributes);
    }
}
