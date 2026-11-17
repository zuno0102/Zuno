using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using FluentAssertions;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.IntegrationTests;

/// <summary>
/// A colour / size's own photos over HTTP on a real database: uploaded, listed with the colour,
/// kept apart from the product's cover, and refused past the colour's slots.
/// </summary>
public class VariantPhotoApiTests(MarketplaceApiFactory factory) : IClassFixture<MarketplaceApiFactory>
{
    private const string Posts = "/api/v1/business/marketplace";

    // The smallest valid PNG: the server checks the bytes, not the name.
    private static readonly byte[] Png = Convert.FromBase64String(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==");

    private static MultipartFormDataContent File()
    {
        var content = new ByteArrayContent(Png);
        content.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        return new MultipartFormDataContent { { content, "file", "photo.png" } };
    }

    private static async Task<JsonElement> Data(HttpResponseMessage response)
    {
        var body = await response.Content.ReadAsStringAsync();
        response.IsSuccessStatusCode.Should().BeTrue(body);
        return JsonDocument.Parse(body).RootElement.GetProperty("data");
    }

    [Fact]
    public async Task AColoursPhoto_IsSavedWithTheColour_ApartFromTheCover()
    {
        var client = factory.ClientFor(Guid.NewGuid());
        var created = await Data(await client.PostAsJsonAsync(Posts, new Dictionary<string, object?>
        {
            ["categoryId"] = MarketplaceCatalogSeedData.Products,
            ["subCategoryId"] = MarketplaceCatalogSeedData.SubId(3, 1),
            ["title"] = "Silk saree",
            ["condition"] = "New",
            ["districtId"] = LocationSeedData.DistrictId("Tamil Nadu", "Kanyakumari"),
            ["variants"] = new object[]
            {
                new { colour = "Red", price = 499, stock = 10 },
                new { colour = "Green", price = 449, stock = 5 },
            },
        }));
        var id = created.GetProperty("id").GetString();
        var green = created.GetProperty("variants").EnumerateArray()
            .Single(v => v.GetProperty("colour").GetString() == "Green").GetProperty("id").GetString();

        await Data(await client.PostAsync($"{Posts}/{id}/images/0", File()));
        var withPhoto = await Data(await client.PostAsync($"{Posts}/{id}/variants/{green}/images/0", File()));
        var listed = (await Data(await client.GetAsync(Posts))).GetProperty("items")[0];

        foreach (var post in new[] { withPhoto, listed })
        {
            post.GetProperty("media").GetArrayLength().Should().Be(1, "the cover is still the product's one photo");
            var colour = post.GetProperty("variants").EnumerateArray().Single(v => v.GetProperty("id").GetString() == green);
            colour.GetProperty("media").GetArrayLength().Should().Be(1);
            colour.GetProperty("media")[0].GetProperty("url").GetString().Should().Contain("/variant-");
        }

        (await client.PostAsync($"{Posts}/{id}/variants/{green}/images/3", File())).StatusCode
            .Should().Be(HttpStatusCode.BadRequest, "a colour has 3 photo slots");

        var removed = await Data(await client.DeleteAsync($"{Posts}/{id}/variants/{green}/images/0"));
        removed.GetProperty("variants").EnumerateArray().Single(v => v.GetProperty("id").GetString() == green)
            .GetProperty("media").GetArrayLength().Should().Be(0);
        removed.GetProperty("media").GetArrayLength().Should().Be(1);
    }
}
