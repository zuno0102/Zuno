using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using FluentAssertions;

namespace Zuno.Rent.IntegrationTests;

/// <summary>
/// Date-based availability through real Postgres: the live check, a booking refused with what is
/// left, an add-on linked to its order — and two bookings for the last pieces arriving together,
/// where exactly one may win.
/// </summary>
public class AvailabilityFlowTests(RentApiFactory factory) : IClassFixture<RentApiFactory>
{
    private const string Orders = "/api/v1/business/rental-orders";

    private static readonly DateTimeOffset Start = DateTimeOffset.UtcNow.Date.AddDays(10);
    private static readonly DateTimeOffset End = Start.AddDays(2);

    private static async Task<JsonElement> Data(HttpResponseMessage response)
    {
        response.IsSuccessStatusCode.Should().BeTrue(await response.Content.ReadAsStringAsync());
        return (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("data");
    }

    private static async Task<(HttpClient Owner, string ItemId)> ChairsAsync(RentApiFactory factory, int quantity)
    {
        var owner = factory.ClientFor(Guid.NewGuid());
        var item = await Data(await owner.PostAsJsonAsync("/api/v1/business/rentals", new
        {
            rentalCategoryId = "b2222222-0000-0000-0000-000000000001",
            name = "Plastic chair",
            priceType = "Daily",
            price = 12,
            quantityOwned = quantity,
            districtIds = new[] { "106ed900-3319-e16c-796b-a3a11ea1a1e9" },
        }));
        return (owner, item.GetProperty("id").GetString()!);
    }

    private static object Book(string itemId, int quantity, string customer) => new
    {
        rentalItemId = itemId,
        quantity,
        startDate = Start,
        endDate = End,
        customerName = customer,
        deliveryAddress = "Kakkanad",
    };

    [Fact]
    public async Task Booked_pieces_reduce_what_is_left_and_an_add_on_links_to_its_order()
    {
        var (owner, itemId) = await ChairsAsync(factory, 2000);
        await Data(await owner.PostAsJsonAsync(Orders, Book(itemId, 1000, "A")));
        var b = await Data(await owner.PostAsJsonAsync(Orders, Book(itemId, 700, "B")));

        var availability = await Data(await owner.GetAsync(
            $"/api/v1/business/rentals/{itemId}/availability?start={Uri.EscapeDataString(Start.ToString("o"))}&end={Uri.EscapeDataString(End.ToString("o"))}"));
        availability.GetProperty("available").GetInt32().Should().Be(300);

        var refused = await owner.PostAsJsonAsync(Orders, Book(itemId, 500, "C"));
        refused.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (await refused.Content.ReadAsStringAsync()).Should().Contain("Only 300");

        var addOn = await Data(await owner.PostAsJsonAsync($"{Orders}/{b.GetProperty("id").GetString()}/add-on", new { quantity = 200 }));
        addOn.GetProperty("parentOrderId").GetString().Should().Be(b.GetProperty("id").GetString());

        var parent = await Data(await owner.GetAsync($"{Orders}/{b.GetProperty("id").GetString()}"));
        parent.GetProperty("addOns")[0].GetProperty("quantity").GetInt32().Should().Be(200);
        parent.GetProperty("canAddPieces").GetBoolean().Should().BeTrue();

        // The record: B's 700 booked, then 200 added — two entries, never one merged 900.
        var history = await Data(await owner.GetAsync($"{Orders}/{b.GetProperty("id").GetString()}/history"));
        history.EnumerateArray().Select(h => (h.GetProperty("title").GetString(), h.GetProperty("quantity").GetInt32()))
            .Should().Equal(("Booked", 700), ("Booked", 200), ("Extra pieces added", 200));
    }

    [Fact]
    public async Task Two_bookings_for_the_last_pieces_at_once_only_one_wins()
    {
        var (owner, itemId) = await ChairsAsync(factory, 1000);

        // Each alone fits; together they do not. The item's row lock makes the second wait and see the first.
        var first = owner.PostAsJsonAsync(Orders, Book(itemId, 600, "First"));
        var second = owner.PostAsJsonAsync(Orders, Book(itemId, 600, "Second"));
        var results = await Task.WhenAll(first, second);

        results.Select(r => r.StatusCode).Should().BeEquivalentTo([HttpStatusCode.Created, HttpStatusCode.BadRequest]);
        var all = await Data(await owner.GetAsync(Orders));
        all.GetProperty("totalCount").GetInt32().Should().Be(1);
    }
}
