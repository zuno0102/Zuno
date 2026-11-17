using FluentAssertions;
using Zuno.Marketplace.Application.Posts;
using Zuno.Marketplace.Domain.Enums;

namespace Zuno.Marketplace.UnitTests;

/// <summary>
/// A B2B lot's available quantity is kept on its own stock page, like a product's: changed in a few
/// taps, at 0 sold out and hidden from buyers, its post never paused or closed from the menu.
/// </summary>
public class B2BStockTests
{
    [Fact]
    public async Task ABToBLot_OffersItsStock_AndTheStockChangesWithoutTheForm()
    {
        using var test = new TestMarketplace();
        var bananas = await test.SaveHandlers.Handle(TestMarketplace.Bananas(), default);

        bananas.CanUpdateStock.Should().BeTrue("a B2B lot keeps its available quantity up to date");
        var dto = await test.StockHandler.Handle(
            new UpdateMarketplacePostStockCommand { Id = bananas.Id, Quantity = 1500 }, default);

        dto.Quantity.Should().Be(1500);
        dto.IsOutOfStock.Should().BeFalse();
    }

    [Fact]
    public async Task ABToBLotAtZero_IsSoldOut_AndHiddenFromBuyers()
    {
        using var test = new TestMarketplace();
        var bananas = await test.SaveHandlers.Handle(TestMarketplace.Bananas(), default);

        var dto = await test.StockHandler.Handle(
            new UpdateMarketplacePostStockCommand { Id = bananas.Id, Quantity = 0 }, default);

        (dto.Quantity, dto.IsOutOfStock, dto.Status).Should().Be((0, true, "Active"));
    }

    [Fact]
    public async Task ABToBLot_WithNoQuantityStated_IsNotSoldOut()
    {
        using var test = new TestMarketplace();

        var dto = await test.SaveHandlers.Handle(TestMarketplace.Bananas(c => c.Quantity = null), default);

        (dto.Quantity, dto.IsOutOfStock).Should().Be((null, false));
    }

    [Fact]
    public async Task EditingASoldOutLot_KeepsItAtZero_WithoutTheMinimumOrderRule()
    {
        using var test = new TestMarketplace();
        var bananas = await test.SaveHandlers.Handle(TestMarketplace.Bananas(), default);

        var dto = await test.SaveHandlers.Handle(new UpdateMarketplacePostCommand
        {
            Id = bananas.Id,
            CategoryId = bananas.CategoryId,
            SubCategoryId = bananas.SubCategoryId,
            Title = bananas.Title,
            Price = bananas.Price,
            PriceUnit = bananas.PriceUnit,
            TradeType = "Wholesale",
            MinOrderQuantity = 100,
            Quantity = 0,
            DistrictId = bananas.DistrictId,
        }, default);

        (dto.Quantity, dto.IsOutOfStock).Should().Be((0, true));
    }

    [Fact]
    public async Task TheBToBStockList_HasTheBusinesssBToBPostsStillUp()
    {
        using var test = new TestMarketplace();
        var lot = test.Seed(p =>
        {
            p.Title = "Bananas";
            p.TradeType = MarketplaceTradeType.Wholesale;
            p.Quantity = 2000;
        });
        test.Seed(p =>
        {
            p.Title = "Closed lot";
            p.TradeType = MarketplaceTradeType.Wholesale;
            p.Status = MarketplacePostStatus.Closed;
        });
        test.Seed(p =>
        {
            p.Title = "Saree";
            p.Condition = MarketplaceItemCondition.New;
            p.Quantity = 4;
        });

        var page = await test.QueryHandlers.Handle(new GetMyMarketplacePostsQuery { Wholesale = true }, default);

        page.Items.Select(p => p.Id).Should().Equal(lot.Id);
    }
}
