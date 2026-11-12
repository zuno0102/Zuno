using FluentAssertions;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Application.Posts;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.UnitTests;

/// <summary>
/// Products say New or Used: a new item keeps a stock count (0 = out of stock, hidden from customers),
/// a used one is a single piece the business marks Sold.
/// </summary>
public class ProductStockTests
{
    private static readonly Guid Sarees = MarketplaceCatalogSeedData.SubId(3, 1);

    private static CreateMarketplacePostCommand Saree(Action<CreateMarketplacePostCommand>? change = null) =>
        TestMarketplace.Car(c =>
        {
            c.SubCategoryId = Sarees;
            c.Title = "Kanchipuram silk saree";
            c.Price = 2_400m;
            c.Condition = "New";
            c.Quantity = 12;
            c.Attributes = new();
            change?.Invoke(c);
        });

    private static ChangeMarketplacePostStatusCommand Move(Guid id, MarketplacePostStatus to) => new() { Id = id, Status = to.ToString() };

    private static async Task<IEnumerable<string>> FailedAsync(Func<Task> act) =>
        (await act.Should().ThrowAsync<ValidationException>()).Which.Errors.Select(e => e.ErrorMessage);

    [Fact]
    public async Task Create_ProductWithoutCondition_IsRefused()
    {
        using var test = new TestMarketplace();

        var failed = await FailedAsync(() => test.SaveHandlers.Handle(Saree(c => c.Condition = null), default));

        failed.Should().Contain("Choose New or Used.");
    }

    [Fact]
    public async Task Create_NewProductWithoutStock_IsRefused()
    {
        using var test = new TestMarketplace();

        var failed = await FailedAsync(() => test.SaveHandlers.Handle(Saree(c => c.Quantity = null), default));

        failed.Should().Contain("Enter how many you have in stock.");
    }

    [Fact]
    public async Task Create_NewProduct_KeepsItsStock_AndOffersUpdateStockButNotSold()
    {
        using var test = new TestMarketplace();

        var dto = await test.SaveHandlers.Handle(Saree(), default);

        dto.Condition.Should().Be("New");
        dto.Quantity.Should().Be(12);
        dto.IsOutOfStock.Should().BeFalse();
        dto.CanUpdateStock.Should().BeTrue();
        dto.Actions.Select(a => a.ToStatus).Should().Equal("Paused", "Closed");
    }

    [Fact]
    public async Task Create_NewProductAtZero_IsOutOfStock_ButStillActive()
    {
        using var test = new TestMarketplace();

        var dto = await test.SaveHandlers.Handle(Saree(c => c.Quantity = 0), default);

        dto.Status.Should().Be("Active");
        dto.IsOutOfStock.Should().BeTrue();
    }

    [Fact]
    public async Task Create_UsedProduct_IsOnePiece_WithMarkAsSold()
    {
        using var test = new TestMarketplace();

        var dto = await test.SaveHandlers.Handle(Saree(c => { c.Condition = "used"; c.Quantity = 7; }), default);

        dto.Condition.Should().Be("Used");
        dto.Quantity.Should().BeNull("a used item is a single piece");
        dto.CanUpdateStock.Should().BeFalse();
        dto.Actions.Should().ContainSingle(a => a.ToStatus == "Sold" && a.Name == "Mark as sold" && a.NeedsConfirm);
    }

    [Fact]
    public async Task Create_OutsideProducts_HasNoCondition_AndNeedsAtLeastOne()
    {
        using var test = new TestMarketplace();

        var food = await test.SaveHandlers.Handle(test.Biryani(c => c.Condition = "Used"), default);
        food.Condition.Should().BeNull();
        food.Quantity.Should().Be(20);

        var failed = await FailedAsync(() => test.SaveHandlers.Handle(TestMarketplace.Bananas(c => c.Quantity = 0), default));
        failed.Should().Contain("The quantity must be at least 1.");
    }

    [Theory]
    [InlineData("New", "New", 1)]
    [InlineData("Used", "Used", null)]
    public async Task Create_FromAnOlderApp_TakesTheConditionDetail_AsTheCondition(string sent, string condition, int? stock)
    {
        using var test = new TestMarketplace();
        var olderApp = Saree(c =>
        {
            c.Condition = null;
            c.Quantity = null;
            c.Attributes = new() { [MarketplacePost.LegacyConditionKey] = sent };
        });

        var dto = await test.SaveHandlers.Handle(olderApp, default);

        dto.Condition.Should().Be(condition);
        dto.Quantity.Should().Be(stock);
        dto.Attributes.Should().BeEmpty("the old detail is not kept as a detail");
    }

    [Fact]
    public async Task Create_FromAnOlderApp_WithoutACondition_StillAsksForOne()
    {
        using var test = new TestMarketplace();

        var failed = await FailedAsync(() => test.SaveHandlers.Handle(Saree(c => { c.Condition = null; c.Quantity = null; }), default));

        failed.Should().Contain("Choose New or Used.");
    }

    [Fact]
    public async Task Create_TheConditionDetail_OutsideProducts_IsStillRefused()
    {
        using var test = new TestMarketplace();
        var food = test.Biryani(c => c.Attributes[MarketplacePost.LegacyConditionKey] = "New");

        var failed = await FailedAsync(() => test.SaveHandlers.Handle(food, default));

        failed.Should().Contain(m => m.Contains("no detail called"));
    }

    [Fact]
    public async Task MarkAsSold_UsedItem_IsFinal_AndFreesThePlanSlot()
    {
        using var test = new TestMarketplace();
        var car = await test.SaveHandlers.Handle(TestMarketplace.Car(), default);

        var sold = await test.ManageHandlers.Handle(Move(car.Id, MarketplacePostStatus.Sold), default);

        sold.Status.Should().Be("Sold");
        sold.Actions.Should().BeEmpty();
        var summary = await test.QueryHandlers.Handle(new GetMyMarketplaceSummaryQuery(), default);
        summary.Should().BeEquivalentTo(new { Active = 0, Sold = 1 }, o => o.ExcludingMissingMembers());
        summary.Plan.CanAddActivePost.Should().BeTrue();

        var edit = new UpdateMarketplacePostCommand { Id = car.Id };
        var act = () => test.SaveHandlers.Handle(edit, default);
        await act.Should().ThrowAsync<DomainException>().WithMessage("A closed or sold post cannot be changed.");
    }

    [Fact]
    public async Task MarkAsSold_NewItem_IsRefused()
    {
        using var test = new TestMarketplace();
        var saree = await test.SaveHandlers.Handle(Saree(), default);

        var act = () => test.ManageHandlers.Handle(Move(saree.Id, MarketplacePostStatus.Sold), default);

        await act.Should().ThrowAsync<DomainException>().WithMessage("Only a used item is marked sold*");
    }

    [Fact]
    public async Task UpdateStock_NewItem_SetsTheCount_DownToOutOfStock_AndBack()
    {
        using var test = new TestMarketplace();
        var saree = await test.SaveHandlers.Handle(Saree(), default);

        var empty = await test.StockHandler.Handle(new UpdateMarketplacePostStockCommand { Id = saree.Id, Quantity = 0 }, default);
        empty.IsOutOfStock.Should().BeTrue();
        empty.Status.Should().Be("Active");

        var restocked = await test.StockHandler.Handle(new UpdateMarketplacePostStockCommand { Id = saree.Id, Quantity = 30 }, default);
        restocked.Quantity.Should().Be(30);
        restocked.IsOutOfStock.Should().BeFalse();
    }

    [Fact]
    public async Task UpdateStock_UsedItem_IsRefused()
    {
        using var test = new TestMarketplace();
        var car = await test.SaveHandlers.Handle(TestMarketplace.Car(), default);

        var act = () => test.StockHandler.Handle(new UpdateMarketplacePostStockCommand { Id = car.Id, Quantity = 3 }, default);

        await act.Should().ThrowAsync<DomainException>().WithMessage("Only a new item keeps a stock count.");
    }

    [Fact]
    public async Task UpdateStock_ClosedItem_IsRefused()
    {
        using var test = new TestMarketplace();
        var saree = await test.SaveHandlers.Handle(Saree(), default);
        await test.ManageHandlers.Handle(Move(saree.Id, MarketplacePostStatus.Closed), default);

        var act = () => test.StockHandler.Handle(new UpdateMarketplacePostStockCommand { Id = saree.Id, Quantity = 3 }, default);

        await act.Should().ThrowAsync<DomainException>().WithMessage("A closed or sold post cannot be changed.");
    }

    [Fact]
    public async Task UpdateStock_AnotherBusinessesPost_IsForbidden()
    {
        using var test = new TestMarketplace();
        var saree = await test.SaveHandlers.Handle(Saree(), default);
        test.As(TestMarketplace.OwnerB);

        var act = () => test.StockHandler.Handle(new UpdateMarketplacePostStockCommand { Id = saree.Id, Quantity = 3 }, default);

        await act.Should().ThrowAsync<ForbiddenException>();
    }

    [Theory]
    [InlineData(-1, false)]
    [InlineData(0, true)]
    [InlineData(1_000_000_000, false)]
    public void StockValidator_ZeroUpToTheLimit(int quantity, bool valid) =>
        new UpdateMarketplacePostStockCommandValidator(Options.Create(new MarketplaceSettings()))
            .Validate(new UpdateMarketplacePostStockCommand { Id = Guid.NewGuid(), Quantity = quantity })
            .IsValid.Should().Be(valid);

    [Fact]
    public async Task Customers_DoNotSee_AnOutOfStockNewItem()
    {
        using var test = new TestMarketplace();
        test.Db.Businesses.Add(new MarketplaceBusiness { OwnerUserId = TestMarketplace.OwnerA, Name = "Shop", IsVerified = true });
        await test.Db.SaveChangesAsync();
        var inStock = test.Seed(p => { p.Condition = MarketplaceItemCondition.New; p.Quantity = 4; });
        test.Seed(p => { p.Condition = MarketplaceItemCondition.New; p.Quantity = 0; });
        var used = test.Seed(p => p.Condition = MarketplaceItemCondition.Used);
        var food = test.Seed(p => { p.CategoryId = MarketplaceCatalogSeedData.NearbyFood; p.SubCategoryId = null; });

        var visible = await test.Db.Posts.Include(p => p.Category).Include(p => p.SubCategory)
            .VisibleToCustomers(test.Db.Businesses, test.Now)
            .Select(p => p.Id)
            .ToListAsync();

        visible.Should().BeEquivalentTo([inStock.Id, used.Id, food.Id]);
    }

    [Fact]
    public async Task Options_NameNewAndUsed_FromTheTable()
    {
        using var test = new TestMarketplace();

        var options = await test.CatalogHandlers.Handle(new Application.Categories.GetMarketplaceOptionsQuery(), default);

        options.Conditions.Select(c => c.Code).Should().Equal("New", "Used");
        options.Statuses.Select(s => s.Code).Should().Contain("Sold");
    }

    [Fact]
    public async Task Categories_SayWhichKeepStock()
    {
        using var test = new TestMarketplace();

        var categories = await test.CatalogHandlers.Handle(new Application.Categories.GetMarketplaceCategoriesQuery(), default);

        categories.Where(c => c.TracksStock).Select(c => c.Name).Should().Equal("Products");
    }
}
