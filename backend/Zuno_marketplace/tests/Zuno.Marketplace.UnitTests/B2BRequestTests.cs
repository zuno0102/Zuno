using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Application.Orders;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.UnitTests;

/// <summary>
/// B2B requests: a buyer asks, the seller accepts or declines, and each side's contact is shown only
/// to whoever may see it — the buyer needs a B2B plan running to see the seller's.
/// </summary>
public class B2BRequestTests
{
    private static readonly Guid Buyer = Guid.NewGuid();

    private sealed class Scene : IDisposable
    {
        public Scene()
        {
            Test = new TestMarketplace(TestMarketplace.OwnerA);
            Test.Db.Businesses.Add(new MarketplaceBusiness
            {
                OwnerUserId = TestMarketplace.OwnerA, Name = "Nanjil Farms", IsVerified = true, RefreshedAt = Test.Now,
            });
            Test.Db.SaveChanges();
            Lot = Test.Seed(p =>
            {
                p.CategoryId = MarketplaceCatalogSeedData.B2BWholesale;
                p.SubCategoryId = MarketplaceCatalogSeedData.SubId(4, 1);
                p.Title = "Nendran banana";
                p.Price = 38m;
                p.PriceUnit = "kg";
                p.TradeType = MarketplaceTradeType.Wholesale;
                p.MinOrderQuantity = 200;
                p.Quantity = 2000;
            });
        }

        public TestMarketplace Test { get; }

        public MarketplacePost Lot { get; }

        public FakeServiceDirectory Directory { get; } = new();

        public MarketplaceB2BRequestHandlers Handlers => new(Test.User, Test.Db, Directory, Test.Reference, Test.Clock, Test.Settings);

        public Task<MarketplaceB2BRequestDto> AskAsync(int quantity = 500, Guid? buyer = null)
        {
            Test.As(buyer ?? Buyer);
            Directory.Person = new ServicePerson("Kumar Traders", "9843012345");
            return Handlers.Handle(
                new CreateMarketplaceB2BRequestCommand { PostId = Lot.Id, Quantity = quantity, Message = "Weekly supply to Thuckalay?" },
                CancellationToken.None);
        }

        public Task<MarketplaceB2BRequestDto> RespondAsync(Guid id, bool accept)
        {
            Test.As(TestMarketplace.OwnerA);
            Directory.Person = new ServicePerson("Shajil", "9000011111");
            return Handlers.Handle(new RespondMarketplaceB2BRequestCommand { Id = id, Accept = accept }, CancellationToken.None);
        }

        public async Task<MarketplaceB2BRequestDto> BuyerViewAsync()
        {
            Test.As(Buyer);
            return (await Handlers.Handle(new GetMyB2BRequestsQuery(), CancellationToken.None)).Items.Single();
        }

        public void Dispose() => Test.Dispose();
    }

    [Fact]
    public async Task Seller_Sees_The_Buyers_Contact_Only_After_Accepting()
    {
        using var scene = new Scene();
        var asked = await scene.AskAsync();
        asked.Status.Should().Be("Requested");
        asked.StatusName.Should().Be("New");
        asked.Total.Should().Be(19_000m);
        asked.Unit.Should().Be("kg");

        scene.Test.As(TestMarketplace.OwnerA);
        var list = await scene.Handlers.Handle(new GetBusinessB2BRequestsQuery(), CancellationToken.None);
        var waiting = list.Items.Single();
        waiting.BuyerName.Should().Be("Kumar Traders");
        waiting.BuyerPhone.Should().BeNull("contact details show once the seller accepts");
        waiting.MinOrderQuantity.Should().Be(200);
        list.Counts.Single(c => c.Status == "Requested").Count.Should().Be(1);

        var accepted = await scene.RespondAsync(asked.Id, accept: true);
        accepted.Status.Should().Be("Accepted");
        accepted.BuyerPhone.Should().Be("9843012345");
        accepted.SellerName.Should().Be("shajil shajil");
    }

    [Fact]
    public async Task Buyer_Sees_The_Sellers_Contact_Only_With_A_B2B_Plan_Running()
    {
        using var scene = new Scene();
        var asked = await scene.AskAsync();
        await scene.RespondAsync(asked.Id, accept: true);

        var withoutPlan = await scene.BuyerViewAsync();
        withoutPlan.SellerName.Should().Be("shajil shajil");
        withoutPlan.SellerPhone.Should().BeNull();
        withoutPlan.ContactNeedsPlan.Should().BeTrue();
        withoutPlan.BuyerPhone.Should().BeNull("the buyer's own view does not echo their number");

        scene.Test.Db.BusinessPlans.Add(new MarketplaceBusinessPlan
        {
            OwnerUserId = Buyer,
            PlanId = MarketplaceCatalogSeedData.B2BBuyerPlan,
            StartsAt = scene.Test.Now.AddDays(-1),
            EndsAt = scene.Test.Now.AddDays(29),
        });
        scene.Test.Db.SaveChanges();
        var withPlan = await scene.BuyerViewAsync();
        withPlan.SellerPhone.Should().Be("9000011111");
        withPlan.ContactNeedsPlan.Should().BeFalse();

        scene.Test.Clock.Current = scene.Test.Now.AddDays(30);
        var lapsed = await scene.BuyerViewAsync();
        lapsed.SellerPhone.Should().BeNull("the plan ran out");
    }

    [Fact]
    public async Task Declined_Request_Shares_No_Contact_And_Cannot_Be_Accepted_Later()
    {
        using var scene = new Scene();
        var asked = await scene.AskAsync();
        var declined = await scene.RespondAsync(asked.Id, accept: false);
        declined.Status.Should().Be("Declined");
        declined.BuyerPhone.Should().BeNull();

        var acceptLater = () => scene.RespondAsync(asked.Id, accept: true);
        await acceptLater.Should().ThrowAsync<DomainException>();

        // A declined request leaves room to ask again.
        var again = await scene.AskAsync();
        again.Status.Should().Be("Requested");
    }

    [Fact]
    public async Task Request_Must_Meet_The_Smallest_Order_And_Not_Pass_What_Is_Available()
    {
        using var scene = new Scene();
        var tooFew = () => scene.AskAsync(150);
        (await tooFew.Should().ThrowAsync<DomainException>()).WithMessage("The smallest order is 200 kg*");

        var tooMany = () => scene.AskAsync(2500);
        (await tooMany.Should().ThrowAsync<DomainException>()).WithMessage("Only 2000 kg available*");

        await scene.AskAsync();
        var twice = () => scene.AskAsync();
        await twice.Should().ThrowAsync<DomainException>("one open request per buyer and lot");
    }

    [Fact]
    public async Task Seller_Cannot_Ask_For_Their_Own_Lot_Nor_Answer_Another_Sellers_Request()
    {
        using var scene = new Scene();
        var own = () => scene.AskAsync(buyer: TestMarketplace.OwnerA);
        await own.Should().ThrowAsync<DomainException>();

        var asked = await scene.AskAsync();
        scene.Test.As(TestMarketplace.OwnerB);
        var answer = () => scene.Handlers.Handle(new RespondMarketplaceB2BRequestCommand { Id = asked.Id, Accept = true }, CancellationToken.None);
        await answer.Should().ThrowAsync<ForbiddenException>();
    }

    [Fact]
    public async Task Product_Posts_Cannot_Be_Asked_For_As_B2B()
    {
        using var scene = new Scene();
        var product = scene.Test.Seed(p => { p.Condition = MarketplaceItemCondition.New; p.Quantity = 4; });
        scene.Test.As(Buyer);
        var ask = () => scene.Handlers.Handle(
            new CreateMarketplaceB2BRequestCommand { PostId = product.Id, Quantity = 1 }, CancellationToken.None);
        await ask.Should().ThrowAsync<DomainException>();
    }

    [Fact]
    public async Task A_Running_B2B_Buyer_Plan_Is_Found()
    {
        using var scene = new Scene();
        scene.Test.Db.BusinessPlans.Add(new MarketplaceBusinessPlan
        {
            OwnerUserId = TestMarketplace.OwnerA,
            PlanId = MarketplaceCatalogSeedData.B2BBuyerPlan,
            StartsAt = scene.Test.Now.AddDays(-1),
        });
        scene.Test.Db.SaveChanges();

        (await scene.Test.Db.HasB2BBuyerPlanAsync(TestMarketplace.OwnerA, scene.Test.Now, CancellationToken.None)).Should().BeTrue();
        (await scene.Test.Db.HasB2BBuyerPlanAsync(TestMarketplace.OwnerB, scene.Test.Now, CancellationToken.None)).Should().BeFalse();
    }

    [Fact]
    public void The_B2B_Buyer_Plan_Is_199_A_Month()
    {
        var plan = MarketplaceCatalogSeedData.Plans.Single(p => p.Purpose == MarketplacePlanPurpose.B2BBuyer);
        plan.Price.Should().Be(199m);
        plan.DurationDays.Should().Be(30);
        plan.IsDefault.Should().BeFalse();
    }
}
