using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.IntegrationTests;

/// <summary>
/// The Marketplace API under attack, as someone with the app and a proxy would try it: forged and
/// tampered tokens, another business's posts, fields the form never sends, hostile input, files that
/// are not what they say, paths outside the upload folder, other websites, and floods. Every attempt
/// must be refused cleanly — never a 500, never a leak.
/// </summary>
[Trait("Category", "Security")]
public class SecurityAttackTests(MarketplaceApiFactory factory) : IClassFixture<MarketplaceApiFactory>
{
    private const string Posts = "/api/v1/business/marketplace";
    private static readonly string Kanyakumari = LocationSeedData.DistrictId("Tamil Nadu", "Kanyakumari").ToString();
    private static readonly byte[] Png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, .. new byte[64]];

    private static object Saree(Action<Dictionary<string, object?>>? change = null)
    {
        var body = new Dictionary<string, object?>
        {
            ["categoryId"] = MarketplaceCatalogSeedData.Products,
            ["subCategoryId"] = MarketplaceCatalogSeedData.SubId(3, 1),
            ["title"] = "Silk saree",
            ["price"] = 499,
            ["condition"] = "New",
            ["quantity"] = 4,
            ["districtId"] = Kanyakumari,
        };
        change?.Invoke(body);
        return body;
    }

    // ── Tokens ──────────────────────────────────────────────────────────────────────────────────

    [Fact]
    public async Task ForgedOrTamperedTokens_Are401()
    {
        var user = Guid.NewGuid();
        var good = MarketplaceApiFactory.Token(user, "BusinessOwner");
        var parts = good.Split('.');

        // A payload rewritten to SuperAdmin, keeping the old signature.
        var payload = JsonSerializer.Deserialize<Dictionary<string, object>>(FromBase64Url(parts[1]))!;
        payload[ClaimTypes.Role] = "SuperAdmin";
        var tampered = $"{parts[0]}.{Base64Url(JsonSerializer.Serialize(payload))}.{parts[2]}";

        var tokens = new Dictionary<string, string>
        {
            ["alg none"] = $"{Base64Url("""{"alg":"none","typ":"JWT"}""")}.{parts[1]}.",
            ["tampered role"] = tampered,
            ["wrong key"] = MarketplaceApiFactory.Token(user, "BusinessOwner", key: new string('x', 32)),
            ["expired"] = MarketplaceApiFactory.Token(user, "BusinessOwner", TimeSpan.FromMinutes(-1)),
            ["garbage"] = "not.a.token",
            ["empty signature"] = $"{parts[0]}.{parts[1]}.",
        };

        foreach (var (name, token) in tokens)
        {
            var client = factory.CreateClient();
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
            (await client.GetAsync(Posts)).StatusCode.Should().Be(HttpStatusCode.Unauthorized, name);
            (await client.GetAsync("/api/v1/admin/marketplace/categories")).StatusCode.Should().Be(HttpStatusCode.Unauthorized, name);
        }
    }

    [Fact]
    public async Task ATokenWithAnUnknownRole_CannotReachBusinessOrAdmin()
    {
        var client = factory.ClientFor(Guid.NewGuid(), "Hacker");

        (await client.GetAsync(Posts)).StatusCode.Should().Be(HttpStatusCode.Forbidden);
        (await client.GetAsync("/api/v1/admin/marketplace/categories")).StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    // ── Another business's post (IDOR) ──────────────────────────────────────────────────────────

    [Fact]
    public async Task AnotherBusiness_CannotTouchAPost_ByAnyRoute_AndThePostStaysAsItWas()
    {
        var owner = factory.ClientFor(Guid.NewGuid());
        var created = await owner.PostAsJsonAsync(Posts, Saree());
        created.StatusCode.Should().Be(HttpStatusCode.Created);
        var id = (await Data(created)).GetProperty("id").GetString();
        (await owner.PostAsync($"{Posts}/{id}/images/0", File(Png, "image/png"))).EnsureSuccessStatusCode();

        var attacker = factory.ClientFor(Guid.NewGuid());
        var attempts = new Dictionary<string, Func<Task<HttpResponseMessage>>>
        {
            ["edit"] = () => attacker.PutAsJsonAsync($"{Posts}/{id}", Saree(b => b["title"] = "Hacked")),
            ["pause"] = () => attacker.PatchAsJsonAsync($"{Posts}/{id}/status", new { status = "Paused" }),
            ["stock"] = () => attacker.PatchAsJsonAsync($"{Posts}/{id}/stock", new { quantity = 0 }),
            ["variants"] = () => attacker.PutAsJsonAsync($"{Posts}/{id}/variants",
                new { variants = new[] { new { colour = "Hacked", price = 1, stock = 0 } } }),
            ["remove"] = () => attacker.DeleteAsync($"{Posts}/{id}"),
            ["replace photo"] = () => attacker.PostAsync($"{Posts}/{id}/images/0", File(Png, "image/png")),
            ["remove photo"] = () => attacker.DeleteAsync($"{Posts}/{id}/images/0"),
        };
        foreach (var (name, attempt) in attempts)
        {
            (await attempt()).StatusCode.Should().BeOneOf([HttpStatusCode.Forbidden, HttpStatusCode.NotFound], name);
        }

        (await Data(await attacker.GetAsync(Posts))).GetProperty("items").GetArrayLength().Should().Be(0, "a business lists only its own posts");
        var mine = (await Data(await owner.GetAsync(Posts))).GetProperty("items")[0];
        mine.GetProperty("title").GetString().Should().Be("Silk saree");
        mine.GetProperty("status").GetString().Should().Be("Active");
        mine.GetProperty("quantity").GetInt32().Should().Be(4);
        mine.GetProperty("media").GetArrayLength().Should().Be(1);
    }

    // ── Fields the form never sends (mass assignment) ──────────────────────────────────────────

    [Fact]
    public async Task ExtraFields_CannotSetTheOwnerTheStatusOrTheId()
    {
        var me = Guid.NewGuid();
        var someoneElse = Guid.NewGuid();
        var forcedId = Guid.NewGuid();
        var client = factory.ClientFor(me);

        var created = await client.PostAsJsonAsync(Posts, Saree(b =>
        {
            b["id"] = forcedId;
            b["ownerUserId"] = someoneElse;
            b["status"] = "Sold";
            b["isDeleted"] = true;
            b["createdDate"] = "2000-01-01T00:00:00Z";
        }));

        created.StatusCode.Should().Be(HttpStatusCode.Created);
        var post = await Data(created);
        post.GetProperty("id").GetString().Should().NotBe(forcedId.ToString());
        post.GetProperty("status").GetString().Should().Be("Active");
        post.GetProperty("createdDate").GetDateTimeOffset().Should().BeAfter(DateTimeOffset.UtcNow.AddMinutes(-5));
        (await Data(await client.GetAsync(Posts))).GetProperty("items").GetArrayLength().Should().Be(1, "it is the caller's");
        (await Data(await factory.ClientFor(someoneElse).GetAsync(Posts))).GetProperty("items").GetArrayLength().Should().Be(0);
    }

    // ── Hostile input ───────────────────────────────────────────────────────────────────────────

    [Fact]
    public async Task HostileQueryStrings_AreRefusedOrCapped_NeverA500()
    {
        var client = factory.ClientFor(Guid.NewGuid());

        foreach (var query in new[]
        {
            "?kind=' OR 1=1; DROP TABLE marketplace_posts;--",
            "?status=Active' --",
            "?categoryId=1 OR 1=1",
            "?page=-5",
            "?page=2147483647",
            "?pageSize=-1",
            "?page=99999999999999999999",
        })
        {
            var response = await client.GetAsync(Posts + query);
            ((int)response.StatusCode).Should().BeLessThan(500, query);
        }

        var huge = await Data(await client.GetAsync($"{Posts}?pageSize=100000"));
        huge.GetProperty("pageSize").GetInt32().Should().BeLessThanOrEqualTo(100, "a page is capped by the server");
        (await client.GetAsync(Posts)).StatusCode.Should().Be(HttpStatusCode.OK, "the table is still there");
    }

    [Fact]
    public async Task HostileBodies_Are400_NeverA500_AndLeakNothing()
    {
        var client = factory.ClientFor(Guid.NewGuid());
        var bodies = new Dictionary<string, HttpContent>
        {
            ["broken JSON"] = new StringContent("{\"title\": ", Encoding.UTF8, "application/json"),
            ["wrong types"] = JsonContent.Create(new { categoryId = "x", price = "free", quantity = new[] { 1 } }),
            ["int overflow"] = new StringContent(
                $$"""{"categoryId":"{{MarketplaceCatalogSeedData.Products}}","title":"x","price":1,"quantity":99999999999,"districtId":"{{Kanyakumari}}"}""",
                Encoding.UTF8, "application/json"),
            ["huge price"] = JsonContent.Create(Saree(b => b["price"] = 1e27m)),
            ["negative stock"] = JsonContent.Create(Saree(b => b["quantity"] = -3)),
            ["pack of zero"] = JsonContent.Create(Saree(b => b["packQuantity"] = 0)),
            ["title of 100,000 characters"] = JsonContent.Create(Saree(b => b["title"] = new string('A', 100_000))),
            ["500 colours"] = JsonContent.Create(Saree(b => b["variants"] = Enumerable.Range(0, 500)
                .Select(i => new { colour = $"C{i}", stock = 1 }).ToArray())),
            ["unknown district"] = JsonContent.Create(Saree(b => b["districtId"] = Guid.NewGuid())),
            ["ships to a made-up state"] = JsonContent.Create(Saree(b =>
            {
                b["deliversEverywhere"] = false;
                b["deliveryStateId"] = Guid.NewGuid();
            })),
            ["script in the title"] = JsonContent.Create(Saree(b => b["title"] = "<script>fetch('//evil')</script>")),
        };

        foreach (var (name, body) in bodies)
        {
            var response = await client.PostAsync(Posts, body);
            var text = await response.Content.ReadAsStringAsync();

            if (name == "script in the title")
            {
                // Stored as text and returned as JSON (never as a page): the app shows it as text.
                response.StatusCode.Should().Be(HttpStatusCode.Created, name);
                response.Content.Headers.ContentType!.MediaType.Should().Be("application/json");
                continue;
            }

            response.StatusCode.Should().Be(HttpStatusCode.BadRequest, $"{name}: {text[..Math.Min(text.Length, 200)]}");
            text.Should().NotContainAny(["   at ", "Exception", "Npgsql", "StackTrace"], name);
        }
    }

    // ── Files ───────────────────────────────────────────────────────────────────────────────────

    [Fact]
    public async Task Uploads_ThatAreNotRealImages_AreRefused()
    {
        var client = factory.ClientFor(Guid.NewGuid());
        var id = (await Data(await client.PostAsJsonAsync(Posts, Saree()))).GetProperty("id").GetString();

        var files = new Dictionary<string, (byte[] Bytes, string Type)>
        {
            ["HTML called a PNG"] = ("<html><script>alert(1)</script></html>"u8.ToArray(), "image/png"),
            ["SVG with a script"] = ("""<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>"""u8.ToArray(), "image/svg+xml"),
            ["a Windows program"] = ([0x4D, 0x5A, 0x90, 0x00, .. new byte[64]], "image/jpeg"),
            ["a PDF"] = ("%PDF-1.7\n"u8.ToArray(), "image/jpeg"),
            ["empty"] = ([], "image/png"),
        };
        foreach (var (name, (bytes, type)) in files)
        {
            (await client.PostAsync($"{Posts}/{id}/images/0", File(bytes, type))).StatusCode.Should().Be(HttpStatusCode.BadRequest, name);
        }

        (await client.PostAsync($"{Posts}/{id}/images/-1", File(Png, "image/png"))).StatusCode.Should().BeOneOf(HttpStatusCode.BadRequest, HttpStatusCode.NotFound);
        var tooBig = await client.PostAsync($"{Posts}/{id}/images/0", File([.. Png, .. new byte[6 * 1024 * 1024]], "image/png"));
        tooBig.StatusCode.Should().BeOneOf(HttpStatusCode.BadRequest, HttpStatusCode.RequestEntityTooLarge);
    }

    [Fact]
    public async Task ThePhotoFolder_ServesNothingOutsideIt_AndPhotosCannotRunAsPages()
    {
        var client = factory.ClientFor(Guid.NewGuid());
        var id = (await Data(await client.PostAsJsonAsync(Posts, Saree()))).GetProperty("id").GetString();
        var saved = await Data(await client.PostAsync($"{Posts}/{id}/images/0", File(Png, "image/png")));
        var url = saved.GetProperty("media")[0].GetProperty("url").GetString()!;

        var anonymous = factory.CreateClient();
        var photo = await anonymous.GetAsync(url);
        photo.StatusCode.Should().Be(HttpStatusCode.OK);
        photo.Content.Headers.ContentType!.MediaType.Should().Be("image/png");
        photo.Headers.GetValues("X-Content-Type-Options").Should().Contain("nosniff");

        foreach (var path in new[]
        {
            "/uploads/../appsettings.json",
            "/uploads/%2e%2e/appsettings.json",
            "/uploads/..%2fappsettings.json",
            "/uploads/%2e%2e%2f%2e%2e%2fZuno.Marketplace.Api.dll",
            "/uploads/....//appsettings.json",
        })
        {
            var response = await anonymous.GetAsync(path);
            var text = await response.Content.ReadAsStringAsync();
            text.Should().NotContain("ConnectionStrings", path).And.NotContain("SigningKey", path);
            response.StatusCode.Should().NotBe(HttpStatusCode.OK, path);
        }
    }

    // ── The browser ─────────────────────────────────────────────────────────────────────────────

    [Fact]
    public async Task EveryReply_CarriesTheSecurityHeaders()
    {
        var response = await factory.ClientFor(Guid.NewGuid()).GetAsync(Posts);

        response.Headers.GetValues("X-Content-Type-Options").Should().Contain("nosniff");
        response.Headers.GetValues("X-Frame-Options").Should().Contain("DENY");
        response.Headers.GetValues("Content-Security-Policy").Single().Should().Contain("default-src 'none'");
        response.Headers.GetValues("Referrer-Policy").Should().Contain("no-referrer");
        response.Headers.Contains("Server").Should().BeFalse("the server does not announce what it runs");
        response.Headers.Contains("X-Powered-By").Should().BeFalse();
    }

    [Fact]
    public async Task AnotherWebsite_IsNotAllowedToCallTheApi()
    {
        var client = factory.CreateClient();
        using var preflight = new HttpRequestMessage(HttpMethod.Options, Posts);
        preflight.Headers.Add("Origin", "https://evil.example");
        preflight.Headers.Add("Access-Control-Request-Method", "DELETE");
        preflight.Headers.Add("Access-Control-Request-Headers", "authorization");

        var response = await client.SendAsync(preflight);

        response.Headers.Contains("Access-Control-Allow-Origin").Should().BeFalse();
    }

    // ── Floods ──────────────────────────────────────────────────────────────────────────────────

    [Fact]
    public async Task AFlood_IsCutOffWith429()
    {
        using var limited = factory.WithWebHostBuilder(builder => builder.ConfigureAppConfiguration((_, config) =>
            config.AddInMemoryCollection(new Dictionary<string, string?> { ["RateLimiting:GlobalPermitLimit"] = "5" })));
        var client = limited.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", MarketplaceApiFactory.Token(Guid.NewGuid(), "BusinessOwner"));

        var statuses = new List<HttpStatusCode>();
        for (var i = 0; i < 12; i++)
        {
            statuses.Add((await client.GetAsync(Posts)).StatusCode);
        }

        statuses.Should().Contain(HttpStatusCode.TooManyRequests);
        statuses.Take(5).Should().OnlyContain(s => s == HttpStatusCode.OK);
    }

    // ── Helpers ─────────────────────────────────────────────────────────────────────────────────

    private static string Base64Url(string text) =>
        Convert.ToBase64String(Encoding.UTF8.GetBytes(text)).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static string FromBase64Url(string encoded)
    {
        var padded = encoded.Replace('-', '+').Replace('_', '/');
        padded += new string('=', (4 - padded.Length % 4) % 4);
        return Encoding.UTF8.GetString(Convert.FromBase64String(padded));
    }

    private static MultipartFormDataContent File(byte[] bytes, string contentType)
    {
        var content = new ByteArrayContent(bytes);
        content.Headers.ContentType = new MediaTypeHeaderValue(contentType);
        return new MultipartFormDataContent { { content, "file", "photo.png" } };
    }

    private static async Task<JsonElement> Data(HttpResponseMessage response)
    {
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("data");
    }
}
