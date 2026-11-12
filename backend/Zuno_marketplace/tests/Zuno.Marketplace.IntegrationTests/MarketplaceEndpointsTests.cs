using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using FluentAssertions;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.IntegrationTests;

public class MarketplaceEndpointsTests(MarketplaceApiFactory factory) : IClassFixture<MarketplaceApiFactory>
{
    private const string Posts = "/api/v1/business/marketplace";
    private static readonly Guid Products = MarketplaceCatalogSeedData.Products;
    private static readonly Guid Vehicles = MarketplaceCatalogSeedData.Vehicles;
    private static readonly Guid NearbyFood = MarketplaceCatalogSeedData.NearbyFood;
    private static readonly Guid BiryaniMeals = MarketplaceCatalogSeedData.SubId(5, 1);

    private static readonly byte[] Png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, .. new byte[64]];

    private static string Kanyakumari => Zuno.Marketplace.Infrastructure.Persistence.Seed.LocationSeedData
        .DistrictId("Tamil Nadu", "Kanyakumari").ToString();

    private static object Car(decimal price = 420000) => new
    {
        categoryId = Products,
        subCategoryId = Vehicles,
        title = "Swift VXi 2019",
        price,
        districtId = Kanyakumari,
        attributes = new Dictionary<string, string> { ["brand"] = "Maruti", ["model_year"] = "2019", ["km_driven"] = "48000", ["fuel"] = "Petrol" },
    };

    private static object Biryani() => new
    {
        categoryId = NearbyFood,
        subCategoryId = BiryaniMeals,
        title = "Veg biryani",
        price = 99,
        originalPrice = 180,
        quantity = 20,
        startsAt = DateTimeOffset.UtcNow,
        endsAt = DateTimeOffset.UtcNow.AddHours(2),
        districtId = Kanyakumari,
        attributes = new Dictionary<string, string> { ["food_type"] = "Veg" },
    };

    [Fact]
    public async Task Health_IsPublic() =>
        (await factory.CreateClient().GetAsync("/health")).StatusCode.Should().Be(HttpStatusCode.OK);

    [Fact]
    public async Task Everything_WithoutAValidToken_Is401()
    {
        (await factory.CreateClient().GetAsync("/api/v1/marketplace-categories")).StatusCode.Should().Be(HttpStatusCode.Unauthorized);

        foreach (var token in new[]
        {
            MarketplaceApiFactory.Token(Guid.NewGuid(), "BusinessOwner", TimeSpan.FromMinutes(-1)),
            MarketplaceApiFactory.Token(Guid.NewGuid(), "BusinessOwner", key: new string('x', 32)),
        })
        {
            var client = factory.CreateClient();
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
            (await client.GetAsync(Posts)).StatusCode.Should().Be(HttpStatusCode.Unauthorized);
        }
    }

    [Fact]
    public async Task BusinessEndpoints_ForACustomer_Are403()
    {
        var customer = factory.ClientFor(Guid.NewGuid(), "Customer");

        (await customer.GetAsync(Posts)).StatusCode.Should().Be(HttpStatusCode.Forbidden);
        (await customer.PostAsJsonAsync(Posts, Car())).StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task AdminEndpoints_ForABusiness_Are403_AndOpenForTheSuperAdmin()
    {
        var business = factory.ClientFor(Guid.NewGuid());
        var admin = factory.ClientFor(Guid.NewGuid(), "SuperAdmin");
        var category = new { name = $"Mobiles {Guid.NewGuid():N}", kind = "Listing", displayOrder = 7 };

        (await business.PostAsJsonAsync("/api/v1/admin/marketplace/categories", category)).StatusCode.Should().Be(HttpStatusCode.Forbidden);
        var created = await admin.PostAsJsonAsync("/api/v1/admin/marketplace/categories", category);

        created.StatusCode.Should().Be(HttpStatusCode.Created);
        var id = (await Data(created)).GetProperty("id").GetString();
        var field = await admin.PostAsJsonAsync(
            $"/api/v1/admin/marketplace/categories/{id}/fields", new { label = "Brand", fieldType = "Text", isRequired = true });
        field.StatusCode.Should().Be(HttpStatusCode.Created);
        var categories = await Data(await business.GetAsync("/api/v1/marketplace-categories"));
        categories.EnumerateArray().Should().Contain(c => c.GetProperty("id").GetString() == id);
    }

    [Fact]
    public async Task CategoriesAndOptions_ComeFromTheSeededTables()
    {
        var client = factory.ClientFor(Guid.NewGuid());

        var categories = await Data(await client.GetAsync("/api/v1/marketplace-categories"));
        var options = await Data(await client.GetAsync("/api/v1/marketplace-options"));

        categories.EnumerateArray().Select(c => c.GetProperty("slug").GetString())
            .Should().StartWith(["products", "b2b-wholesale", "nearby-food", "advertisements"]);
        options.GetProperty("imageSlots").GetInt32().Should().Be(5);
        options.GetProperty("statuses").EnumerateArray().Select(s => s.GetProperty("code").GetString())
            .Should().Equal("Active", "Paused", "Expired", "Closed");
    }

    [Fact]
    public async Task FreePlan_OneLivePost_ThenPauseFreesTheSlot()
    {
        var client = factory.ClientFor(Guid.NewGuid());

        var car = await client.PostAsJsonAsync(Posts, Car());
        car.StatusCode.Should().Be(HttpStatusCode.Created);
        var carId = (await Data(car)).GetProperty("id").GetString();

        var second = await client.PostAsJsonAsync(Posts, Biryani());
        second.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (await Body(second)).GetProperty("message").GetString().Should().StartWith("Your Free plan allows 1 active post.");

        (await client.PatchAsJsonAsync($"{Posts}/{carId}/status", new { status = "Paused" })).StatusCode.Should().Be(HttpStatusCode.OK);
        (await client.PostAsJsonAsync(Posts, Biryani())).StatusCode.Should().Be(HttpStatusCode.Created);

        var summary = await Data(await client.GetAsync($"{Posts}/summary"));
        summary.GetProperty("active").GetInt32().Should().Be(1);
        summary.GetProperty("paused").GetInt32().Should().Be(1);
        summary.GetProperty("plan").GetProperty("canAddActivePost").GetBoolean().Should().BeFalse();
    }

    [Fact]
    public async Task ConcurrentCreates_OnlyOneWinsTheFreeSlot()
    {
        var client = factory.ClientFor(Guid.NewGuid());

        var results = await Task.WhenAll(Enumerable.Range(0, 5).Select(_ => client.PostAsJsonAsync(Posts, Car())));

        results.Count(r => r.StatusCode == HttpStatusCode.Created).Should().Be(1);
        results.Count(r => r.StatusCode == HttpStatusCode.BadRequest).Should().Be(4);
    }

    [Fact]
    public async Task Create_WithMissingDetail_Is400NamingTheField()
    {
        var client = factory.ClientFor(Guid.NewGuid());
        var car = new
        {
            categoryId = Products,
            subCategoryId = Vehicles,
            title = "Swift",
            price = 1,
            districtId = Kanyakumari,
            attributes = new Dictionary<string, string> { ["brand"] = "Maruti" },
        };

        var response = await client.PostAsJsonAsync(Posts, car);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (await Body(response)).GetProperty("errors").TryGetProperty("Attributes.km_driven", out _).Should().BeTrue();
    }

    [Fact]
    public async Task AnotherBusinessesPost_Is403()
    {
        var owner = factory.ClientFor(Guid.NewGuid());
        var id = (await Data(await owner.PostAsJsonAsync(Posts, Car()))).GetProperty("id").GetString();
        var other = factory.ClientFor(Guid.NewGuid());

        (await other.PutAsJsonAsync($"{Posts}/{id}", Car(1))).StatusCode.Should().Be(HttpStatusCode.Forbidden);
        (await other.DeleteAsync($"{Posts}/{id}")).StatusCode.Should().Be(HttpStatusCode.Forbidden);
        (await other.PatchAsJsonAsync($"{Posts}/{id}/status", new { status = "Closed" })).StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Delete_PostWithDetails_IsGoneFromTheListAndFreesTheSlot()
    {
        var client = factory.ClientFor(Guid.NewGuid());
        var id = (await Data(await client.PostAsJsonAsync(Posts, Car()))).GetProperty("id").GetString();

        var deleted = await client.DeleteAsync($"{Posts}/{id}");

        deleted.StatusCode.Should().Be(HttpStatusCode.NoContent);
        (await Data(await client.GetAsync(Posts))).GetProperty("totalCount").GetInt32().Should().Be(0);
        (await client.PostAsJsonAsync(Posts, Car())).StatusCode.Should().Be(HttpStatusCode.Created);
    }

    [Fact]
    public async Task Update_ChangesTheDetailsStoredAsJson()
    {
        var client = factory.ClientFor(Guid.NewGuid());
        var id = (await Data(await client.PostAsJsonAsync(Posts, Car()))).GetProperty("id").GetString();
        var changed = new
        {
            categoryId = Products,
            subCategoryId = Vehicles,
            title = "Swift VXi 2019",
            price = 400000,
            districtId = Kanyakumari,
            attributes = new Dictionary<string, string> { ["brand"] = "Maruti", ["model_year"] = "2019", ["km_driven"] = "50000", ["fuel"] = "Diesel" },
        };

        var updated = await Data(await client.PutAsJsonAsync($"{Posts}/{id}", changed));

        updated.GetProperty("attributes").GetProperty("km_driven").GetString().Should().Be("50000");
        updated.GetProperty("attributes").GetProperty("fuel").GetString().Should().Be("Diesel");
    }

    [Fact]
    public async Task MissingPost_Is404()
    {
        var client = factory.ClientFor(Guid.NewGuid());

        (await client.DeleteAsync($"{Posts}/{Guid.NewGuid()}")).StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Photo_RealImageSaved_FakeImageRefused_AndServed()
    {
        var client = factory.ClientFor(Guid.NewGuid());
        var id = (await Data(await client.PostAsJsonAsync(Posts, Car()))).GetProperty("id").GetString();

        var saved = await client.PostAsync($"{Posts}/{id}/images/0", File(Png, "image/png"));
        var fake = await client.PostAsync($"{Posts}/{id}/images/1", File("<script>alert(1)</script>"u8.ToArray(), "image/png"));
        var outOfRange = await client.PostAsync($"{Posts}/{id}/images/9", File(Png, "image/png"));

        saved.StatusCode.Should().Be(HttpStatusCode.OK);
        var url = (await Data(saved)).GetProperty("media")[0].GetProperty("url").GetString();
        url.Should().MatchRegex($"^/uploads/marketplace/{id}/image-0-[a-f0-9]{{12}}\\.png$");
        fake.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        outOfRange.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (await factory.CreateClient().GetAsync(url)).StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task List_FiltersAndPages()
    {
        var client = factory.ClientFor(Guid.NewGuid());
        await client.PostAsJsonAsync(Posts, Car());

        var listings = await Data(await client.GetAsync($"{Posts}?kind=Listing&pageSize=500"));
        var food = await Data(await client.GetAsync($"{Posts}?kind=FoodOffer"));
        var bad = await client.GetAsync($"{Posts}?status=Gone");

        listings.GetProperty("totalCount").GetInt32().Should().Be(1);
        listings.GetProperty("pageSize").GetInt32().Should().Be(100);
        food.GetProperty("items").GetArrayLength().Should().Be(0);
        bad.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task ProfileSync_StoresTheVerifiedBusiness()
    {
        var client = factory.ClientFor(Guid.NewGuid());

        var data = await Data(await client.PostAsync($"{Posts}/profile/sync", null));

        data.GetProperty("isVerified").GetBoolean().Should().BeTrue();
        data.GetProperty("name").GetString().Should().Be("Test Shop");
    }

    private static MultipartFormDataContent File(byte[] bytes, string contentType)
    {
        var file = new ByteArrayContent(bytes);
        file.Headers.ContentType = new MediaTypeHeaderValue(contentType);
        return new MultipartFormDataContent { { file, "file", "photo.png" } };
    }

    private static async Task<JsonElement> Body(HttpResponseMessage response) =>
        await response.Content.ReadFromJsonAsync<JsonElement>();

    private static async Task<JsonElement> Data(HttpResponseMessage response) =>
        (await Body(response)).GetProperty("data");
}
