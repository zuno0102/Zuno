using FluentAssertions;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Application.Admin;
using Zuno.Marketplace.Application.Categories;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Application.Posts;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;
using Zuno.Marketplace.Infrastructure.Persistence;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.UnitTests;

public class QueryAndCatalogTests
{
    [Fact]
    public async Task Summary_NoPosts_IsZeroWithTheFreePlan()
    {
        using var test = new TestMarketplace();

        var summary = await test.QueryHandlers.Handle(new GetMyMarketplaceSummaryQuery(), default);

        summary.Should().BeEquivalentTo(new { Active = 0, Paused = 0, Expired = 0, Closed = 0 });
        summary.Plan.Should().BeEquivalentTo(new { Code = "free", Name = "Free", MaxActivePosts = 1, UsedActivePosts = 0, CanAddActivePost = true, EndsAt = (DateTimeOffset?)null });
    }

    [Fact]
    public async Task Summary_CountsEachShownStatus_OnlyForTheCaller()
    {
        using var test = new TestMarketplace();
        test.Seed();
        test.Seed(p => p.Status = MarketplacePostStatus.Paused);
        test.Seed(p => p.Status = MarketplacePostStatus.Paused);
        test.Seed(p => p.EndsAt = test.Now.AddMinutes(-1));
        test.Seed(p => p.Status = MarketplacePostStatus.Closed);
        test.Seed(p => p.OwnerUserId = TestMarketplace.OwnerB);

        var summary = await test.QueryHandlers.Handle(new GetMyMarketplaceSummaryQuery(), default);

        summary.Should().BeEquivalentTo(new { Active = 1, Paused = 2, Expired = 1, Closed = 1 });
        summary.Plan.UsedActivePosts.Should().Be(1);
        summary.Plan.CanAddActivePost.Should().BeFalse();
    }

    [Fact]
    public async Task Summary_CountsEachMainCategoryByStatus_AndTheTotalsAreTheirSum()
    {
        using var test = new TestMarketplace();
        test.Seed();
        test.Seed(p => p.Status = MarketplacePostStatus.Paused);
        test.Seed(p => { p.CategoryId = MarketplaceCatalogSeedData.NearbyFood; p.SubCategoryId = null; p.Status = MarketplacePostStatus.Paused; });
        test.Seed(p => { p.CategoryId = MarketplaceCatalogSeedData.NearbyFood; p.SubCategoryId = null; p.EndsAt = test.Now.AddMinutes(-1); });
        test.Seed(p => { p.CategoryId = MarketplaceCatalogSeedData.NearbyFood; p.SubCategoryId = null; p.OwnerUserId = TestMarketplace.OwnerB; });

        var summary = await test.QueryHandlers.Handle(new GetMyMarketplaceSummaryQuery(), default);

        summary.Categories.Should().BeEquivalentTo(new[]
        {
            new { CategoryId = MarketplaceCatalogSeedData.Products, Active = 1, Paused = 1, Expired = 0, Closed = 0 },
            new { CategoryId = MarketplaceCatalogSeedData.NearbyFood, Active = 0, Paused = 1, Expired = 1, Closed = 0 },
        });
        summary.Should().BeEquivalentTo(new { Active = 1, Paused = 2, Expired = 1, Closed = 0 }, o => o.ExcludingMissingMembers());
    }

    [Fact]
    public async Task List_Empty_IsAnEmptyPage()
    {
        using var test = new TestMarketplace();

        var page = await test.QueryHandlers.Handle(new GetMyMarketplacePostsQuery(), default);

        page.Items.Should().BeEmpty();
        page.TotalCount.Should().Be(0);
        page.PageSize.Should().Be(30);
    }

    [Fact]
    public async Task List_PagesNewestFirst_AndCapsThePageSize()
    {
        using var test = new TestMarketplace();
        for (var i = 0; i < 3; i++)
        {
            test.Clock.Current = test.Now.AddMinutes(1);
            test.Seed(p => p.Title = $"Post {i}");
        }

        var first = await test.QueryHandlers.Handle(new GetMyMarketplacePostsQuery { PageSize = 2 }, default);
        var last = await test.QueryHandlers.Handle(new GetMyMarketplacePostsQuery { Page = 2, PageSize = 2 }, default);
        var capped = await test.QueryHandlers.Handle(new GetMyMarketplacePostsQuery { PageSize = 5000 }, default);

        first.Items.Select(p => p.Title).Should().Equal("Post 2", "Post 1");
        last.Items.Select(p => p.Title).Should().Equal("Post 0");
        first.TotalCount.Should().Be(3);
        capped.PageSize.Should().Be(100);
    }

    [Fact]
    public async Task List_FiltersByKindAndShownStatus()
    {
        using var test = new TestMarketplace();
        test.Seed(p => p.Title = "Car");
        test.Seed(p =>
        {
            p.Title = "Old food";
            p.Kind = MarketplacePostKind.FoodOffer;
            p.CategoryId = MarketplaceCatalogSeedData.NearbyFood;
            p.EndsAt = test.Now.AddMinutes(-1);
        });

        var food = await test.QueryHandlers.Handle(new GetMyMarketplacePostsQuery { Kind = "FoodOffer" }, default);
        var expired = await test.QueryHandlers.Handle(new GetMyMarketplacePostsQuery { Status = "Expired" }, default);
        var active = await test.QueryHandlers.Handle(new GetMyMarketplacePostsQuery { Status = "Active" }, default);

        food.Items.Select(p => p.Title).Should().Equal("Old food");
        expired.Items.Select(p => p.Title).Should().Equal("Old food");
        active.Items.Select(p => p.Title).Should().Equal("Car");
    }

    [Theory]
    [InlineData("Listing", null, true)]
    [InlineData(null, "Expired", true)]
    [InlineData("Car", null, false)]
    [InlineData(null, "Gone", false)]
    [InlineData("1; DROP TABLE marketplace_posts", null, false)]
    public void ListValidator_KnownNamesOnly(string? kind, string? status, bool valid) =>
        new GetMyMarketplacePostsQueryValidator()
            .Validate(new GetMyMarketplacePostsQuery { Kind = kind, Status = status })
            .IsValid.Should().Be(valid);

    [Fact]
    public async Task Visibility_OnlyLiveStartedPostsOfVerifiedBusinessesInActiveCategories()
    {
        using var test = new TestMarketplace();
        var verified = Guid.NewGuid();
        var unverified = Guid.NewGuid();
        test.Db.Businesses.AddRange(
            new MarketplaceBusiness { OwnerUserId = verified, Name = "shajil shajil", IsVerified = true },
            new MarketplaceBusiness { OwnerUserId = unverified, Name = "Apple Shop", IsVerified = false });
        await test.Db.SaveChangesAsync();
        test.Seed(p => { p.OwnerUserId = verified; p.Title = "Shown"; });
        test.Seed(p => { p.OwnerUserId = unverified; p.Title = "Unverified"; });
        test.Seed(p => { p.OwnerUserId = Guid.NewGuid(); p.Title = "Never synced"; });
        test.Seed(p => { p.OwnerUserId = verified; p.Title = "Paused"; p.Status = MarketplacePostStatus.Paused; });
        test.Seed(p => { p.OwnerUserId = verified; p.Title = "Ended"; p.EndsAt = test.Now; });
        test.Seed(p => { p.OwnerUserId = verified; p.Title = "Not yet"; p.StartsAt = test.Now.AddHours(1); p.EndsAt = test.Now.AddHours(2); });
        test.Seed(p => { p.OwnerUserId = verified; p.Title = "Category off"; p.CategoryId = MarketplaceCatalogSeedData.B2BWholesale; p.SubCategoryId = null; });
        test.Seed(p => { p.OwnerUserId = verified; p.Title = "Sub-category off"; p.SubCategoryId = MarketplaceCatalogSeedData.SubId(3, 1); });
        var sarees = await test.Db.SubCategories.SingleAsync(s => s.Id == MarketplaceCatalogSeedData.SubId(3, 1));
        sarees.IsActive = false;
        var products = await test.Db.Categories.SingleAsync(c => c.Id == MarketplaceCatalogSeedData.B2BWholesale);
        products.IsActive = false;
        await test.Db.SaveChangesAsync();

        var shown = await test.Db.Posts.VisibleToCustomers(test.Db.Businesses, test.Now).Select(p => p.Title).ToListAsync();

        shown.Should().Equal("Shown");
    }

    [Fact]
    public async Task Categories_ActiveOnlyWithActiveFields_InOrder()
    {
        using var test = new TestMarketplace();

        var categories = await test.CatalogHandlers.Handle(new GetMarketplaceCategoriesQuery(), default);

        categories.Select(c => c.Slug).Should().Equal("products", "b2b-wholesale", "nearby-food", "advertisements");
        categories.Select(c => c.ShortName).Should().Equal("Products", "B2B", "Food", "Ads");
        categories[0].SubCategories.Select(s => s.Name).Should().StartWith(["Sarees", "Clothing", "Footwear", "Toys"]).And.Contain(["Vehicles", "Property"]);
        categories[0].Fields.Select(f => f.Key).Should().Equal(
            ["brand", "model_year", "km_driven", "fuel", "owners", "property_type", "deal", "area", "bedrooms"],
            "a product asks only its basic fields; Vehicles and Property keep their own details");
        categories.Single(c => c.Slug == "b2b-wholesale").TradeMode.Should().Be("WholesaleOnly");
        categories.Single(c => c.Slug == "nearby-food").Kind.Should().Be("FoodOffer");
    }

    [Fact]
    public async Task Options_ComeFromTheTablesAndSettings()
    {
        using var test = new TestMarketplace();

        var options = await test.CatalogHandlers.Handle(new GetMarketplaceOptionsQuery(), default);

        options.Kinds.Select(k => k.Code).Should().Equal("Listing", "FoodOffer", "Advertisement");
        options.Statuses.Should().ContainSingle(s => s.Code == "Expired").Which.Tone.Should().Be("danger");
        options.ImageSlots.Should().Be(5);
        options.MaxFoodOfferHours.Should().Be(24);
    }

    [Fact]
    public async Task Options_SendTheTextLimitsTheValidatorsCheck()
    {
        using var test = new TestMarketplace();

        var options = await test.CatalogHandlers.Handle(new GetMarketplaceOptionsQuery(), default);

        options.TextLimits.Should().BeEquivalentTo(MarketplaceTextLimits.ToDto());
        options.TextLimits.Title.Should().Be(MarketplaceTextLimits.Title);
        options.MaxStartDaysAhead.Should().BePositive();

        var validator = new CreateMarketplacePostCommandValidator(Options.Create(new MarketplaceSettings()));
        var tooLong = TestMarketplace.Car(c => c.Title = new string('a', options.TextLimits.Title + 1));
        var justFits = TestMarketplace.Car(c => c.Title = new string('a', options.TextLimits.Title));
        validator.Validate(tooLong).Errors.Should().Contain(e => e.PropertyName == "Title");
        validator.Validate(justFits).Errors.Should().NotContain(e => e.PropertyName == "Title");
    }

    [Theory]
    [InlineData("9876543210", true)]
    [InlineData("+919876543210", true)]
    [InlineData("987654321", false)]
    [InlineData("1234567890123456", false)]
    [InlineData("98765 43210", false)]
    public void ContactPhone_IsCheckedAgainstTheSentDigits(string phone, bool valid)
    {
        var validator = new CreateMarketplacePostCommandValidator(Options.Create(new MarketplaceSettings()));

        var result = validator.Validate(TestMarketplace.Car(c => c.ContactPhone = phone));

        result.Errors.Any(e => e.PropertyName == "ContactPhone").Should().Be(!valid);
    }

    [Fact]
    public async Task Admin_CreateCategory_ShowsAtOnceDespiteTheCache()
    {
        using var test = new TestMarketplace();
        await test.CatalogHandlers.Handle(new GetMarketplaceCategoriesQuery(), default);

        var created = await test.AdminHandlers.Handle(
            new CreateMarketplaceCategoryCommand { Name = "  Mobiles & Tablets ", Kind = "listing", DisplayOrder = 7 }, default);
        var categories = await test.CatalogHandlers.Handle(new GetMarketplaceCategoriesQuery(), default);

        created.Slug.Should().Be("mobiles-tablets");
        created.Name.Should().Be("Mobiles & Tablets");
        categories.Should().Contain(c => c.Id == created.Id);
    }

    [Fact]
    public async Task Admin_DuplicateCategoryName_IsRefused()
    {
        using var test = new TestMarketplace();

        var act = () => test.AdminHandlers.Handle(new CreateMarketplaceCategoryCommand { Name = "VEHICLES" }, default);

        await act.Should().ThrowAsync<DomainException>().WithMessage("A category with this name already exists.");
    }

    [Fact]
    public async Task Admin_SwitchOffCategory_HidesItFromBusinessesButNotTheAdmin()
    {
        using var test = new TestMarketplace();

        await test.AdminHandlers.Handle(
            new UpdateMarketplaceCategoryCommand { Id = MarketplaceCatalogSeedData.Products, Name = "Products", Kind = "Listing", IsActive = false }, default);

        (await test.CatalogHandlers.Handle(new GetMarketplaceCategoriesQuery(), default)).Should().NotContain(c => c.Slug == "products");
        (await test.CatalogHandlers.Handle(new GetMarketplaceCategoriesQuery(IncludeInactive: true), default))
            .Should().ContainSingle(c => c.Slug == "products").Which.IsActive.Should().BeFalse();
    }

    [Fact]
    public async Task Admin_UpdateMissingCategory_IsNotFound()
    {
        using var test = new TestMarketplace();

        var act = () => test.AdminHandlers.Handle(new UpdateMarketplaceCategoryCommand { Id = Guid.NewGuid(), Name = "X", Kind = "Listing" }, default);

        await act.Should().ThrowAsync<EntityNotFoundException>();
    }

    [Fact]
    public async Task Admin_AddField_MakesItsKeyFromTheLabel_AndPostsMustFillIt()
    {
        using var test = new TestMarketplace();

        var category = await test.AdminHandlers.Handle(new CreateMarketplaceFieldCommand
        {
            CategoryId = MarketplaceCatalogSeedData.Products,
            SubCategoryId = MarketplaceCatalogSeedData.Vehicles,
            Label = "Insurance valid till",
            FieldType = "Text",
            IsRequired = true,
            DisplayOrder = 6,
        }, default);
        var act = () => test.SaveHandlers.Handle(TestMarketplace.Car(), default);

        category.Fields.Should().Contain(f => f.Key == "insurance_valid_till");
        (await act.Should().ThrowAsync<ValidationException>()).Which.Errors.Should()
            .ContainSingle(e => e.PropertyName == "Attributes.insurance_valid_till");
    }

    [Fact]
    public async Task Admin_AddFieldTwice_IsRefused()
    {
        using var test = new TestMarketplace();

        var act = () => test.AdminHandlers.Handle(
            new CreateMarketplaceFieldCommand { CategoryId = MarketplaceCatalogSeedData.Products, SubCategoryId = MarketplaceCatalogSeedData.Vehicles, Label = "KM driven", FieldType = "Number" }, default);

        await act.Should().ThrowAsync<DomainException>();
    }

    [Fact]
    public async Task Admin_UpdateField_KeepsItsKey_AndDropsOptionsOfANonList()
    {
        using var test = new TestMarketplace();
        var fuel = (await test.Db.CategoryFields.SingleAsync(f => f.Key == "fuel")).Id;

        var category = await test.AdminHandlers.Handle(new UpdateMarketplaceFieldCommand
        {
            Id = fuel,
            CategoryId = MarketplaceCatalogSeedData.Products,
            SubCategoryId = MarketplaceCatalogSeedData.Vehicles,
            Label = "Fuel used",
            FieldType = "Text",
            Options = ["Petrol"],
        }, default);

        category.Fields.Single(f => f.Id == fuel).Should().BeEquivalentTo(new { Key = "fuel", Label = "Fuel used", FieldType = "Text", Options = new List<string>() });
    }

    [Fact]
    public async Task Admin_UpdateFieldOfAnotherCategory_IsNotFound()
    {
        using var test = new TestMarketplace();
        var fuel = (await test.Db.CategoryFields.SingleAsync(f => f.Key == "fuel")).Id;

        var act = () => test.AdminHandlers.Handle(
            new UpdateMarketplaceFieldCommand { Id = fuel, CategoryId = MarketplaceCatalogSeedData.B2BWholesale, Label = "Fuel", FieldType = "Text" }, default);

        await act.Should().ThrowAsync<EntityNotFoundException>();
    }

    [Theory]
    [InlineData("Select", new string[0], false)]
    [InlineData("Select", new[] { "Yes", "yes" }, false)]
    [InlineData("Select", new[] { "Yes", "No" }, true)]
    [InlineData("Text", new string[0], true)]
    [InlineData("Date", new string[0], false)]
    public void Admin_FieldValidator_ListsNeedDistinctChoices(string type, string[] options, bool valid) =>
        new CreateMarketplaceFieldCommandValidator()
            .Validate(new CreateMarketplaceFieldCommand { CategoryId = Guid.NewGuid(), Label = "Colour", FieldType = type, Options = [.. options] })
            .IsValid.Should().Be(valid);

    [Theory]
    [InlineData("", "Listing", false)]
    [InlineData("&&&", "Listing", false)]
    [InlineData("Mobiles", "Auction", false)]
    [InlineData("Mobiles", "FoodOffer", true)]
    public void Admin_CategoryValidator(string name, string kind, bool valid) =>
        new CreateMarketplaceCategoryCommandValidator()
            .Validate(new CreateMarketplaceCategoryCommand { Name = name, Kind = kind })
            .IsValid.Should().Be(valid);

    [Theory]
    [InlineData("Farm & Wholesale", '-', "farm-wholesale")]
    [InlineData("KM driven", '_', "km_driven")]
    [InlineData("  Événement 2026 ", '-', "v-nement-2026")]
    public void Slug_KeepsLettersAndDigits(string text, char separator, string expected) =>
        MarketplaceCategoryAdminHandlers.Slug(text, separator).Should().Be(expected);

    [Fact]
    public void Seed_HasOneDefaultFreePlanWithOnePost()
    {
        MarketplaceCatalogSeedData.Plans.Should().ContainSingle(p => p.IsDefault)
            .Which.Should().BeEquivalentTo(new { Code = "free", Price = 0m, MaxActivePosts = 1, DurationDays = (int?)null });
    }

    [Fact]
    public void Seed_EveryListFieldHasChoices_AndKeysAreUniquePerCategory()
    {
        var fields = MarketplaceCatalogSeedData.Fields;

        fields.Where(f => f.FieldType == MarketplaceFieldType.Select).Should().OnlyContain(f => f.Options.Count > 0);
        fields.GroupBy(f => (f.CategoryId, f.SubCategoryId, f.Key)).Should().OnlyContain(g => g.Count() == 1);
        fields.Select(f => f.Id).Should().OnlyHaveUniqueItems();
        fields.Select(f => f.CategoryId).Should().BeSubsetOf(MarketplaceCatalogSeedData.Categories.Select(c => c.Id));
    }

    [Fact]
    public void Seed_EveryStatusButExpiredCanBeLeft_AndClosedIsFinal()
    {
        var transitions = MarketplaceCatalogSeedData.Transitions;

        transitions.Should().NotContain(t => t.FromStatus == MarketplacePostStatus.Closed);
        transitions.Should().NotContain(t => t.FromStatus == MarketplacePostStatus.Expired || t.ToStatus == MarketplacePostStatus.Expired);
        transitions.Where(t => t.ToStatus == MarketplacePostStatus.Closed).Should().OnlyContain(t => t.NeedsConfirm);
    }

    [Fact]
    public void Seed_DistrictIdsMatchTheServiceFormula()
    {
        // The same id the Service and Rent databases give Kanyakumari, so the app's picker works for all three.
        LocationSeedData.DistrictId("Tamil Nadu", "Kanyakumari").Should().Be(TestMarketplace.Kanyakumari);
        LocationSeedData.Districts.Should().Contain(d => d.Id == TestMarketplace.Kanyakumari && d.Name == "Kanyakumari");
    }

    [Fact]
    public void LockKey_IsStablePerOwner_AndDiffersBetweenOwners()
    {
        MarketplaceDbContext.LockKey(TestMarketplace.OwnerA).Should().Be(MarketplaceDbContext.LockKey(TestMarketplace.OwnerA));
        MarketplaceDbContext.LockKey(TestMarketplace.OwnerA).Should().NotBe(MarketplaceDbContext.LockKey(TestMarketplace.OwnerB));
    }
}
