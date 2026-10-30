using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using FluentAssertions;
using Microsoft.Extensions.DependencyInjection;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;
using Zuno.Rent.Infrastructure.Persistence;

namespace Zuno.Rent.IntegrationTests;

/// <summary>
/// A rent order through real Postgres: listed with its steps, sent out and returned with stock
/// following, and a customer message read and answered. Orders and the customer's message are
/// written straight to the database, as customer ordering arrives in step 2.
/// </summary>
public class RentalOrderFlowTests(RentApiFactory factory) : IClassFixture<RentApiFactory>
{
    private const string Orders = "/api/v1/business/rental-orders";

    private static async Task<JsonElement> Data(HttpResponseMessage response)
    {
        response.IsSuccessStatusCode.Should().BeTrue(await response.Content.ReadAsStringAsync());
        return (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("data");
    }

    [Fact]
    public async Task Booked_order_is_sent_out_returned_and_talked_about()
    {
        var ownerId = Guid.NewGuid();
        var owner = factory.ClientFor(ownerId);
        var item = await Data(await owner.PostAsJsonAsync("/api/v1/business/rentals", new
        {
            rentalCategoryId = "b2222222-0000-0000-0000-000000000001",
            name = "Plastic chair",
            priceType = "Daily",
            price = 12,
            quantityOwned = 1000,
            districtIds = new[] { "106ed900-3319-e16c-796b-a3a11ea1a1e9" },
        }));
        var itemId = Guid.Parse(item.GetProperty("id").GetString()!);

        var orderId = Guid.NewGuid();
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<RentDbContext>();
            db.RentalOrders.Add(new RentalOrder
            {
                Id = orderId,
                RentalItemId = itemId,
                OwnerUserId = ownerId,
                CustomerUserId = Guid.NewGuid(),
                CustomerName = "Rahul",
                Quantity = 300,
                StartDate = DateTimeOffset.UtcNow,
                EndDate = DateTimeOffset.UtcNow.AddDays(2),
                DeliveryAddress = "St. Mary's Hall, Kakkanad",
                Status = RentalOrderStatus.Booked,
            });
            db.RentalOrderMessages.Add(new RentalOrderMessage
            {
                RentalOrderId = orderId,
                SenderUserId = Guid.NewGuid(),
                SenderRole = RentalMessageSenderRole.Customer,
                Body = "Can you deliver by 9 am?",
            });
            await db.SaveChangesAsync();
        }

        var listed = (await Data(await owner.GetAsync(Orders))).GetProperty("items")[0];
        listed.GetProperty("itemName").GetString().Should().Be("Plastic chair");
        listed.GetProperty("unreadMessages").GetInt32().Should().Be(1);
        listed.GetProperty("actions")[0].GetProperty("label").GetString().Should().Be("Send out");

        var stock = (await Data(await owner.GetAsync("/api/v1/business/rentals/stock"))).GetProperty("items")[0];
        stock.GetProperty("quantityBooked").GetInt32().Should().Be(300);

        var sent = await Data(await owner.PostAsJsonAsync($"{Orders}/{orderId}/status", new { toStatus = "OnRent" }));
        sent.GetProperty("statusName").GetString().Should().Be("On rent");
        stock = (await Data(await owner.GetAsync("/api/v1/business/rentals/stock"))).GetProperty("items")[0];
        stock.GetProperty("quantityOut").GetInt32().Should().Be(300);
        stock.GetProperty("quantityIn").GetInt32().Should().Be(700);

        (await owner.PostAsJsonAsync($"{Orders}/{orderId}/status", new { toStatus = "Booked" }))
            .StatusCode.Should().Be(HttpStatusCode.BadRequest, "On rent cannot go back to Booked");
        await Data(await owner.PostAsJsonAsync($"{Orders}/{orderId}/status", new { toStatus = "Returned" }));

        var threads = await Data(await owner.GetAsync($"{Orders}/threads"));
        threads[0].GetProperty("unreadCount").GetInt32().Should().Be(1);

        var messages = await Data(await owner.GetAsync($"{Orders}/{orderId}/messages"));
        messages[0].GetProperty("senderName").GetString().Should().Be("Rahul");
        (await Data(await owner.PostAsJsonAsync($"{Orders}/{orderId}/messages", new { body = "Yes, 8:30." })))
            .GetProperty("isMine").GetBoolean().Should().BeTrue();

        threads = await Data(await owner.GetAsync($"{Orders}/threads"));
        threads[0].GetProperty("unreadCount").GetInt32().Should().Be(0);
        threads[0].GetProperty("lastMessage").GetString().Should().Be("Yes, 8:30.");

        var counts = await Data(await owner.GetAsync($"{Orders}/counts"));
        counts.EnumerateArray().Single(c => c.GetProperty("status").GetString() == "Returned")
            .GetProperty("count").GetInt32().Should().Be(1);

        (await factory.ClientFor(Guid.NewGuid()).GetAsync($"{Orders}/{orderId}/messages"))
            .StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }
}
