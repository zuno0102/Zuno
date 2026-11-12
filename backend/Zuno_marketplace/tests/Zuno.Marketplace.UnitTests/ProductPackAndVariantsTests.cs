using FluentAssertions;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Application.Posts;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.UnitTests;

/// <summary>
/// A product's Quantity is how many come in one item (a pack of 3), apart from its stock; its colours
/// and sizes can be changed on their own ("Manage variants"); the Stock page lists the products that
/// keep a stock count.
/// </summary>
public class ProductPackAndVariantsTests
{
    private static CreateMarketplacePostCommand Saree(Action<CreateMarketplacePostCommand>? change = null) =>
        TestMarketplace.Car(c =>
        {
            c.SubCategoryId = MarketplaceCatalogSeedData.SubId(3, 1);
            c.Title = "Kanchipuram silk saree";
            c.Price = 2_400m;
            c.OriginalPrice = 3_000m;
            c.Condition = "New";
            c.Quantity = 12;
            c.Attributes = new();
            change?.Invoke(c);
        });

    private static List<MarketplaceVariantInput> RedAndBlue() =>
    [
        new() { Colour = "Red", Size = "M", Price = 2_400m, Stock = 10 },
        new() { Colour = "Blue", Price = 2_200m, Stock = 5 },
    ];

    private static ReplaceMarketplacePostVariantsCommand Replace(Guid id, List<MarketplaceVariantInput> variants) =>
        new() { Id = id, Variants = variants };

    [Fact]
    public async Task Create_Product_WithoutAPackQuantity_IsOnePiece_AndKeepsItsStockApart()
    {
        using var test = new TestMarketplace();

        var dto = await test.SaveHandlers.Handle(Saree(), default);

        dto.PackQuantity.Should().Be(1);
        dto.Quantity.Should().Be(12, "the stock is its own figure");
    }

    [Fact]
    public async Task Create_ProductInAPack_KeepsThePackQuantity()
    {
        using var test = new TestMarketplace();

        var dto = await test.SaveHandlers.Handle(Saree(c => c.PackQuantity = 3), default);

        dto.PackQuantity.Should().Be(3);
    }

    [Fact]
    public async Task Create_FoodOffer_HasNoPackQuantity()
    {
        using var test = new TestMarketplace();

        var dto = await test.SaveHandlers.Handle(test.Biryani(c => c.PackQuantity = 2), default);

        dto.PackQuantity.Should().BeNull("only a product comes in packs");
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public void Validator_RefusesAPackOfLessThanOne(int pack)
    {
        var validator = new CreateMarketplacePostCommandValidator(Options.Create(new MarketplaceSettings()));

        validator.Validate(Saree(c => c.PackQuantity = pack)).Errors
            .Should().Contain(e => e.PropertyName == nameof(MarketplacePostFields.PackQuantity));
    }

    [Fact]
    public async Task ReplaceVariants_SetsTheColoursAndSizes_AndKeepsTheRestOfThePost()
    {
        using var test = new TestMarketplace();
        var saved = await test.SaveHandlers.Handle(Saree(c =>
        {
            c.PackQuantity = 2;
            c.CustomDetails = [new() { Name = "Work", Value = "Zari" }];
        }), default);

        var dto = await test.VariantsHandler.Handle(Replace(saved.Id, RedAndBlue()), default);

        dto.Variants.Select(v => (v.Colour, v.Size, v.Price, v.Stock)).Should().Equal(
            ("Red", "M", 2_400m, 10), ("Blue", null, 2_200m, 5));
        dto.Quantity.Should().Be(15, "the stock is the colours and sizes added up");
        dto.Price.Should().Be(2_200m, "the lowest they sell at");
        (dto.Title, dto.PackQuantity, dto.OriginalPrice).Should().Be(("Kanchipuram silk saree", 2, 3_000m));
        dto.CustomDetails.Select(d => (d.Name, d.Value)).Should().Equal(("Work", "Zari"));
    }

    [Fact]
    public async Task ReplaceVariants_KeepsARowSentWithItsId_AndDropsOneLeftOut()
    {
        using var test = new TestMarketplace();
        var saved = await test.SaveHandlers.Handle(Saree(c => c.Variants = RedAndBlue()), default);
        var red = saved.Variants.Single(v => v.Colour == "Red");

        var dto = await test.VariantsHandler.Handle(
            Replace(saved.Id, [new() { Id = red.Id, Colour = "Red", Size = "M", Price = 2_400m, Stock = 3 }]), default);

        dto.Variants.Should().ContainSingle().Which.Id.Should().Be(red.Id);
        dto.Quantity.Should().Be(3);
    }

    [Fact]
    public async Task ReplaceVariants_ChecksThemAsTheFormDoes()
    {
        using var test = new TestMarketplace();
        var saved = await test.SaveHandlers.Handle(Saree(), default);

        async Task<IEnumerable<string>> Refused(List<MarketplaceVariantInput> variants) =>
            (await test.Invoking(t => t.VariantsHandler.Handle(Replace(saved.Id, variants), default))
                .Should().ThrowAsync<ValidationException>()).Which.Errors.Select(e => e.ErrorMessage);

        (await Refused([new() { Colour = "Red", Price = 100m, Stock = 1 }, new() { Colour = " red ", Price = 100m, Stock = 1 }]))
            .Should().Contain("Red is listed twice.");
        (await Refused([new() { Colour = "Gold", Price = 5_000m, Stock = 1 }]))
            .Should().Contain("The MRP cannot be less than the price.");
        (await Refused([new() { Price = 100m, Stock = 1 }]))
            .Should().Contain("Give a colour, a size, or both.");
    }

    [Fact]
    public void ReplaceVariants_NeedsAtLeastOne()
    {
        var validator = new ReplaceMarketplacePostVariantsCommandValidator();

        validator.Validate(Replace(Guid.NewGuid(), [])).Errors
            .Should().Contain(e => e.ErrorMessage == "Keep at least one colour or size.");
    }

    [Fact]
    public async Task ReplaceVariants_OnAUsedItem_IsRefused()
    {
        using var test = new TestMarketplace();
        var saved = await test.SaveHandlers.Handle(Saree(c =>
        {
            c.Condition = "Used";
            c.Quantity = null;
        }), default);

        var act = () => test.VariantsHandler.Handle(Replace(saved.Id, RedAndBlue()), default);

        await act.Should().ThrowAsync<DomainException>().WithMessage("Only a new product is sold in colours and sizes.");
    }

    [Fact]
    public async Task ReplaceVariants_OnAnotherBusinesssPost_IsForbidden()
    {
        using var test = new TestMarketplace();
        var saved = await test.SaveHandlers.Handle(Saree(), default);

        var act = () => test.As(TestMarketplace.OwnerB).VariantsHandler.Handle(Replace(saved.Id, RedAndBlue()), default);

        await act.Should().ThrowAsync<ForbiddenException>();
    }

    [Fact]
    public async Task ReplaceVariants_OnAClosedProduct_IsRefused()
    {
        using var test = new TestMarketplace();
        var saved = await test.SaveHandlers.Handle(Saree(), default);
        await test.ManageHandlers.Handle(
            new ChangeMarketplacePostStatusCommand { Id = saved.Id, Status = nameof(MarketplacePostStatus.Closed) }, default);

        var act = () => test.VariantsHandler.Handle(Replace(saved.Id, RedAndBlue()), default);

        await act.Should().ThrowAsync<DomainException>().WithMessage("A closed or sold post cannot be changed.");
    }

    [Fact]
    public async Task ASwitchedOffColour_IsKept_ButNotCountedOrPricedFrom()
    {
        using var test = new TestMarketplace();
        var saved = await test.SaveHandlers.Handle(Saree(), default);

        var dto = await test.VariantsHandler.Handle(Replace(saved.Id,
        [
            new() { Colour = "Red", Price = 2_400m, Stock = 10 },
            new() { Colour = "Blue", Price = 2_000m, Stock = 4, IsActive = false },
        ]), default);

        dto.Variants.Select(v => (v.Colour, v.IsActive)).Should().Equal(("Red", true), ("Blue", false));
        dto.Quantity.Should().Be(10, "a switched-off colour's stock is not on sale");
        dto.Price.Should().Be(2_400m, "it sells from the lowest colour still on sale");
    }

    [Fact]
    public async Task AColour_KeepsDetailsOfItsOwn_TrimmedAndEmptiesDropped()
    {
        using var test = new TestMarketplace();
        var saved = await test.SaveHandlers.Handle(Saree(), default);

        var dto = await test.VariantsHandler.Handle(Replace(saved.Id,
        [
            new()
            {
                Colour = "Red", Price = 2_400m, Stock = 10,
                CustomDetails = [new() { Name = " Border ", Value = " Zari " }, new() { Name = "Blouse", Value = "With blouse" }],
            },
            new() { Colour = "Blue", Price = 2_400m, Stock = 4 },
        ]), default);

        dto.Variants[0].CustomDetails.Select(d => (d.Name, d.Value)).Should().Equal(("Border", "Zari"), ("Blouse", "With blouse"));
        dto.Variants[1].CustomDetails.Should().BeEmpty();
    }

    [Fact]
    public void AColoursDetails_AreCheckedLikeThePosts()
    {
        var validator = new CreateMarketplacePostCommandValidator(Options.Create(new MarketplaceSettings()));
        List<string> Errors(List<MarketplaceCustomDetailInput> details) => validator.Validate(Saree(c => c.Variants =
            [new() { Colour = "Red", Price = 100m, Stock = 1, CustomDetails = details }])).Errors.Select(e => e.ErrorMessage).ToList();

        Errors([new() { Name = "Border", Value = "Zari" }, new() { Name = " border", Value = "Plain" }])
            .Should().Contain("Name each detail of a colour / size once.");
        Errors([new() { Name = "", Value = "Zari" }]).Should().Contain("Name the detail, e.g. Border.");
        Errors([new() { Name = "Border", Value = "" }]).Should().Contain("Give the detail a value.");
        Errors([new() { Name = new string('B', 500), Value = "x" }]).Should().NotBeEmpty();
        Errors([.. Enumerable.Range(0, 16).Select(i => new MarketplaceCustomDetailInput { Name = $"D{i}", Value = "x" })])
            .Should().Contain(e => e.StartsWith("Add at most"));
        Errors([new() { Name = "Border", Value = "Zari" }]).Should().BeEmpty();
    }

    [Fact]
    public async Task Remove_AProductWithOtherColoursOnSale_IsRefused_UntilTheyGoFirst()
    {
        using var test = new TestMarketplace();
        var saved = await test.SaveHandlers.Handle(Saree(c => c.Variants =
        [
            new() { Colour = "Red", Price = 2_400m, Stock = 10 },
            new() { Colour = "Green", Price = 2_400m, Stock = 3 },
            new() { Colour = "Blue", Price = 2_400m, Stock = 4 },
        ]), default);
        var red = saved.Variants.Single(v => v.Colour == "Red");
        var green = saved.Variants.Single(v => v.Colour == "Green");

        var remove = () => test.ManageHandlers.Handle(new DeleteMarketplacePostCommand { Id = saved.Id }, default);

        await remove.Should().ThrowAsync<DomainException>()
            .WithMessage("Remove or switch off its other colours and sizes first: Green, Blue.");

        // Blue removed, Green switched off: only the main one (Red) is left on sale.
        await test.VariantsHandler.Handle(Replace(saved.Id,
        [
            new() { Id = red.Id, Colour = "Red", Price = 2_400m, Stock = 10 },
            new() { Id = green.Id, Colour = "Green", Price = 2_400m, Stock = 3, IsActive = false },
        ]), default);
        await remove.Should().NotThrowAsync("the main colour does not hold it back");
    }

    [Fact]
    public async Task Remove_AProductWithOneStockCount_IsAllowed()
    {
        using var test = new TestMarketplace();
        var saved = await test.SaveHandlers.Handle(Saree(), default);

        var remove = () => test.ManageHandlers.Handle(new DeleteMarketplacePostCommand { Id = saved.Id }, default);

        await remove.Should().NotThrowAsync();
    }

    [Fact]
    public async Task TheInactiveTile_CountsPausedPosts_AndLiveProductsWithAColourSwitchedOff()
    {
        using var test = new TestMarketplace();
        var free = await test.Db.Plans.SingleAsync(p => p.IsDefault);
        free.MaxActivePosts = 5;
        await test.Db.SaveChangesAsync();
        var partly = await test.SaveHandlers.Handle(Saree(c => c.Variants =
        [
            new() { Colour = "Red", Price = 2_400m, Stock = 10 },
            new() { Colour = "Green", Price = 2_400m, Stock = 3, IsActive = false },
        ]), default);
        var allOn = await test.SaveHandlers.Handle(Saree(c =>
        {
            c.Title = "Cotton saree";
            c.Variants = [new() { Colour = "Blue", Price = 900m, Stock = 2 }];
        }), default);
        var paused = await test.SaveHandlers.Handle(Saree(c => c.Title = "Paused saree"), default);
        await test.ManageHandlers.Handle(
            new ChangeMarketplacePostStatusCommand { Id = paused.Id, Status = nameof(MarketplacePostStatus.Paused) }, default);

        var summary = await test.QueryHandlers.Handle(new GetMyMarketplaceSummaryQuery(), default);
        var page = await test.QueryHandlers.Handle(new GetMyMarketplacePostsQuery { Inactive = true }, default);

        (summary.Paused, summary.Inactive).Should().Be((1, 2), "the paused post, and the saree with Green off");
        page.Items.Select(p => p.Id).Should().BeEquivalentTo([partly.Id, paused.Id]);
        page.Items.Should().NotContain(p => p.Id == allOn.Id);
    }

    [Fact]
    public async Task EveryColourSwitchedOff_IsOutOfStock()
    {
        using var test = new TestMarketplace();
        var saved = await test.SaveHandlers.Handle(Saree(), default);

        var dto = await test.VariantsHandler.Handle(Replace(saved.Id,
            [new() { Colour = "Red", Price = 2_400m, Stock = 10, IsActive = false }]), default);

        (dto.Quantity, dto.IsOutOfStock, dto.Price).Should().Be((0, true, 2_400m));
    }

    [Fact]
    public async Task UpdatingStock_CountsOnlyTheColoursOnSale()
    {
        using var test = new TestMarketplace();
        var saved = await test.SaveHandlers.Handle(Saree(c => c.Variants =
        [
            new() { Colour = "Red", Price = 2_400m, Stock = 10 },
            new() { Colour = "Blue", Price = 2_400m, Stock = 4, IsActive = false },
        ]), default);
        var red = saved.Variants.Single(v => v.Colour == "Red");

        var dto = await test.StockHandler.Handle(
            new UpdateMarketplacePostStockCommand { Id = saved.Id, VariantId = red.Id, Quantity = 7 }, default);

        dto.Quantity.Should().Be(7);
    }

    [Fact]
    public void AColourSentByAnOlderApp_IsOnSale()
    {
        var input = System.Text.Json.JsonSerializer.Deserialize<MarketplaceVariantInput>("""{"colour":"Red","stock":1}""");

        input!.IsActive.Should().BeTrue();
    }

    [Fact]
    public async Task StockList_HasOnlyNewProductsStillUp()
    {
        using var test = new TestMarketplace();
        var saree = test.Seed(p =>
        {
            p.Title = "Saree";
            p.Condition = MarketplaceItemCondition.New;
            p.Quantity = 4;
        });
        var paused = test.Seed(p =>
        {
            p.Title = "Paused";
            p.Condition = MarketplaceItemCondition.New;
            p.Quantity = 0;
            p.Status = MarketplacePostStatus.Paused;
        });
        test.Seed(p =>
        {
            p.Title = "Old bike";
            p.Condition = MarketplaceItemCondition.Used;
        });
        test.Seed(p =>
        {
            p.Title = "Closed";
            p.Condition = MarketplaceItemCondition.New;
            p.Quantity = 1;
            p.Status = MarketplacePostStatus.Closed;
        });

        var page = await test.QueryHandlers.Handle(new GetMyMarketplacePostsQuery { KeepsStock = true }, default);

        page.Items.Select(p => p.Id).Should().BeEquivalentTo([saree.Id, paused.Id]);
        page.TotalCount.Should().Be(2);
    }
}
