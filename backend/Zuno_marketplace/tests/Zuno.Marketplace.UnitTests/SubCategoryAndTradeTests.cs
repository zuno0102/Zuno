using FluentAssertions;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Application.Admin;
using Zuno.Marketplace.Application.Categories;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.UnitTests;

/// <summary>Four main categories, each with sub-categories; details per sub-category; B2B wholesale only.</summary>
public class SubCategoryAndTradeTests
{
    private static readonly Guid Sarees = MarketplaceCatalogSeedData.SubId(3, 1);
    private static readonly Guid Fruits = MarketplaceCatalogSeedData.SubId(4, 1);

    private static async Task<IEnumerable<string>> FailedPropertiesAsync(Func<Task> act) =>
        (await act.Should().ThrowAsync<ValidationException>()).Which.Errors.Select(e => e.PropertyName);

    [Fact]
    public async Task Create_WithoutSubCategory_WhenTheCategoryHasThem_IsRefused()
    {
        using var test = new TestMarketplace();

        var failed = await FailedPropertiesAsync(() => test.SaveHandlers.Handle(TestMarketplace.Car(c => c.SubCategoryId = null), default));

        failed.Should().Contain("SubCategoryId");
    }

    [Fact]
    public async Task Create_WithAnotherCategorysSubCategory_IsRefused()
    {
        using var test = new TestMarketplace();

        var failed = await FailedPropertiesAsync(() => test.SaveHandlers.Handle(TestMarketplace.Car(c => c.SubCategoryId = Fruits), default));

        failed.Should().Contain("SubCategoryId");
    }

    [Fact]
    public async Task Create_InASwitchedOffSubCategory_IsRefused()
    {
        using var test = new TestMarketplace();
        var vehicles = await test.Db.SubCategories.SingleAsync(s => s.Id == MarketplaceCatalogSeedData.Vehicles);
        vehicles.IsActive = false;
        await test.Db.SaveChangesAsync();

        var failed = await FailedPropertiesAsync(() => test.SaveHandlers.Handle(TestMarketplace.Car(), default));

        failed.Should().Contain("SubCategoryId");
    }

    [Fact]
    public async Task Create_Saree_IsNotAskedTheVehicleDetails_AndSavesItsSubCategory()
    {
        using var test = new TestMarketplace();
        var saree = TestMarketplace.Car(c =>
        {
            c.SubCategoryId = Sarees;
            c.Title = "Kanchipuram silk saree";
            c.Price = 2_400m;
            c.Attributes = new() { ["condition"] = "New" };
        });

        var dto = await test.SaveHandlers.Handle(saree, default);

        dto.CategoryName.Should().Be("Products");
        dto.SubCategoryName.Should().Be("Sarees");
        dto.Attributes.Should().Equal(new Dictionary<string, string> { ["condition"] = "New" });
    }

    [Fact]
    public async Task Create_Saree_WithAVehicleDetail_IsRefused()
    {
        using var test = new TestMarketplace();

        var failed = await FailedPropertiesAsync(() => test.SaveHandlers.Handle(
            TestMarketplace.Car(c => { c.SubCategoryId = Sarees; c.Attributes = new() { ["km_driven"] = "100" }; }),
            default));

        failed.Should().Contain("Attributes.km_driven");
    }

    [Fact]
    public async Task Create_CategoryWideDetail_IsAskedInEverySubCategory()
    {
        using var test = new TestMarketplace();

        var dto = await test.SaveHandlers.Handle(TestMarketplace.Car(c => c.Attributes["condition"] = "Used"), default);

        dto.Attributes["condition"].Should().Be("Used");
    }

    [Fact]
    public async Task Create_B2BSentAsRetail_IsSavedAsWholesale()
    {
        using var test = new TestMarketplace();

        var dto = await test.SaveHandlers.Handle(TestMarketplace.Bananas(c => c.TradeType = "Retail"), default);

        dto.TradeType.Should().Be("Wholesale");
        dto.MinOrderQuantity.Should().Be(100);
    }

    [Theory]
    [InlineData("PriceUnit")]
    [InlineData("MinOrderQuantity")]
    public async Task Create_B2BWithoutUnitOrSmallestOrder_IsRefused(string missing)
    {
        using var test = new TestMarketplace();
        var bananas = TestMarketplace.Bananas(c =>
        {
            if (missing == "PriceUnit")
            {
                c.PriceUnit = null;
            }
            else
            {
                c.MinOrderQuantity = null;
            }
        });

        var failed = await FailedPropertiesAsync(() => test.SaveHandlers.Handle(bananas, default));

        failed.Should().Contain(missing);
    }

    [Theory]
    [InlineData("Retail", "Retail")]
    [InlineData("Wholesale", "Wholesale")]
    public async Task Create_InAnEitherCategory_KeepsWhatTheBusinessChose(string sent, string saved)
    {
        using var test = new TestMarketplace();
        var category = await test.AdminHandlers.Handle(
            new CreateMarketplaceCategoryCommand { Name = "Livestock", Kind = "Listing", TradeMode = "Either", DisplayOrder = 5 }, default);

        var dto = await test.SaveHandlers.Handle(TestMarketplace.Bananas(c =>
        {
            c.CategoryId = category.Id;
            c.SubCategoryId = null;
            c.TradeType = sent;
        }), default);

        dto.TradeType.Should().Be(saved);
        dto.SubCategoryId.Should().BeNull("a category without sub-categories takes posts without one");
    }

    [Fact]
    public async Task Admin_AddSubCategory_ShowsAtOnce_AndADuplicateIsRefused()
    {
        using var test = new TestMarketplace();
        await test.CatalogHandlers.Handle(new GetMarketplaceCategoriesQuery(), default);

        await test.AdminHandlers.Handle(
            new CreateMarketplaceSubCategoryCommand { CategoryId = MarketplaceCatalogSeedData.Products, Name = "Watches", DisplayOrder = 13 }, default);
        var duplicate = () => test.AdminHandlers.Handle(
            new CreateMarketplaceSubCategoryCommand { CategoryId = MarketplaceCatalogSeedData.Products, Name = "WATCHES" }, default);
        var categories = await test.CatalogHandlers.Handle(new GetMarketplaceCategoriesQuery(), default);

        categories.Single(c => c.Id == MarketplaceCatalogSeedData.Products).SubCategories.Should().Contain(s => s.Slug == "watches");
        await duplicate.Should().ThrowAsync<DomainException>();
    }

    [Fact]
    public async Task Admin_HideSubCategory_HidesItAndItsDetailsFromBusinessesButNotTheAdmin()
    {
        using var test = new TestMarketplace();

        await test.AdminHandlers.Handle(new UpdateMarketplaceSubCategoryCommand
        {
            CategoryId = MarketplaceCatalogSeedData.Products,
            Id = MarketplaceCatalogSeedData.Vehicles,
            Name = "Vehicles",
            DisplayOrder = 10,
            IsActive = false,
        }, default);

        var forBusiness = (await test.CatalogHandlers.Handle(new GetMarketplaceCategoriesQuery(), default))
            .Single(c => c.Id == MarketplaceCatalogSeedData.Products);
        var forAdmin = (await test.CatalogHandlers.Handle(new GetMarketplaceCategoriesQuery(IncludeInactive: true), default))
            .Single(c => c.Id == MarketplaceCatalogSeedData.Products);

        forBusiness.SubCategories.Should().NotContain(s => s.Name == "Vehicles");
        forBusiness.Fields.Should().NotContain(f => f.Key == "km_driven");
        forAdmin.SubCategories.Should().ContainSingle(s => s.Name == "Vehicles").Which.IsActive.Should().BeFalse();
    }

    [Fact]
    public async Task Admin_UpdateMissingSubCategory_IsNotFound()
    {
        using var test = new TestMarketplace();

        var act = () => test.AdminHandlers.Handle(
            new UpdateMarketplaceSubCategoryCommand { CategoryId = MarketplaceCatalogSeedData.Products, Id = Fruits, Name = "Fruits" }, default);

        await act.Should().ThrowAsync<EntityNotFoundException>();
    }

    [Fact]
    public async Task Admin_FieldForAnotherCategorysSubCategory_IsNotFound()
    {
        using var test = new TestMarketplace();

        var act = () => test.AdminHandlers.Handle(new CreateMarketplaceFieldCommand
        {
            CategoryId = MarketplaceCatalogSeedData.Products,
            SubCategoryId = Fruits,
            Label = "Size",
            FieldType = "Text",
        }, default);

        await act.Should().ThrowAsync<EntityNotFoundException>();
    }

    [Fact]
    public async Task Admin_SameDetailInTwoSubCategories_IsAllowed_ButNotBesideACategoryWideOne()
    {
        using var test = new TestMarketplace();

        await test.AdminHandlers.Handle(new CreateMarketplaceFieldCommand
        {
            CategoryId = MarketplaceCatalogSeedData.Products,
            SubCategoryId = Sarees,
            Label = "Fabric",
            FieldType = "Text",
        }, default);
        var clothing = await test.AdminHandlers.Handle(new CreateMarketplaceFieldCommand
        {
            CategoryId = MarketplaceCatalogSeedData.Products,
            SubCategoryId = MarketplaceCatalogSeedData.SubId(3, 2),
            Label = "Fabric",
            FieldType = "Text",
        }, default);
        clothing.Fields.Count(f => f.Key == "fabric").Should().Be(2);
        var clash = () => test.AdminHandlers.Handle(new CreateMarketplaceFieldCommand
        {
            CategoryId = MarketplaceCatalogSeedData.Products,
            SubCategoryId = Sarees,
            Label = "Condition",
            FieldType = "Text",
        }, default);

        await clash.Should().ThrowAsync<DomainException>().WithMessage("*already asks a detail called 'Condition'*");
    }

    [Theory]
    [InlineData("RetailOnly", true)]
    [InlineData("Either", true)]
    [InlineData("Bulk", false)]
    public void Admin_CategoryValidator_TradeMode(string mode, bool valid) =>
        new CreateMarketplaceCategoryCommandValidator()
            .Validate(new CreateMarketplaceCategoryCommand { Name = "Livestock", Kind = "Listing", TradeMode = mode })
            .IsValid.Should().Be(valid);

    [Fact]
    public async Task Options_IncludeTheTradeModeNamesFromTheTable()
    {
        using var test = new TestMarketplace();

        var options = await test.CatalogHandlers.Handle(new GetMarketplaceOptionsQuery(), default);

        options.TradeModes.Select(t => t.Code).Should().Equal("RetailOnly", "WholesaleOnly", "Either");
        options.TradeModes.Should().OnlyContain(t => !string.IsNullOrWhiteSpace(t.Name) && !string.IsNullOrWhiteSpace(t.Detail));
    }

    [Fact]
    public void Seed_FourActiveMainCategories_EachWithSubCategories()
    {
        var active = MarketplaceCatalogSeedData.Categories.Where(c => c.IsActive).OrderBy(c => c.DisplayOrder).ToList();

        active.Select(c => c.Name).Should().Equal("Products", "B2B Wholesale", "Nearby food", "Advertisements");
        active.Single(c => c.Id == MarketplaceCatalogSeedData.B2BWholesale).TradeMode.Should().Be(MarketplaceTradeMode.WholesaleOnly);
        active.Should().OnlyContain(c => MarketplaceCatalogSeedData.SubCategories.Any(s => s.CategoryId == c.Id));
        MarketplaceCatalogSeedData.SubCategories.Select(s => s.Id).Should().OnlyHaveUniqueItems();
        MarketplaceCatalogSeedData.SubCategories.GroupBy(s => (s.CategoryId, s.Slug)).Should().OnlyContain(g => g.Count() == 1);
        MarketplaceCatalogSeedData.Fields.Where(f => f.SubCategoryId is { } id)
            .Should().OnlyContain(f => MarketplaceCatalogSeedData.SubCategories.Any(s => s.Id == f.SubCategoryId && s.CategoryId == f.CategoryId));
    }
}
