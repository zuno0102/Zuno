using FluentAssertions;
using FluentValidation.TestHelper;
using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Application.Customer;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.UnitTests;

/// <summary>
/// What customers browse — home, search, a post opened, the wishlist — against the one visibility
/// rule: live, started, in stock, active category, verified business.
/// </summary>
public class CustomerBrowseTests
{
    private static readonly Guid Customer = Guid.NewGuid();
    private static readonly Guid OtherCustomer = Guid.NewGuid();

    // Nagercoil and a shop ~12 km away in Marthandam's direction, and one ~1 km away.
    private const double HomeLat = 8.1833;
    private const double HomeLng = 77.4119;

    private sealed class Scene : IDisposable
    {
        public Scene()
        {
            Test = new TestMarketplace(TestMarketplace.OwnerA);
            Test.Db.Businesses.AddRange(
                new MarketplaceBusiness { OwnerUserId = TestMarketplace.OwnerA, Name = "Joy Silks", IsVerified = true, RefreshedAt = Test.Now },
                new MarketplaceBusiness { OwnerUserId = TestMarketplace.OwnerB, Name = "Not Yet Verified", IsVerified = false, RefreshedAt = Test.Now });
            Test.Db.SaveChanges();
        }

        public TestMarketplace Test { get; }

        public FakePaymentGateway Gateway { get; } = new();

        public MarketplaceBrowseHandlers Browse => new(Test.User, Test.Db, Test.Reference, Gateway, Test.Clock, Test.Settings);

        public MarketplacePost Product(string title = "Silk saree", Action<MarketplacePost>? change = null) =>
            Test.Seed(p =>
            {
                p.Title = title;
                p.SubCategoryId = MarketplaceCatalogSeedData.SubId(3, 1);
                p.Condition = MarketplaceItemCondition.New;
                p.Quantity = 5;
                change?.Invoke(p);
            });

        public MarketplacePost Food(string title, double? lat = null, double? lng = null, Action<MarketplacePost>? change = null) =>
            Test.Seed(p =>
            {
                p.Title = title;
                p.Kind = MarketplacePostKind.FoodOffer;
                p.CategoryId = MarketplaceCatalogSeedData.NearbyFood;
                p.SubCategoryId = MarketplaceCatalogSeedData.SubId(5, 1);
                p.Price = 99m;
                p.OriginalPrice = 180m;
                p.Quantity = 10;
                p.StartsAt = Test.Now.AddHours(-1);
                p.EndsAt = Test.Now.AddHours(3);
                p.Latitude = lat;
                p.Longitude = lng;
                change?.Invoke(p);
            });

        public MarketplacePost Ad(bool withBanner = true) =>
            Test.Seed(p =>
            {
                p.Title = "Aadi sale";
                p.Kind = MarketplacePostKind.Advertisement;
                p.CategoryId = MarketplaceCatalogSeedData.Advertisements;
                p.SubCategoryId = MarketplaceCatalogSeedData.SubId(6, 1);
                p.Price = null;
                p.StartsAt = Test.Now.AddDays(-1);
                p.EndsAt = Test.Now.AddDays(10);
                if (withBanner)
                {
                    p.Media = [new MarketplacePostMedia { Url = "/uploads/marketplace/ad/image-0.jpg", SortOrder = 0 }];
                }
            });

        public MarketplacePost Lot() =>
            Test.Seed(p =>
            {
                p.Title = "Nendran banana";
                p.CategoryId = MarketplaceCatalogSeedData.B2BWholesale;
                p.SubCategoryId = MarketplaceCatalogSeedData.SubId(4, 1);
                p.TradeType = MarketplaceTradeType.Wholesale;
                p.Price = 38m;
                p.PriceUnit = "kg";
                p.MinOrderQuantity = 200;
                p.Quantity = 2000;
            });

        public Task<MarketplaceHomeDto> HomeAsync(double? lat = null, double? lng = null, List<Guid>? districts = null)
        {
            Test.As(Customer);
            return Browse.Handle(
                new GetMarketplaceHomeQuery { Latitude = lat, Longitude = lng, DistrictIds = districts ?? [] }, CancellationToken.None);
        }

        public Task<MarketplaceCardPageDto> SearchAsync(Action<SearchMarketplacePostsQuery>? change = null)
        {
            Test.As(Customer);
            var query = new SearchMarketplacePostsQuery();
            change?.Invoke(query);
            return Browse.Handle(query, CancellationToken.None);
        }

        public Task<MarketplacePostDetailDto> DetailAsync(Guid id)
        {
            Test.As(Customer);
            return Browse.Handle(new GetMarketplacePostDetailQuery { Id = id }, CancellationToken.None);
        }

        public Task SaveAsync(Guid postId, Guid? user = null)
        {
            Test.As(user ?? Customer);
            return Browse.Handle(new AddFavouriteCommand { PostId = postId }, CancellationToken.None);
        }

        public Task<MarketplaceCardPageDto> WishlistAsync(Guid? user = null)
        {
            Test.As(user ?? Customer);
            return Browse.Handle(new GetMyFavouritesQuery(), CancellationToken.None);
        }

        public void Dispose() => Test.Dispose();
    }

    [Fact]
    public async Task Home_Fills_Each_Section_With_What_Belongs_There()
    {
        using var scene = new Scene();
        var saree = scene.Product();
        var biryani = scene.Food("Veg biryani");
        var ad = scene.Ad();
        var lot = scene.Lot();

        var home = await scene.HomeAsync();

        home.Banners.Select(c => c.Id).Should().Equal(ad.Id);
        home.Banners[0].ImageUrl.Should().Be("/uploads/marketplace/ad/image-0.jpg");
        home.Food.Select(c => c.Id).Should().Equal(biryani.Id);
        home.Food[0].OriginalPrice.Should().Be(180m);
        home.Products.Select(c => c.Id).Should().Equal(saree.Id);
        home.Products[0].BusinessName.Should().Be("Joy Silks");
        home.Products[0].DistrictName.Should().Be("Kanyakumari");
        home.Wholesale.Select(c => c.Id).Should().Equal(lot.Id);
        home.Wholesale[0].TradeType.Should().Be("Wholesale");
    }

    [Fact]
    public async Task Home_Hides_What_Customers_May_Not_See()
    {
        using var scene = new Scene();
        scene.Test.As(TestMarketplace.OwnerB);
        scene.Product("From an unverified business");
        scene.Test.As(TestMarketplace.OwnerA);
        scene.Product("Paused saree", p => p.Status = MarketplacePostStatus.Paused);
        scene.Product("Sold out saree", p => p.Quantity = 0);
        scene.Product("Closed saree", p => p.Status = MarketplacePostStatus.Closed);
        scene.Food("Yesterday's biryani", change: p => p.EndsAt = scene.Test.Now.AddMinutes(-1));
        scene.Food("Tomorrow's biryani", change: p => p.StartsAt = scene.Test.Now.AddDays(1));
        scene.Ad(withBanner: false);

        var home = await scene.HomeAsync();

        home.Products.Should().BeEmpty();
        home.Food.Should().BeEmpty();
        home.Banners.Should().BeEmpty("an advert with no banner photo has nothing to slide");
        home.Wholesale.Should().BeEmpty();
    }

    [Fact]
    public async Task Home_Sorts_Food_Nearest_First_And_Keeps_Each_Section_To_Its_Size()
    {
        using var scene = new Scene();
        scene.Test.Limits.HomeSectionSize = 2;
        var far = scene.Food("Far biryani", 8.3, 77.2);
        var near = scene.Food("Near biryani", 8.19, 77.41);
        var noPin = scene.Food("No pin biryani");
        scene.Product("One");
        scene.Product("Two");
        scene.Product("Three");

        var home = await scene.HomeAsync(HomeLat, HomeLng);

        home.Food.Select(c => c.Id).Should().Equal(near.Id, far.Id);
        home.Food[0].DistanceKm.Should().BeLessThan(2);
        home.Food[1].DistanceKm.Should().BeGreaterThan(20);
        home.Food.Should().NotContain(c => c.Id == noPin.Id, "a post without a pin sorts after every pinned one");
        home.Products.Should().HaveCount(2);
    }

    [Fact]
    public async Task Home_Keeps_Food_And_Adverts_To_The_Customers_Districts()
    {
        using var scene = new Scene();
        scene.Food("Veg biryani");
        scene.Ad();
        var saree = scene.Product();
        var elsewhere = LocationSeedData.DistrictId("Tamil Nadu", "Tirunelveli");

        var home = await scene.HomeAsync(districts: [elsewhere]);

        home.Food.Should().BeEmpty();
        home.Banners.Should().BeEmpty();
        home.Products.Select(c => c.Id).Should().Equal([saree.Id], "products ship, so they show wherever the customer is");
    }

    [Fact]
    public async Task Search_Matches_Words_In_Any_Case_And_Takes_Wildcards_Literally()
    {
        using var scene = new Scene();
        var saree = scene.Product("Kanchipuram Silk Saree");
        scene.Product("Cotton kurta");

        (await scene.SearchAsync(q => q.Keyword = "  silk ")).Items.Select(c => c.Id).Should().Equal(saree.Id);
        (await scene.SearchAsync(q => q.Keyword = "%")).TotalCount.Should().Be(0, "% is a letter to search for, not 'everything'");
        (await scene.SearchAsync(q => q.Keyword = "nothing like this")).Items.Should().BeEmpty();
    }

    [Fact]
    public async Task Search_Filters_By_Kind_And_B2B_And_Pages_With_A_Capped_Size()
    {
        using var scene = new Scene();
        scene.Test.Limits.MaxPageSize = 2;
        scene.Product("One");
        scene.Product("Two");
        scene.Product("Three");
        var lot = scene.Lot();
        var biryani = scene.Food("Veg biryani");

        (await scene.SearchAsync(q => q.Kind = "FoodOffer")).Items.Select(c => c.Id).Should().Equal(biryani.Id);
        (await scene.SearchAsync(q => q.Wholesale = true)).Items.Select(c => c.Id).Should().Equal(lot.Id);

        var products = await scene.SearchAsync(q =>
        {
            q.Kind = "Listing";
            q.Wholesale = false;
            q.PageSize = 50;
        });
        products.TotalCount.Should().Be(3);
        products.PageSize.Should().Be(2, "the page size is capped by the settings");
        products.Items.Should().HaveCount(2);

        var last = await scene.SearchAsync(q =>
        {
            q.Kind = "Listing";
            q.Wholesale = false;
            q.Page = 2;
        });
        last.Items.Should().HaveCount(1);
    }

    [Fact]
    public async Task Detail_Shows_Only_What_Is_On_Sale_With_Labelled_Details()
    {
        using var scene = new Scene();
        var car = scene.Product("Swift VXi", p =>
        {
            p.SubCategoryId = MarketplaceCatalogSeedData.Vehicles;
            p.Attributes = [new() { Key = "brand", Value = "Maruti" }, new() { Key = "km_driven", Value = "48000" }];
            p.CustomDetails = [new() { Key = "Owners", Value = "1" }];
            p.Variants =
            [
                new MarketplacePostVariant { Colour = "Red", Stock = 3, SortOrder = 0, IsActive = false },
                new MarketplacePostVariant { Colour = "Blue", Stock = 2, SortOrder = 1 },
                new MarketplacePostVariant { Colour = "Green", Stock = 4, SortOrder = 2, IsActive = false },
            ];
        });

        var detail = await scene.DetailAsync(car.Id);

        detail.Card.Title.Should().Be("Swift VXi");
        detail.Variants.Select(v => v.Colour).Should().Equal(["Red", "Blue"], "the main one is always on sale; a switched-off colour is not");
        detail.Details.Select(d => $"{d.Name}: {d.Value}").Should().Equal("Brand: Maruti", "KM driven: 48000 km", "Owners: 1");
        detail.CanOrder.Should().BeTrue();
        detail.CanRequest.Should().BeFalse();
        detail.PaymentMethods.Select(m => m.Code).Should().Equal("CashOnDelivery", "Online");
    }

    [Fact]
    public async Task Detail_Offers_Only_The_Ways_The_Seller_Can_Be_Paid_Now()
    {
        using var scene = new Scene();
        var saree = scene.Product();

        scene.Gateway.IsReady = false;
        (await scene.DetailAsync(saree.Id)).PaymentMethods.Select(m => m.Code).Should().Equal(["CashOnDelivery"], "online pay is not offered while it cannot be taken");

        scene.Gateway.IsReady = true;
        var business = scene.Test.Db.Businesses.Single(b => b.OwnerUserId == TestMarketplace.OwnerA);
        business.AcceptsCashOnDelivery = false;
        await scene.Test.Db.SaveChangesAsync();
        (await scene.DetailAsync(saree.Id)).PaymentMethods.Select(m => m.Code).Should().Equal("Online");
    }

    [Fact]
    public async Task Detail_Of_A_Hidden_Or_Unknown_Post_Is_Not_Found()
    {
        using var scene = new Scene();
        var paused = scene.Product(change: p => p.Status = MarketplacePostStatus.Paused);

        await scene.Invoking(s => s.DetailAsync(paused.Id)).Should().ThrowAsync<EntityNotFoundException>();
        await scene.Invoking(s => s.DetailAsync(Guid.NewGuid())).Should().ThrowAsync<EntityNotFoundException>();
    }

    [Fact]
    public async Task Detail_Of_A_B2B_Lot_Asks_For_A_Request_Not_An_Order()
    {
        using var scene = new Scene();
        var lot = scene.Lot();

        var detail = await scene.DetailAsync(lot.Id);

        detail.CanRequest.Should().BeTrue();
        detail.CanOrder.Should().BeFalse();
        detail.Card.MinOrderQuantity.Should().Be(200);
    }

    [Fact]
    public async Task Wishlist_Saves_Once_Shows_Hearts_And_Removes()
    {
        using var scene = new Scene();
        var saree = scene.Product();

        await scene.SaveAsync(saree.Id);
        await scene.SaveAsync(saree.Id);

        scene.Test.Db.Favourites.AsNoTracking().Count().Should().Be(1, "saving twice is the same as once");
        var list = await scene.WishlistAsync();
        list.TotalCount.Should().Be(1);
        list.Items.Single().IsFavourite.Should().BeTrue();
        (await scene.HomeAsync()).Products.Single().IsFavourite.Should().BeTrue();
        (await scene.DetailAsync(saree.Id)).Card.IsFavourite.Should().BeTrue();

        scene.Test.As(Customer);
        await scene.Browse.Handle(new RemoveFavouriteCommand { PostId = saree.Id }, CancellationToken.None);
        await scene.Browse.Handle(new RemoveFavouriteCommand { PostId = saree.Id }, CancellationToken.None);

        (await scene.WishlistAsync()).Items.Should().BeEmpty();
        (await scene.HomeAsync()).Products.Single().IsFavourite.Should().BeFalse();
    }

    [Fact]
    public async Task Wishlist_Is_Each_Customers_Own()
    {
        using var scene = new Scene();
        var saree = scene.Product();

        await scene.SaveAsync(saree.Id);

        (await scene.WishlistAsync(OtherCustomer)).Items.Should().BeEmpty();
        scene.Test.As(OtherCustomer);
        (await scene.Browse.Handle(new GetMarketplaceHomeQuery(), CancellationToken.None)).Products.Single().IsFavourite.Should().BeFalse();
    }

    [Fact]
    public async Task Wishlist_Keeps_A_Post_No_Longer_On_Sale_Marked_Not_Available()
    {
        using var scene = new Scene();
        var saree = scene.Product();
        await scene.SaveAsync(saree.Id);

        var post = scene.Test.Db.Posts.Single(p => p.Id == saree.Id);
        post.Status = MarketplacePostStatus.Sold;
        await scene.Test.Db.SaveChangesAsync();

        var card = (await scene.WishlistAsync()).Items.Single();
        card.IsAvailable.Should().BeFalse();
        card.IsFavourite.Should().BeTrue();
    }

    [Fact]
    public async Task Wishlist_Refuses_A_Hidden_Post_And_Stops_At_Its_Limit()
    {
        using var scene = new Scene();
        scene.Test.Limits.MaxFavourites = 1;
        var paused = scene.Product("Paused", p => p.Status = MarketplacePostStatus.Paused);
        var one = scene.Product("One");
        var two = scene.Product("Two");

        await scene.Invoking(s => s.SaveAsync(paused.Id)).Should().ThrowAsync<EntityNotFoundException>();
        await scene.SaveAsync(one.Id);
        await scene.Invoking(s => s.SaveAsync(two.Id)).Should().ThrowAsync<DomainException>().WithMessage("*full (1 items)*");
        await scene.SaveAsync(one.Id);
    }

    [Theory]
    [InlineData(8.1, null)]
    [InlineData(null, 77.4)]
    [InlineData(91.0, 77.4)]
    [InlineData(8.1, 181.0)]
    public void A_Place_Is_Both_Coordinates_In_Range_Or_Neither(double? lat, double? lng)
    {
        new GetMarketplaceHomeQueryValidator()
            .TestValidate(new GetMarketplaceHomeQuery { Latitude = lat, Longitude = lng })
            .IsValid.Should().BeFalse();
        new GetMarketplaceHomeQueryValidator().TestValidate(new GetMarketplaceHomeQuery()).IsValid.Should().BeTrue();
    }

    [Fact]
    public void Search_Refuses_An_Unknown_Kind_Too_Many_Districts_And_Overlong_Words()
    {
        using var test = new TestMarketplace();
        var validator = new SearchMarketplacePostsQueryValidator(test.Settings);

        validator.TestValidate(new SearchMarketplacePostsQuery { Kind = "Lottery" }).ShouldHaveValidationErrorFor(x => x.Kind);
        validator.TestValidate(new SearchMarketplacePostsQuery { Keyword = new string('a', test.Limits.MaxSearchLength + 1) })
            .ShouldHaveValidationErrorFor(x => x.Keyword);
        validator.TestValidate(new SearchMarketplacePostsQuery { DistrictIds = Enumerable.Range(0, 21).Select(_ => Guid.NewGuid()).ToList() })
            .IsValid.Should().BeFalse();
        validator.TestValidate(new SearchMarketplacePostsQuery { Keyword = "saree", Kind = "listing" }).IsValid.Should().BeTrue();
    }
}
