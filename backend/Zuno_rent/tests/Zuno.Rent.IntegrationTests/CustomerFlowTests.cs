using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using FluentAssertions;

namespace Zuno.Rent.IntegrationTests;

/// <summary>
/// The customer side on real Postgres: a verified business lists chairs, a customer finds them, books,
/// the business sees the app order and sends it out, they talk — and each side is kept to its routes.
/// </summary>
public class CustomerFlowTests(RentApiFactory factory) : IClassFixture<RentApiFactory>
{
    private static readonly DateTimeOffset Start = DateTimeOffset.UtcNow.Date.AddDays(20);
    private static readonly DateTimeOffset End = Start.AddDays(2);

    private static async Task<JsonElement> Data(HttpResponseMessage response)
    {
        response.IsSuccessStatusCode.Should().BeTrue(await response.Content.ReadAsStringAsync());
        return (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("data");
    }

    private async Task<(HttpClient Business, string ItemId)> ListedChairsAsync(int quantity)
    {
        var business = factory.ClientFor(Guid.NewGuid());
        await Data(await business.PostAsync("/api/v1/business/rentals/profile/sync", null));
        var item = await Data(await business.PostAsJsonAsync("/api/v1/business/rentals", new
        {
            rentalCategoryId = "b2222222-0000-0000-0000-000000000001",
            name = $"Plastic chair {Guid.NewGuid():N}",
            priceType = "Daily",
            price = 12,
            quantityOwned = quantity,
            districtIds = new[] { "106ed900-3319-e16c-796b-a3a11ea1a1e9" },
        }));
        return (business, item.GetProperty("id").GetString()!);
    }

    private static object Booking(string itemId, int quantity) => new
    {
        rentalItemId = itemId,
        quantity,
        startDate = Start,
        endDate = End,
        deliveryAddress = "Kakkanad",
        districtId = "106ed900-3319-e16c-796b-a3a11ea1a1e9",
    };

    [Fact]
    public async Task A_customer_finds_books_and_talks_and_the_business_sends_it_out()
    {
        var (business, itemId) = await ListedChairsAsync(1000);
        var customer = factory.ClientFor(Guid.NewGuid(), "Customer");

        var home = await Data(await customer.GetAsync("/api/v1/rentals/home?seed=7"));
        home.GetArrayLength().Should().BeGreaterThan(0);
        var detail = await Data(await customer.GetAsync($"/api/v1/rentals/{itemId}"));
        detail.GetProperty("card").GetProperty("businessName").GetString().Should().Be("Test Rentals");

        var order = await Data(await customer.PostAsJsonAsync("/api/v1/customer/rental-orders", Booking(itemId, 300)));
        var orderId = order.GetProperty("id").GetString();
        order.GetProperty("customerName").GetString().Should().Be("Test Customer");

        var refused = await customer.PostAsJsonAsync("/api/v1/customer/rental-orders", Booking(itemId, 800));
        refused.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (await refused.Content.ReadAsStringAsync()).Should().Contain("Only 700");

        await Data(await customer.PostAsJsonAsync($"/api/v1/customer/rental-orders/{orderId}/messages", new { body = "Deliver by 9?" }));

        var seen = await Data(await business.GetAsync($"/api/v1/business/rental-orders/{orderId}"));
        seen.GetProperty("source").GetString().Should().Be("App");
        seen.GetProperty("unreadMessages").GetInt32().Should().Be(1);
        await Data(await business.PostAsJsonAsync($"/api/v1/business/rental-orders/{orderId}/status", new { toStatus = "OnRent" }));

        var mine = await Data(await customer.GetAsync($"/api/v1/customer/rental-orders/{orderId}"));
        mine.GetProperty("statusName").GetString().Should().Be("On rent");
        mine.GetProperty("actions").GetArrayLength().Should().Be(0, "the customer cannot cancel once it is out");
        var history = await Data(await customer.GetAsync($"/api/v1/customer/rental-orders/{orderId}/history"));
        history.EnumerateArray().Select(h => h.GetProperty("title").GetString()).Should().Equal("Booked by customer", "On rent");
    }

    [Fact]
    public async Task Each_side_is_kept_to_its_own_routes()
    {
        var business = factory.ClientFor(Guid.NewGuid());
        var customer = factory.ClientFor(Guid.NewGuid(), "Customer");

        (await business.GetAsync("/api/v1/rentals/home?seed=1")).StatusCode.Should().Be(HttpStatusCode.Forbidden);
        (await business.GetAsync("/api/v1/customer/rental-orders")).StatusCode.Should().Be(HttpStatusCode.Forbidden);
        (await customer.GetAsync("/api/v1/business/rental-orders")).StatusCode.Should().Be(HttpStatusCode.Forbidden);
        (await customer.GetAsync("/api/v1/business/rentals")).StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Two_customers_for_the_last_pieces_at_once_only_one_wins()
    {
        var (_, itemId) = await ListedChairsAsync(1000);
        var first = factory.ClientFor(Guid.NewGuid(), "Customer");
        var second = factory.ClientFor(Guid.NewGuid(), "Customer");

        var results = await Task.WhenAll(
            first.PostAsJsonAsync("/api/v1/customer/rental-orders", Booking(itemId, 600)),
            second.PostAsJsonAsync("/api/v1/customer/rental-orders", Booking(itemId, 600)));

        results.Select(r => r.StatusCode).Should().BeEquivalentTo([HttpStatusCode.Created, HttpStatusCode.BadRequest]);
    }
}
