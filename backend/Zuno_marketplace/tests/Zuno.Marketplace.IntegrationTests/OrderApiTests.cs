using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using FluentAssertions;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.IntegrationTests;

/// <summary>
/// Product orders and B2B requests through the real API and database: the migration, the database's
/// own checks, who may call what, and the whole way from ordered to closed.
/// </summary>
public class OrderApiTests(MarketplaceApiFactory factory) : IClassFixture<MarketplaceApiFactory>
{
    private const string Business = "/api/v1/business/marketplace";
    private const string Customer = "/api/v1/marketplace";

    private static readonly byte[] Png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, .. new byte[64]];

    private static string Kanyakumari => LocationSeedData.DistrictId("Tamil Nadu", "Kanyakumari").ToString();

    /// <summary>A new seller with a live saree in Red (5) and Blue (3).</summary>
    private async Task<(HttpClient Seller, Guid PostId, Guid Red, Guid Blue)> SareeSellerAsync()
    {
        var seller = factory.ClientFor(Guid.NewGuid());
        (await seller.PostAsync($"{Business}/profile/sync", null)).EnsureSuccessStatusCode();
        var post = await Data(await seller.PostAsJsonAsync(Business, new
        {
            categoryId = MarketplaceCatalogSeedData.Products,
            subCategoryId = MarketplaceCatalogSeedData.SubId(3, 1),
            title = "Silk saree",
            price = 2400,
            condition = "New",
            districtId = Kanyakumari,
            attributes = new Dictionary<string, string>(),
            variants = new[]
            {
                new { colour = "Red", price = (decimal?)2400, stock = 5 },
                new { colour = "Blue", price = (decimal?)2600, stock = 3 },
            },
        }), HttpStatusCode.Created);

        var variants = post.GetProperty("variants").EnumerateArray().ToList();
        Guid Id(string colour) => variants.Single(v => v.GetProperty("colour").GetString() == colour).GetProperty("id").GetGuid();
        return (seller, post.GetProperty("id").GetGuid(), Id("Red"), Id("Blue"));
    }

    private static object Order(Guid postId, Guid variantId, string method = "CashOnDelivery", int quantity = 2) => new
    {
        postId,
        variantId,
        quantity,
        paymentMethod = method,
        deliveryAddress = "12, North Street, Nagercoil",
        pincode = "629001",
    };

    [Fact]
    public async Task Cash_Order_Goes_From_New_To_Closed_Through_The_Api()
    {
        var (seller, postId, red, _) = await SareeSellerAsync();
        var customer = factory.ClientFor(Guid.NewGuid(), "Customer");

        var placed = await Data(await customer.PostAsJsonAsync($"{Customer}/orders", Order(postId, red)), HttpStatusCode.Created);
        placed.GetProperty("status").GetString().Should().Be("Placed");
        placed.GetProperty("amount").GetDecimal().Should().Be(4800m);
        var id = placed.GetProperty("id").GetGuid();

        var list = await Data(await seller.GetAsync($"{Business}/orders"));
        list.GetProperty("totalCount").GetInt32().Should().Be(1);
        list.GetProperty("counts").EnumerateArray()
            .Single(c => c.GetProperty("status").GetString() == "Placed").GetProperty("count").GetInt32().Should().Be(1);
        var card = list.GetProperty("items")[0];
        card.GetProperty("customerPhone").GetString().Should().Be("9876543210");
        card.GetProperty("actions").EnumerateArray().Select(a => a.GetProperty("name").GetString()).Should().Equal("Confirm order");

        await Data(await seller.PatchAsJsonAsync($"{Business}/orders/{id}/status", new { status = "Confirmed" }));
        var shipped = await Data(await seller.PostAsJsonAsync($"{Business}/orders/{id}/ship", new { courierCode = "delhivery", trackingNumber = "149021" }));
        shipped.GetProperty("trackingUrl").GetString().Should().Be("https://www.delhivery.com/track/package/149021");

        var receipt = await Data(await seller.PostAsync($"{Business}/orders/{id}/receipt", Photo()));
        receipt.GetProperty("receiptUrl").GetString().Should().StartWith($"/uploads/marketplace/{id}/receipt-0-");

        // Shipped: the customer's cancel is refused.
        (await customer.PostAsync($"{Customer}/orders/{id}/cancel", null)).StatusCode.Should().Be(HttpStatusCode.BadRequest);

        await Data(await seller.PatchAsJsonAsync($"{Business}/orders/{id}/status", new { status = "OutForDelivery" }));
        var delivered = await Data(await seller.PatchAsJsonAsync($"{Business}/orders/{id}/status", new { status = "Delivered" }));
        delivered.GetProperty("isPaid").GetBoolean().Should().BeTrue();
        delivered.GetProperty("events").GetArrayLength().Should().Be(5);

        var closed = await Data(await customer.PostAsJsonAsync($"{Customer}/orders/{id}/review", new { score = 5, comment = "Lovely saree" }));
        closed.GetProperty("status").GetString().Should().Be("Closed");
        closed.GetProperty("ratingScore").GetInt16().Should().Be(5);
    }

    [Fact]
    public async Task Online_Order_Needs_A_Proven_Payment_And_Is_Refunded_When_Cancelled()
    {
        var (seller, postId, _, blue) = await SareeSellerAsync();
        var customer = factory.ClientFor(Guid.NewGuid(), "Customer");

        var placed = await Data(await customer.PostAsJsonAsync($"{Customer}/orders", Order(postId, blue, "Online", 1)), HttpStatusCode.Created);
        placed.GetProperty("status").GetString().Should().Be("AwaitingPayment");
        var id = placed.GetProperty("id").GetGuid();

        var checkout = await Data(await customer.PostAsync($"{Customer}/orders/{id}/payment", null));
        var providerOrderId = checkout.GetProperty("providerOrderId").GetString();
        checkout.GetProperty("amount").GetDecimal().Should().Be(2600m);

        var forged = await customer.PostAsJsonAsync($"{Customer}/orders/{id}/payment/confirm", new { providerOrderId, paymentId = "pay_1", signature = "forged" });
        forged.StatusCode.Should().Be(HttpStatusCode.BadRequest);

        var paid = await Data(await customer.PostAsJsonAsync($"{Customer}/orders/{id}/payment/confirm", new { providerOrderId, paymentId = $"pay_{id:N}", signature = "good" }));
        paid.GetProperty("status").GetString().Should().Be("Confirmed");
        paid.GetProperty("dueToBusiness").GetDecimal().Should().Be(2600m);

        // The business sees it confirmed and paid.
        var seen = await Data(await seller.GetAsync($"{Business}/orders/{id}"));
        seen.GetProperty("isPaid").GetBoolean().Should().BeTrue();

        var cancelled = await Data(await customer.PostAsync($"{Customer}/orders/{id}/cancel", null));
        cancelled.GetProperty("status").GetString().Should().Be("Cancelled");
        cancelled.GetProperty("refunded").GetBoolean().Should().BeTrue();
        cancelled.GetProperty("dueToBusiness").GetDecimal().Should().Be(0m);

        // The held piece is back on the colour.
        var post = await Data(await seller.GetAsync($"{Business}?products=true"));
        post.GetProperty("items")[0].GetProperty("variants").EnumerateArray()
            .Single(v => v.GetProperty("colour").GetString() == "Blue").GetProperty("stock").GetInt32().Should().Be(3);
    }

    [Fact]
    public async Task Orders_Are_Private_To_Their_Business_And_Customer()
    {
        var (_, postId, red, _) = await SareeSellerAsync();
        var customer = factory.ClientFor(Guid.NewGuid(), "Customer");
        var id = (await Data(await customer.PostAsJsonAsync($"{Customer}/orders", Order(postId, red)), HttpStatusCode.Created))
            .GetProperty("id").GetGuid();

        var otherBusiness = factory.ClientFor(Guid.NewGuid());
        (await otherBusiness.GetAsync($"{Business}/orders/{id}")).StatusCode.Should().Be(HttpStatusCode.Forbidden);
        (await otherBusiness.PatchAsJsonAsync($"{Business}/orders/{id}/status", new { status = "Confirmed" }))
            .StatusCode.Should().Be(HttpStatusCode.Forbidden);

        var otherCustomer = factory.ClientFor(Guid.NewGuid(), "Customer");
        (await otherCustomer.PostAsync($"{Customer}/orders/{id}/cancel", null)).StatusCode.Should().Be(HttpStatusCode.Forbidden);

        // A customer cannot use the business's order endpoints at all.
        (await customer.GetAsync($"{Business}/orders")).StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Bad_Order_Input_Is_Refused_With_A_Reason()
    {
        var (_, postId, red, _) = await SareeSellerAsync();
        var customer = factory.ClientFor(Guid.NewGuid(), "Customer");

        foreach (var bad in new object[]
        {
            new { postId, variantId = red, quantity = 1, paymentMethod = "Barter", deliveryAddress = "x", pincode = "629001" },
            new { postId, variantId = red, quantity = 1, paymentMethod = "CashOnDelivery", deliveryAddress = "", pincode = "629001" },
            new { postId, variantId = red, quantity = 1, paymentMethod = "CashOnDelivery", deliveryAddress = "x", pincode = "62900" },
            new { postId, variantId = red, quantity = 0, paymentMethod = "CashOnDelivery", deliveryAddress = "x", pincode = "629001" },
            new { postId, variantId = red, quantity = 9, paymentMethod = "CashOnDelivery", deliveryAddress = "x", pincode = "629001" },
        })
        {
            (await customer.PostAsJsonAsync($"{Customer}/orders", bad)).StatusCode.Should().Be(HttpStatusCode.BadRequest);
        }
    }

    [Fact]
    public async Task Payment_Settings_Keep_A_Way_To_Pay_And_Decide_What_Customers_May_Choose()
    {
        var (seller, postId, red, _) = await SareeSellerAsync();
        (await seller.PutAsJsonAsync($"{Business}/payment-settings", new { acceptsCashOnDelivery = false, acceptsOnlinePay = false }))
            .StatusCode.Should().Be(HttpStatusCode.BadRequest);

        var saved = await Data(await seller.PutAsJsonAsync($"{Business}/payment-settings", new { acceptsCashOnDelivery = false, acceptsOnlinePay = true }));
        saved.GetProperty("acceptsCashOnDelivery").GetBoolean().Should().BeFalse();
        (await Data(await seller.GetAsync($"{Business}/payment-settings"))).GetProperty("acceptsOnlinePay").GetBoolean().Should().BeTrue();

        var customer = factory.ClientFor(Guid.NewGuid(), "Customer");
        (await customer.PostAsJsonAsync($"{Customer}/orders", Order(postId, red))).StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (await customer.PostAsJsonAsync($"{Customer}/orders", Order(postId, red, "Online"))).StatusCode.Should().Be(HttpStatusCode.Created);
    }

    [Fact]
    public async Task B2B_Request_Is_Accepted_And_Contacts_Follow_The_Plan_Rule()
    {
        var seller = factory.ClientFor(Guid.NewGuid());
        (await seller.PostAsync($"{Business}/profile/sync", null)).EnsureSuccessStatusCode();
        var lot = await Data(await seller.PostAsJsonAsync(Business, new
        {
            categoryId = MarketplaceCatalogSeedData.B2BWholesale,
            subCategoryId = MarketplaceCatalogSeedData.SubId(4, 1),
            title = "Nendran banana",
            price = 38,
            priceUnit = "kg",
            tradeType = "Wholesale",
            minOrderQuantity = 200,
            quantity = 2000,
            districtId = Kanyakumari,
            attributes = new Dictionary<string, string>(),
        }), HttpStatusCode.Created);
        var postId = lot.GetProperty("id").GetGuid();

        var buyer = factory.ClientFor(Guid.NewGuid(), "Customer");
        (await buyer.PostAsJsonAsync($"{Customer}/b2b-requests", new { postId, quantity = 100 }))
            .StatusCode.Should().Be(HttpStatusCode.BadRequest, "below the smallest order");
        var asked = await Data(await buyer.PostAsJsonAsync($"{Customer}/b2b-requests", new { postId, quantity = 500, message = "Weekly?" }), HttpStatusCode.Created);
        var id = asked.GetProperty("id").GetGuid();
        (await buyer.PostAsJsonAsync($"{Customer}/b2b-requests", new { postId, quantity = 500 }))
            .StatusCode.Should().Be(HttpStatusCode.BadRequest, "one open request per lot");

        var waiting = (await Data(await seller.GetAsync($"{Business}/b2b-requests?status=Requested"))).GetProperty("items")[0];
        waiting.GetProperty("buyerPhone").ValueKind.Should().Be(JsonValueKind.Null);

        var accepted = await Data(await seller.PostAsync($"{Business}/b2b-requests/{id}/accept", null));
        accepted.GetProperty("status").GetString().Should().Be("Accepted");
        accepted.GetProperty("buyerPhone").GetString().Should().Be("9876543210");

        var mine = (await Data(await buyer.GetAsync($"{Customer}/b2b-requests"))).GetProperty("items")[0];
        mine.GetProperty("sellerName").GetString().Should().Be("Test Shop");
        mine.GetProperty("sellerPhone").ValueKind.Should().Be(JsonValueKind.Null, "no B2B plan running");
        mine.GetProperty("contactNeedsPlan").GetBoolean().Should().BeTrue();

        (await seller.PostAsync($"{Business}/b2b-requests/{id}/decline", null)).StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Options_Carry_The_Order_Tables()
    {
        var options = await Data(await factory.ClientFor(Guid.NewGuid()).GetAsync("/api/v1/marketplace-options"));
        options.GetProperty("orderStatuses").EnumerateArray().Select(s => s.GetProperty("code").GetString())
            .Should().Contain(["Placed", "Shipped", "Delivered", "Closed"]);
        options.GetProperty("couriers").EnumerateArray().Last().GetProperty("takesCustomName").GetBoolean().Should().BeTrue();
        options.GetProperty("paymentMethods").GetArrayLength().Should().Be(2);
        options.GetProperty("b2bRequestStatuses").GetArrayLength().Should().Be(3);
        options.GetProperty("autoCloseDays").GetInt32().Should().Be(10);
    }

    private static MultipartFormDataContent Photo()
    {
        var file = new ByteArrayContent(Png);
        file.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        return new MultipartFormDataContent { { file, "file", "receipt.png" } };
    }

    private static async Task<JsonElement> Data(HttpResponseMessage response, HttpStatusCode expected = HttpStatusCode.OK)
    {
        var body = await response.Content.ReadAsStringAsync();
        response.StatusCode.Should().Be(expected, body);
        return JsonDocument.Parse(body).RootElement.GetProperty("data").Clone();
    }
}
