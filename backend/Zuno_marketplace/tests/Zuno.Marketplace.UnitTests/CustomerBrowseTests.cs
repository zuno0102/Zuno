using FluentAssertions;
using FluentValidation.TestHelper;
using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Application.Admin;
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

            // Each read worked out afresh; the one test of the kept ranking switches it back on.
            Test.Limits.HomeCacheSeconds = 0;
        }

        public TestMarketplace Test { get; }

        public FakePaymentGateway Gateway { get; } = new();

        public MarketplaceBrowseHandlers Browse => new(Test.User, Test.Db, Test.Reference, Gateway, Test.Clock, Test.Settings);

        public MarketplaceHomeHandler Home => new(Test.User, Test.Db, Test.Reference, Test.Clock, Test.Settings, Test.Cache);

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

        /// <summary>An advert; <paramref name="paid"/> gives it a banner paid for a week.</summary>
        public MarketplacePost Ad(bool withBanner = true, bool paid = true) =>
            Test.Seed(p =>
            {
                p.BannerPaidUntil = paid ? Test.Now.AddDays(7) : null;
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
            return Home.Handle(
                new GetMarketplaceHomeQuery { Latitude = lat, Longitude = lng, DistrictIds = districts ?? [] }, CancellationToken.None);
        }

        /// <summary>An order by the customer, <paramref name="daysAgo"/> days back.</summary>
        public void Order(
            MarketplacePost post,
            int quantity = 1,
            MarketplaceOrderStatus status = MarketplaceOrderStatus.Delivered,
            short? rating = null,
            int daysAgo = 0)
        {
            var now = Test.Clock.Current;
            Test.Clock.Current = now.AddDays(-daysAgo);
            Test.Db.Orders.Add(new MarketplaceOrder
            {
                PostId = post.Id,
                OwnerUserId = post.OwnerUserId,
                CustomerUserId = Customer,
                CustomerName = "Priya",
                CustomerPhone = "9876543210",
                DeliveryAddress = "12, North Street",
                Pincode = "629001",
                Title = post.Title,
                Quantity = quantity,
                UnitPrice = 100m,
                Amount = 100m * quantity,
                PaymentMethod = MarketplacePaymentMethod.CashOnDelivery,
                Status = status,
                RatingScore = rating,
            });
            Test.Db.SaveChanges();
            Test.Db.ChangeTracker.Clear();
            Test.Clock.Current = now;
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

    private static MarketplaceHomeSectionDto Section(MarketplaceHomeDto home, string code) =>
        home.Sections.Single(s => s.Code == code);

    private static List<Guid> Ids(MarketplaceHomeDto home, string code) =>
        home.Sections.SingleOrDefault(s => s.Code == code)?.Items.Select(c => c.Id).ToList() ?? [];

    [Fact]
    public async Task Home_Is_The_Section_Rows_In_Order_Each_Filled_From_Its_Source()
    {
        using var scene = new Scene();
        var saree = scene.Product();
        var biryani = scene.Food("Veg biryani");
        var ad = scene.Ad();
        var lot = scene.Lot();

        var home = await scene.HomeAsync();

        home.Sections.Select(s => s.Code).Should().Equal("just_in", "banners", "b2b_lots", "food", "all");
        home.Sections.Select(s => s.Layout).Should().Equal("Grid", "Banner", "Strip", "Grid", "Feed");
        Ids(home, "just_in").Should().Equal(saree.Id);
        Section(home, "just_in").Title.Should().Be("Just in");
        Section(home, "just_in").Items[0].BusinessName.Should().Be("Joy Silks");
        Ids(home, "banners").Should().Equal(ad.Id);
        Section(home, "banners").Items[0].ImageUrl.Should().Be("/uploads/marketplace/ad/image-0.jpg");
        Ids(home, "food").Should().Equal(biryani.Id);
        Section(home, "food").Items[0].OriginalPrice.Should().Be(180m);
        Ids(home, "b2b_lots").Should().Equal(lot.Id);
        Section(home, "all").Items.Should().BeEmpty("the app pages the feed itself");
        Section(home, "all").PageSize.Should().Be(20);
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

        home.Sections.Select(s => s.Code).Should().Equal(["all"], "an empty section is left out, and an advert with no banner photo has nothing to slide");
    }

    [Fact]
    public async Task Home_Banner_Shows_Only_Adverts_Whose_Paid_Banner_Is_Running()
    {
        using var scene = new Scene();
        var paid = scene.Ad();
        scene.Ad(paid: false);
        var ended = scene.Ad();
        var row = scene.Test.Db.Posts.Single(p => p.Id == ended.Id);
        row.BannerPaidUntil = scene.Test.Now.AddMinutes(-1);
        scene.Test.Db.SaveChanges();

        Ids(await scene.HomeAsync(), "banners").Should().Equal(paid.Id);
    }

    [Fact]
    public async Task Home_With_No_Paid_Banner_Has_No_Banner_Section()
    {
        using var scene = new Scene();
        scene.Ad(paid: false);
        scene.Product();

        (await scene.HomeAsync()).Sections.Should().NotContain(s => s.Code == "banners");
    }

    [Fact]
    public async Task Admin_Records_A_Paid_Banner_On_An_Advert_Only_And_Can_End_It()
    {
        using var scene = new Scene();
        var ad = scene.Ad(paid: false);
        var saree = scene.Product();
        var admin = new SetMarketplaceBannerCommandHandler(scene.Test.Db);

        var set = await admin.Handle(new SetMarketplaceBannerCommand { Id = ad.Id, PaidUntil = scene.Test.Now.AddDays(30) }, default);
        set.BannerPaidUntil.Should().Be(scene.Test.Now.AddDays(30));
        Ids(await scene.HomeAsync(), "banners").Should().Equal(ad.Id);

        await admin.Handle(new SetMarketplaceBannerCommand { Id = ad.Id, PaidUntil = null }, default);
        (await scene.HomeAsync()).Sections.Should().NotContain(s => s.Code == "banners");

        var product = () => admin.Handle(new SetMarketplaceBannerCommand { Id = saree.Id, PaidUntil = scene.Test.Now.AddDays(1) }, default);
        await product.Should().ThrowAsync<DomainException>().WithMessage("Only an advert*");

        var validator = new SetMarketplaceBannerCommandValidator(scene.Test.Clock);
        validator.TestValidate(new SetMarketplaceBannerCommand { Id = ad.Id, PaidUntil = scene.Test.Now.AddDays(-1) })
            .ShouldHaveValidationErrorFor(x => x.PaidUntil);
        validator.TestValidate(new SetMarketplaceBannerCommand { Id = ad.Id, PaidUntil = scene.Test.Now.AddDays(400) })
            .ShouldHaveValidationErrorFor(x => x.PaidUntil);
        validator.TestValidate(new SetMarketplaceBannerCommand { Id = ad.Id, PaidUntil = null }).ShouldNotHaveAnyValidationErrors();
    }

    [Fact]
    public async Task Home_Second_Newest_Section_Carries_On_Where_The_First_Stopped()
    {
        using var scene = new Scene();
        var start = scene.Test.Now;
        var products = Enumerable.Range(1, 20).Select(i =>
        {
            scene.Test.Clock.Current = start.AddMinutes(i);
            return scene.Product($"Product {i}");
        }).ToList();
        scene.Test.Clock.Current = start.AddHours(1);

        var home = await scene.HomeAsync();

        var newestFirst = products.AsEnumerable().Reverse().Select(p => p.Id).ToList();
        Ids(home, "just_in").Should().Equal(newestFirst.Take(8), "four rows of two");
        Ids(home, "more_to_explore").Should().Equal(newestFirst.Skip(8).Take(10), "five rows of two, none repeated");
    }

    [Fact]
    public async Task Home_Sorts_Food_Nearest_First()
    {
        using var scene = new Scene();
        var far = scene.Food("Far biryani", 8.3, 77.2);
        var near = scene.Food("Near biryani", 8.19, 77.41);
        var noPin = scene.Food("No pin biryani");

        var food = Section(await scene.HomeAsync(HomeLat, HomeLng), "food").Items;

        food.Select(c => c.Id).Should().Equal(near.Id, far.Id, noPin.Id);
        food[0].DistanceKm.Should().BeLessThan(2);
        food[1].DistanceKm.Should().BeGreaterThan(20);
        food[2].DistanceKm.Should().BeNull("a post without a pin sorts after every pinned one");
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

        home.Sections.Should().NotContain(s => s.Code == "food" || s.Code == "banners");
        Ids(home, "just_in").Should().Equal([saree.Id], "products ship, so they show wherever the customer is");
    }

    [Fact]
    public async Task Home_Puts_Each_Product_In_One_Discount_Band_Biggest_Discount_First()
    {
        using var scene = new Scene();
        static Action<MarketplacePost> Mrp(decimal price) => p =>
        {
            p.OriginalPrice = 1000m;
            p.Price = price;
        };
        var seventyFive = scene.Product("75% off", Mrp(250m));
        var fiftyFive = scene.Product("55% off", Mrp(450m));
        var fifty = scene.Product("50% off exactly", Mrp(500m));
        var thirtyFive = scene.Product("35% off", Mrp(650m));
        scene.Product("5% off", Mrp(950m));
        scene.Product("No MRP");

        var home = await scene.HomeAsync();

        Ids(home, "off_70").Should().Equal(seventyFive.Id);
        Ids(home, "off_50").Should().Equal(fiftyFive.Id, fifty.Id);
        Ids(home, "off_30").Should().Equal(thirtyFive.Id);
        home.Sections.Should().NotContain(s => s.Code == "off_10", "5% is under every band");
    }

    [Fact]
    public async Task Home_For_Men_Shows_Mens_And_Unisex_Products()
    {
        using var scene = new Scene();
        static Action<MarketplacePost> For(string value) =>
            p => p.Attributes = [new() { Key = MarketplaceHomeHandler.AudienceKey, Value = value }];
        var shirt = scene.Product("Shirt", For("Men"));
        var cap = scene.Product("Cap", For("Unisex"));
        var kurti = scene.Product("Kurti", For("Women"));

        var home = await scene.HomeAsync();

        Ids(home, "for_men").Should().BeEquivalentTo([shirt.Id, cap.Id]);
        Ids(home, "for_women").Should().BeEquivalentTo([kurti.Id, cap.Id]);
        home.Sections.Should().NotContain(s => s.Code == "for_kids");
    }

    [Fact]
    public async Task Home_Ranks_Best_Sellers_By_Units_Most_Reviewed_By_Reviews_And_Trending_By_Recent_Orders()
    {
        using var scene = new Scene();
        var popular = scene.Product("Ordered often");
        var bulk = scene.Product("One big order");
        var reviewed = scene.Product("Reviewed");
        var cancelledOnly = scene.Product("Only cancelled");

        scene.Order(bulk, quantity: 10, daysAgo: 30);
        scene.Order(popular);
        scene.Order(popular);
        scene.Order(popular);
        scene.Order(reviewed, rating: 5);
        scene.Order(reviewed, rating: 4, daysAgo: 30);
        scene.Order(cancelledOnly, quantity: 50, status: MarketplaceOrderStatus.Cancelled);

        var home = await scene.HomeAsync();

        Ids(home, "best_sellers").Should().Equal(bulk.Id, popular.Id, reviewed.Id);
        Ids(home, "most_reviewed").Should().Equal(reviewed.Id);
        Ids(home, "trending").Should().Equal(popular.Id, reviewed.Id);
    }

    [Fact]
    public async Task Home_Recommends_From_What_The_Customer_Ordered_And_Saved_And_Shows_Their_Wishlist()
    {
        using var scene = new Scene();
        var ordered = scene.Product("Ordered saree");
        var anotherSaree = scene.Product("Another saree");
        var toy = scene.Product("Toy car", p => p.SubCategoryId = MarketplaceCatalogSeedData.SubId(3, 4));
        var savedShoe = scene.Product("Saved shoe", p => p.SubCategoryId = MarketplaceCatalogSeedData.SubId(3, 3));
        var otherShoe = scene.Product("Other shoe", p => p.SubCategoryId = MarketplaceCatalogSeedData.SubId(3, 3));
        scene.Order(ordered);
        await scene.SaveAsync(savedShoe.Id);

        var home = await scene.HomeAsync();

        Ids(home, "recommended").Should().BeEquivalentTo(
            [anotherSaree.Id, savedShoe.Id, otherShoe.Id], "the same kinds of thing, but not what they already bought");
        Ids(home, "recommended").Should().NotContain(toy.Id);
        Ids(home, "wishlist").Should().Equal(savedShoe.Id);
        Section(home, "wishlist").Items.Single().IsFavourite.Should().BeTrue();
    }

    [Fact]
    public async Task Home_A_New_Customer_Has_No_Recommended_Or_Wishlist_Row()
    {
        using var scene = new Scene();
        scene.Product();

        var home = await scene.HomeAsync();

        home.Sections.Should().NotContain(s => s.Code == "recommended" || s.Code == "wishlist");
    }

    [Fact]
    public async Task Home_Keeps_A_Ranking_Briefly_But_Never_Shows_A_Post_That_Went_Off_Sale()
    {
        using var scene = new Scene();
        scene.Test.Limits.HomeCacheSeconds = 120;
        var first = scene.Product("First");
        var second = scene.Product("Second");

        Ids(await scene.HomeAsync(), "just_in").Should().BeEquivalentTo([first.Id, second.Id]);

        var post = scene.Test.Db.Posts.Single(p => p.Id == first.Id);
        post.Status = MarketplacePostStatus.Paused;
        scene.Test.Db.SaveChanges();
        scene.Product("Third, after the ranking was kept");

        Ids(await scene.HomeAsync(), "just_in").Should().Equal(
            [second.Id], "the kept ranking is checked against what is on show; new posts join when it is next worked out");
    }

    [Fact]
    public async Task Home_Leaves_Out_A_Switched_Off_Row()
    {
        using var scene = new Scene();
        scene.Product();
        scene.Test.Db.HomeSections.Single(s => s.Code == "just_in").IsActive = false;
        scene.Test.Db.SaveChanges();

        var home = await scene.HomeAsync();

        home.Sections.Select(s => s.Code).Should().Equal("more_to_explore", "all");
    }

    [Fact]
    public async Task Feed_Has_Products_Lots_And_Local_Food_But_No_Adverts()
    {
        using var scene = new Scene();
        var saree = scene.Product();
        var lot = scene.Lot();
        var biryani = scene.Food("Veg biryani");
        scene.Ad();
        var elsewhere = LocationSeedData.DistrictId("Tamil Nadu", "Tirunelveli");

        (await scene.SearchAsync(q => q.Feed = true)).Items.Select(c => c.Id)
            .Should().BeEquivalentTo([saree.Id, lot.Id, biryani.Id]);
        (await scene.SearchAsync(q =>
            {
                q.Feed = true;
                q.DistrictIds = [elsewhere];
            })).Items.Select(c => c.Id)
            .Should().BeEquivalentTo([saree.Id, lot.Id], "food is local; products and lots ship");
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
        Section(await scene.HomeAsync(), "just_in").Items.Single().IsFavourite.Should().BeTrue();
        (await scene.DetailAsync(saree.Id)).Card.IsFavourite.Should().BeTrue();

        scene.Test.As(Customer);
        await scene.Browse.Handle(new RemoveFavouriteCommand { PostId = saree.Id }, CancellationToken.None);
        await scene.Browse.Handle(new RemoveFavouriteCommand { PostId = saree.Id }, CancellationToken.None);

        (await scene.WishlistAsync()).Items.Should().BeEmpty();
        Section(await scene.HomeAsync(), "just_in").Items.Single().IsFavourite.Should().BeFalse();
    }

    [Fact]
    public async Task Wishlist_Is_Each_Customers_Own()
    {
        using var scene = new Scene();
        var saree = scene.Product();

        await scene.SaveAsync(saree.Id);

        (await scene.WishlistAsync(OtherCustomer)).Items.Should().BeEmpty();
        scene.Test.As(OtherCustomer);
        Section(await scene.Home.Handle(new GetMarketplaceHomeQuery(), CancellationToken.None), "just_in").Items.Single().IsFavourite.Should().BeFalse();
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
