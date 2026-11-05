using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using FluentAssertions;

namespace Zuno.Rent.IntegrationTests;

public class RentEndpointsTests(RentApiFactory factory) : IClassFixture<RentApiFactory>
{
    private const string Items = "/api/v1/business/rentals";
    private const string ToolsMachines = "b2222222-0000-0000-0000-000000000006";
    private const string CuttingMachine = "c3333333-0000-0000-0006-000000000001";
    private const string Ernakulam = "106ed900-3319-e16c-796b-a3a11ea1a1e9";

    private static readonly byte[] Png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, .. new byte[64]];
    private static readonly byte[] Mp4 = [0, 0, 0, 0x18, .. "ftypmp42"u8.ToArray(), .. new byte[64]];

    private static object Machine(string priceType = "Daily", decimal price = 500, int quantity = 1, bool available = true) => new
    {
        rentalCategoryId = ToolsMachines,
        rentalSubCategoryId = CuttingMachine,
        name = "Cutting machine",
        priceType,
        price,
        quantityOwned = quantity,
        isAvailable = available,
        districtIds = new[] { Ernakulam },
    };

    [Fact]
    public async Task Health_is_public()
    {
        (await factory.CreateClient().GetAsync("/health")).StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Rent_reputation_is_public_for_the_Service_API()
    {
        var response = await factory.CreateClient().GetAsync("/api/v1/rentals/reputation");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        (await Data(response)).GetProperty("items").ValueKind.Should().Be(JsonValueKind.Array);
    }

    [Fact]
    public async Task Without_a_valid_token_everything_is_401()
    {
        var anonymous = factory.CreateClient();
        (await anonymous.GetAsync("/api/v1/rental-categories")).StatusCode.Should().Be(HttpStatusCode.Unauthorized);

        foreach (var token in new[]
        {
            RentApiFactory.Token(Guid.NewGuid(), "BusinessOwner", TimeSpan.FromMinutes(-1)),
            RentApiFactory.Token(Guid.NewGuid(), "BusinessOwner", key: new string('x', 32)),
        })
        {
            var client = factory.CreateClient();
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
            (await client.GetAsync(Items)).StatusCode.Should().Be(HttpStatusCode.Unauthorized);
        }
    }

    [Theory]
    [InlineData("Customer")]
    [InlineData("Worker")]
    public async Task Only_a_business_can_manage_rent_items(string role)
    {
        var client = factory.ClientFor(Guid.NewGuid(), role);

        (await client.GetAsync(Items)).StatusCode.Should().Be(HttpStatusCode.Forbidden);
        (await client.PostAsJsonAsync(Items, Machine())).StatusCode.Should().Be(HttpStatusCode.Forbidden);
        (await client.GetAsync("/api/v1/rental-categories")).StatusCode.Should().Be(HttpStatusCode.OK, "the catalogue is for every signed-in user");
    }

    [Fact]
    public async Task Categories_are_seeded_with_sub_categories()
    {
        var data = await Data(await factory.ClientFor(Guid.NewGuid()).GetAsync("/api/v1/rental-categories"));

        data.GetArrayLength().Should().Be(7);
        data.EnumerateArray().Single(c => c.GetProperty("name").GetString() == "Tools & machines")
            .GetProperty("subCategories").EnumerateArray().Select(s => s.GetProperty("name").GetString())
            .Should().Contain("Cutting machine");
    }

    [Fact]
    public async Task Rate_types_are_seeded_per_day_per_item_per_hour()
    {
        var data = await Data(await factory.ClientFor(Guid.NewGuid()).GetAsync("/api/v1/rental-price-types"));

        data.EnumerateArray().Select(t => t.GetProperty("name").GetString())
            .Should().Equal("Per day", "Per item", "Per hour");
        (await factory.CreateClient().GetAsync("/api/v1/rental-price-types")).StatusCode
            .Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task The_summary_counts_only_the_callers_items_and_the_list_filters()
    {
        var owner = factory.ClientFor(Guid.NewGuid());
        await owner.PostAsJsonAsync(Items, Machine(quantity: 3));
        await owner.PostAsJsonAsync(Items, Machine(available: false));
        await factory.ClientFor(Guid.NewGuid()).PostAsJsonAsync(Items, Machine(quantity: 50));

        var summary = await Data(await owner.GetAsync($"{Items}/summary"));

        summary.GetProperty("totalItems").GetInt32().Should().Be(2);
        summary.GetProperty("availableItems").GetInt32().Should().Be(1);
        summary.GetProperty("unavailableItems").GetInt32().Should().Be(1);
        summary.GetProperty("unitsAvailable").GetInt64().Should().Be(3);
        (await Data(await owner.GetAsync($"{Items}?isAvailable=false"))).GetProperty("totalCount").GetInt32().Should().Be(1);

        var customer = factory.CreateClient();
        customer.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", RentApiFactory.Token(Guid.NewGuid(), "Customer"));
        (await customer.GetAsync($"{Items}/summary")).StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Stock_is_changed_in_one_call_and_checked()
    {
        var owner = factory.ClientFor(Guid.NewGuid());
        var id = (await Data(await owner.PostAsJsonAsync(Items, Machine(quantity: 1000)))).GetProperty("id").GetString();

        var updated = await Data(await owner.PatchAsJsonAsync($"{Items}/{id}/stock", new { quantityOwned = 1050, isAvailable = false }));
        updated.GetProperty("quantityOwned").GetInt32().Should().Be(1050);
        updated.GetProperty("isAvailable").GetBoolean().Should().BeFalse();

        (await owner.PatchAsJsonAsync($"{Items}/{id}/stock", new { quantityOwned = 0, isAvailable = true }))
            .StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (await factory.ClientFor(Guid.NewGuid()).PatchAsJsonAsync($"{Items}/{id}/stock", new { quantityOwned = 1, isAvailable = true }))
            .StatusCode.Should().Be(HttpStatusCode.Forbidden);

        var customer = factory.CreateClient();
        customer.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", RentApiFactory.Token(Guid.NewGuid(), "Customer"));
        (await customer.PatchAsJsonAsync($"{Items}/{id}/stock", new { quantityOwned = 1, isAvailable = true }))
            .StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Stock_and_orders_are_served_to_the_owner_only()
    {
        var owner = factory.ClientFor(Guid.NewGuid());
        var id = (await Data(await owner.PostAsJsonAsync(Items, Machine(quantity: 1000)))).GetProperty("id").GetString();

        var stock = (await Data(await owner.GetAsync($"{Items}/stock"))).GetProperty("items")[0];
        stock.GetProperty("quantityTotal").GetInt32().Should().Be(1000);
        stock.GetProperty("quantityIn").GetInt32().Should().Be(1000);
        stock.GetProperty("quantityOut").GetInt32().Should().Be(0);

        (await Data(await owner.GetAsync($"{Items}/{id}/orders"))).GetProperty("totalCount").GetInt32().Should().Be(0);
        (await factory.ClientFor(Guid.NewGuid()).GetAsync($"{Items}/{id}/orders"))
            .StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Rent_orders_endpoints_are_owner_only_and_answer_empty()
    {
        var owner = factory.ClientFor(Guid.NewGuid());

        (await Data(await owner.GetAsync("/api/v1/business/rental-orders"))).GetProperty("totalCount").GetInt32().Should().Be(0);
        (await Data(await owner.GetAsync("/api/v1/business/rental-orders/counts"))).GetArrayLength().Should().Be(5);
        (await Data(await owner.GetAsync("/api/v1/business/rental-orders/threads"))).GetArrayLength().Should().Be(0);
        (await owner.GetAsync($"/api/v1/business/rental-orders/{Guid.NewGuid()}")).StatusCode.Should().Be(HttpStatusCode.NotFound);
        (await owner.PostAsJsonAsync($"/api/v1/business/rental-orders/{Guid.NewGuid()}/status", new { toStatus = "Lost" }))
            .StatusCode.Should().Be(HttpStatusCode.BadRequest);

        var customer = factory.CreateClient();
        customer.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", RentApiFactory.Token(Guid.NewGuid(), "Customer"));
        (await customer.GetAsync("/api/v1/business/rental-orders")).StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Questions_are_saved_with_the_item_and_come_back_in_order()
    {
        var owner = factory.ClientFor(Guid.NewGuid());

        var created = await Data(await owner.PostAsJsonAsync(Items, new
        {
            rentalCategoryId = ToolsMachines,
            name = "Plastic chair",
            priceType = "Fixed",
            price = 12,
            quantityOwned = 1000,
            districtIds = new[] { Ernakulam },
            questions = new[]
            {
                new { prompt = "Event date and venue", isRequired = true },
                new { prompt = "Delivery needed?", isRequired = false },
            },
        }));

        created.GetProperty("quantityOwned").GetInt32().Should().Be(1000);
        created.GetProperty("questions").EnumerateArray()
            .Select(q => (q.GetProperty("prompt").GetString(), q.GetProperty("isRequired").GetBoolean()))
            .Should().Equal(("Event date and venue", true), ("Delivery needed?", false));

        var listed = (await Data(await owner.GetAsync(Items))).GetProperty("items")[0];
        listed.GetProperty("questions").GetArrayLength().Should().Be(2);
    }

    [Fact]
    public async Task A_business_adds_edits_lists_and_removes_its_items()
    {
        var owner = factory.ClientFor(Guid.NewGuid());

        var created = await owner.PostAsJsonAsync(Items, Machine());
        created.StatusCode.Should().Be(HttpStatusCode.Created);
        var item = await Data(created);
        var id = item.GetProperty("id").GetString();
        item.GetProperty("districts")[0].GetProperty("name").GetString().Should().Be("Ernakulam");

        var edited = await Data(await owner.PutAsJsonAsync($"{Items}/{id}", Machine("Hourly", 90, 2, available: false)));
        edited.GetProperty("priceType").GetString().Should().Be("Hourly");
        edited.GetProperty("quantityOwned").GetInt32().Should().Be(2);
        edited.GetProperty("isAvailable").GetBoolean().Should().BeFalse();

        var list = await Data(await owner.GetAsync(Items));
        list.GetProperty("totalCount").GetInt32().Should().Be(1);

        (await owner.DeleteAsync($"{Items}/{id}")).StatusCode.Should().Be(HttpStatusCode.NoContent);
        (await Data(await owner.GetAsync(Items))).GetProperty("totalCount").GetInt32().Should().Be(0);
        (await owner.PutAsJsonAsync($"{Items}/{id}", Machine())).StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Bad_fields_come_back_as_400_naming_the_field()
    {
        var owner = factory.ClientFor(Guid.NewGuid());

        var response = await owner.PostAsJsonAsync(Items, Machine("PerPerson", 0, 0));

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        var errors = JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement.GetProperty("errors");
        errors.EnumerateObject().Select(e => e.Name).Should().Contain(["PriceType", "Price", "QuantityOwned"]);
    }

    [Fact]
    public async Task Another_business_gets_403_and_never_its_items()
    {
        var owner = factory.ClientFor(Guid.NewGuid());
        var other = factory.ClientFor(Guid.NewGuid());
        var id = (await Data(await owner.PostAsJsonAsync(Items, Machine()))).GetProperty("id").GetString();

        (await other.PutAsJsonAsync($"{Items}/{id}", Machine())).StatusCode.Should().Be(HttpStatusCode.Forbidden);
        (await other.DeleteAsync($"{Items}/{id}")).StatusCode.Should().Be(HttpStatusCode.Forbidden);
        (await other.PostAsync($"{Items}/{id}/images/0", File(Png, "image/png"))).StatusCode.Should().Be(HttpStatusCode.Forbidden);
        (await Data(await other.GetAsync(Items))).GetProperty("totalCount").GetInt32().Should().Be(0);
    }

    [Fact]
    public async Task Photos_and_video_are_checked_by_their_bytes_and_served()
    {
        var owner = factory.ClientFor(Guid.NewGuid());
        var id = (await Data(await owner.PostAsJsonAsync(Items, Machine()))).GetProperty("id").GetString();

        var photo = await owner.PostAsync($"{Items}/{id}/images/0", File(Png, "image/png"));
        photo.StatusCode.Should().Be(HttpStatusCode.OK);
        var url = (await Data(photo)).GetProperty("media")[0].GetProperty("url").GetString()!;
        url.Should().MatchRegex(@"^/uploads/rentals/[0-9a-f-]{36}/image-0-[0-9a-f]{12}\.png$");
        (await factory.CreateClient().GetAsync(url)).StatusCode.Should().Be(HttpStatusCode.OK);

        (await owner.PostAsync($"{Items}/{id}/images/3", File(Png, "image/png"))).StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (await owner.PostAsync($"{Items}/{id}/images/1", File("<html></html>"u8.ToArray(), "image/png"))).StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (await owner.PostAsync($"{Items}/{id}/images/1", File([.. Png, .. new byte[5 * 1024 * 1024]], "image/png"))).StatusCode.Should().Be(HttpStatusCode.BadRequest);

        var video = await owner.PostAsync($"{Items}/{id}/video", File(Mp4, "video/mp4"));
        video.StatusCode.Should().Be(HttpStatusCode.OK);
        (await Data(video)).GetProperty("media").EnumerateArray().Select(m => m.GetProperty("mediaType").GetString()).Should().Equal("Image", "Video");
        (await owner.PostAsync($"{Items}/{id}/video", File(Png, "video/mp4"))).StatusCode.Should().Be(HttpStatusCode.BadRequest);

        var removed = await Data(await owner.DeleteAsync($"{Items}/{id}/images/0"));
        removed.GetProperty("media").EnumerateArray().Should().ContainSingle();
        (await factory.CreateClient().GetAsync(url)).StatusCode.Should().NotBe(HttpStatusCode.OK, "the file is deleted");
    }

    private static MultipartFormDataContent File(byte[] bytes, string contentType)
    {
        var file = new ByteArrayContent(bytes);
        file.Headers.ContentType = new MediaTypeHeaderValue(contentType);
        return new MultipartFormDataContent { { file, "file", "upload.bin" } };
    }

    private static async Task<JsonElement> Data(HttpResponseMessage response)
    {
        var body = await response.Content.ReadAsStringAsync();
        response.IsSuccessStatusCode.Should().BeTrue(body);
        return JsonDocument.Parse(body).RootElement.GetProperty("data").Clone();
    }
}
