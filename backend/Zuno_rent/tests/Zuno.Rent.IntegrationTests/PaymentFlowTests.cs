using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using FluentAssertions;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Zuno.Rent.Application.Orders;
using Zuno.Rent.Infrastructure.Persistence;

namespace Zuno.Rent.IntegrationTests;

/// <summary>
/// Money on real Postgres: an item asking ₹2 a chair, a customer paying the advance online, the
/// business taking the balance by UPI QR and only then returning the chairs; an offline order's cash
/// advance; two customers holding the last chairs; and an unpaid hold let go.
/// </summary>
public class PaymentFlowTests(RentApiFactory factory) : IClassFixture<RentApiFactory>
{
    private const string Ernakulam = "106ed900-3319-e16c-796b-a3a11ea1a1e9";
    private static readonly DateTimeOffset Start = DateTimeOffset.UtcNow.Date.AddDays(30);
    private static readonly DateTimeOffset End = Start.AddDays(2).AddMinutes(-1);

    private static async Task<JsonElement> Data(HttpResponseMessage response)
    {
        response.IsSuccessStatusCode.Should().BeTrue(await response.Content.ReadAsStringAsync());
        return (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("data");
    }

    /// <summary>A verified business listing chairs at ₹10 a day, asking the advance given.</summary>
    private async Task<(HttpClient Business, string ItemId)> ChairsAsync(int quantity, string advanceType, decimal? advance)
    {
        var business = factory.ClientFor(Guid.NewGuid());
        await Data(await business.PostAsync("/api/v1/business/rentals/profile/sync", null));
        var item = await Data(await business.PostAsJsonAsync("/api/v1/business/rentals", new
        {
            rentalCategoryId = "b2222222-0000-0000-0000-000000000001",
            name = $"Plastic chair {Guid.NewGuid():N}",
            priceType = "Daily",
            price = 10,
            quantityOwned = quantity,
            advanceType,
            advanceAmount = advance,
            districtIds = new[] { Ernakulam },
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
        districtId = Ernakulam,
    };

    [Fact]
    public async Task Advance_online_balance_by_upi_qr_then_returned()
    {
        var (business, itemId) = await ChairsAsync(1000, "PerPiece", 2);
        await Data(await business.PutAsJsonAsync("/api/v1/business/rentals/payment-settings", new { upiId = "joy@okhdfcbank" }));
        var customer = factory.ClientFor(Guid.NewGuid(), "Customer");

        var detail = await Data(await customer.GetAsync($"/api/v1/rentals/{itemId}"));
        detail.GetProperty("advanceType").GetString().Should().Be("PerPiece");

        var order = await Data(await customer.PostAsJsonAsync("/api/v1/customer/rental-orders", Booking(itemId, 100)));
        var orderId = order.GetProperty("id").GetString();
        order.GetProperty("status").GetString().Should().Be("AwaitingAdvance");
        order.GetProperty("amount").GetDecimal().Should().Be(2000);
        order.GetProperty("payNowAmount").GetDecimal().Should().Be(200);

        var checkout = await Data(await customer.PostAsync($"/api/v1/customer/rental-orders/{orderId}/checkout", null));
        checkout.GetProperty("amount").GetDecimal().Should().Be(200);
        var providerOrderId = checkout.GetProperty("providerOrderId").GetString();

        var forged = await customer.PostAsJsonAsync(
            $"/api/v1/customer/rental-orders/{orderId}/pay", new { providerOrderId, paymentId = "pay_x", signature = "bad" });
        forged.StatusCode.Should().Be(HttpStatusCode.BadRequest);

        var paid = await Data(await customer.PostAsJsonAsync(
            $"/api/v1/customer/rental-orders/{orderId}/pay", new { providerOrderId, paymentId = $"pay_{orderId}", signature = "good" }));
        paid.GetProperty("status").GetString().Should().Be("Booked");
        paid.GetProperty("paymentStatusName").GetString().Should().Be("Advance paid");
        paid.GetProperty("upiId").ValueKind.Should().Be(JsonValueKind.Null, "the QR is the business's to show");

        var seen = await Data(await business.GetAsync($"/api/v1/business/rental-orders/{orderId}"));
        seen.GetProperty("balance").GetDecimal().Should().Be(1800);
        seen.GetProperty("upiId").GetString().Should().Be("joy@okhdfcbank");
        await Data(await business.PostAsJsonAsync($"/api/v1/business/rental-orders/{orderId}/status", new { toStatus = "OnRent" }));

        var early = await business.PostAsJsonAsync($"/api/v1/business/rental-orders/{orderId}/status", new { toStatus = "Returned" });
        early.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (await early.Content.ReadAsStringAsync()).Should().Contain("₹1,800 is still due");

        await Data(await business.PostAsJsonAsync(
            $"/api/v1/business/rental-orders/{orderId}/payments", new { method = "UpiQr", amount = 1800 }));
        var returned = await Data(await business.PostAsJsonAsync(
            $"/api/v1/business/rental-orders/{orderId}/status", new { toStatus = "Returned" }));
        returned.GetProperty("paymentStatus").GetString().Should().Be("Paid");

        var history = await Data(await customer.GetAsync($"/api/v1/customer/rental-orders/{orderId}/history"));
        history.EnumerateArray().Select(h => h.GetProperty("title").GetString()).Should().Equal(
            "Booked by customer", "Advance paid", "Booked", "On rent", "Payment received", "Returned");
    }

    [Fact]
    public async Task An_offline_order_takes_its_advance_in_cash()
    {
        var (business, itemId) = await ChairsAsync(100, "PerOrder", 500);
        var offline = new
        {
            rentalItemId = itemId,
            quantity = 50,
            startDate = Start,
            endDate = End,
            customerName = "Anu",
            deliveryAddress = "Kakkanad",
        };

        // No advance in hand yet: still confirmed, with nothing paid and the whole amount due.
        var notYet = await Data(await business.PostAsJsonAsync("/api/v1/business/rental-orders", offline));
        notYet.GetProperty("status").GetString().Should().Be("Booked");
        notYet.GetProperty("paid").GetDecimal().Should().Be(0);
        notYet.GetProperty("balance").GetDecimal().Should().Be(1000);
        notYet.GetProperty("canCollect").GetBoolean().Should().BeTrue();

        var order = await Data(await business.PostAsJsonAsync("/api/v1/business/rental-orders", new
        {
            offline.rentalItemId, offline.quantity, offline.startDate, offline.endDate, offline.customerName, offline.deliveryAddress,
            advanceMethod = "Cash",
        }));
        order.GetProperty("paid").GetDecimal().Should().Be(500);
        order.GetProperty("balance").GetDecimal().Should().Be(500);
        order.GetProperty("payments")[0].GetProperty("methodName").GetString().Should().Be("Cash");

        var options = await Data(await business.GetAsync("/api/v1/rental-payment-options"));
        options.GetProperty("methods").EnumerateArray().Select(m => m.GetProperty("code").GetString()).Should().Equal("UpiQr", "Cash");
    }

    [Fact]
    public async Task Two_customers_awaiting_their_advance_cannot_hold_the_same_last_chairs()
    {
        var (_, itemId) = await ChairsAsync(10, "PerOrder", 100);

        var tries = await Task.WhenAll(Enumerable.Range(0, 2).Select(_ =>
            factory.ClientFor(Guid.NewGuid(), "Customer").PostAsJsonAsync("/api/v1/customer/rental-orders", Booking(itemId, 10))));

        tries.Count(r => r.IsSuccessStatusCode).Should().Be(1);
        tries.Count(r => r.StatusCode == HttpStatusCode.BadRequest).Should().Be(1);
    }

    [Fact]
    public async Task An_unpaid_hold_is_let_go_and_its_chairs_are_free_again()
    {
        var (_, itemId) = await ChairsAsync(10, "PerOrder", 100);
        var first = factory.ClientFor(Guid.NewGuid(), "Customer");
        var order = await Data(await first.PostAsJsonAsync("/api/v1/customer/rental-orders", Booking(itemId, 10)));
        var orderId = Guid.Parse(order.GetProperty("id").GetString()!);

        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<RentDbContext>();
            await db.RentalOrders.Where(o => o.Id == orderId)
                .ExecuteUpdateAsync(set => set.SetProperty(o => o.HoldUntil, DateTimeOffset.UtcNow.AddMinutes(-1)));
        }

        // Free at once, before the lapse job has run.
        var second = factory.ClientFor(Guid.NewGuid(), "Customer");
        (await second.PostAsJsonAsync("/api/v1/customer/rental-orders", Booking(itemId, 10))).IsSuccessStatusCode.Should().BeTrue();

        using (var scope = factory.Services.CreateScope())
        {
            await scope.ServiceProvider.GetRequiredService<ISender>().Send(new LapseRentalAdvancesCommand());
        }

        var lapsed = await Data(await first.GetAsync($"/api/v1/customer/rental-orders/{orderId}"));
        lapsed.GetProperty("status").GetString().Should().Be("Cancelled");
        (await first.PostAsync($"/api/v1/customer/rental-orders/{orderId}/checkout", null)).StatusCode
            .Should().Be(HttpStatusCode.BadRequest);
    }
}
