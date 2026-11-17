using System.Net.Http.Json;
using System.Text.Json;
using FluentAssertions;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.IntegrationTests;

/// <summary>
/// A colour / size switched Inactive stays Inactive on a real database, through both ways the app
/// saves it: the product form's edit, and Manage variants.
/// </summary>
public class VariantActiveRoundTripTests(MarketplaceApiFactory factory) : IClassFixture<MarketplaceApiFactory>
{
    private const string Posts = "/api/v1/business/marketplace";

    private static Dictionary<string, object?> Saree(object[] variants) => new()
    {
        ["categoryId"] = MarketplaceCatalogSeedData.Products,
        ["subCategoryId"] = MarketplaceCatalogSeedData.SubId(3, 1),
        ["title"] = "Silk saree",
        ["condition"] = "New",
        ["originalPrice"] = 999,
        ["districtId"] = LocationSeedData.DistrictId("Tamil Nadu", "Kanyakumari"),
        ["variants"] = variants,
    };

    private static async Task<JsonElement> Data(HttpResponseMessage response)
    {
        var body = await response.Content.ReadAsStringAsync();
        response.IsSuccessStatusCode.Should().BeTrue(body);
        return JsonDocument.Parse(body).RootElement.GetProperty("data");
    }

    private static List<(string Colour, bool IsActive)> Colours(JsonElement post) =>
        [.. post.GetProperty("variants").EnumerateArray()
            .Select(v => (v.GetProperty("colour").GetString()!, v.GetProperty("isActive").GetBoolean()))];

    [Fact]
    public async Task SwitchingAColourOff_InTheProductForm_IsSaved_AndReadBack()
    {
        var client = factory.ClientFor(Guid.NewGuid());
        var created = await Data(await client.PostAsJsonAsync(Posts, Saree(
        [
            new { colour = "Red", price = 499, stock = 10 },
            new { colour = "Green", price = 449, stock = 5 },
        ])));
        var ids = created.GetProperty("variants").EnumerateArray().Select(v => v.GetProperty("id").GetString()).ToList();
        var id = created.GetProperty("id").GetString();

        var edited = await Data(await client.PutAsJsonAsync($"{Posts}/{id}", Saree(
        [
            new { id = ids[0], colour = "Red", price = 499, stock = 10, isActive = true },
            new { id = ids[1], colour = "Green", price = 449, stock = 5, isActive = false },
        ])));
        var listed = (await Data(await client.GetAsync(Posts))).GetProperty("items")[0];

        Colours(edited).Should().Equal(("Red", true), ("Green", false));
        Colours(listed).Should().Equal(("Red", true), ("Green", false));
        listed.GetProperty("quantity").GetInt32().Should().Be(10);
    }

    [Fact]
    public async Task SwitchingAColourOff_OnManageVariants_IsSaved_AndBackOnAgain()
    {
        var client = factory.ClientFor(Guid.NewGuid());
        var created = await Data(await client.PostAsJsonAsync(Posts, Saree(
        [
            new { colour = "Red", price = 499, stock = 10 },
            new { colour = "Green", price = 449, stock = 5 },
        ])));
        var ids = created.GetProperty("variants").EnumerateArray().Select(v => v.GetProperty("id").GetString()).ToList();
        var id = created.GetProperty("id").GetString();

        object Body(bool greenOn) => new
        {
            variants = new object[]
            {
                new { id = ids[0], colour = "Red", price = 499, stock = 10, isActive = true },
                new { id = ids[1], colour = "Green", price = 449, stock = 5, isActive = greenOn },
            },
        };

        await Data(await client.PutAsJsonAsync($"{Posts}/{id}/variants", Body(greenOn: false)));
        Colours((await Data(await client.GetAsync(Posts))).GetProperty("items")[0])
            .Should().Equal(("Red", true), ("Green", false));

        await Data(await client.PutAsJsonAsync($"{Posts}/{id}/variants", Body(greenOn: true)));
        Colours((await Data(await client.GetAsync(Posts))).GetProperty("items")[0])
            .Should().Equal(("Red", true), ("Green", true));
    }
}
