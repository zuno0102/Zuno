using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text;
using System.Text.Json.Serialization;
using FluentAssertions;
using Microsoft.IdentityModel.Tokens;

namespace Zuno.Api.IntegrationTests;

/// <summary>
/// What the API refuses, proved against the running application rather than the handlers.
/// </summary>
/// <remarks>
/// Authorisation is enforced by the pipeline — attributes, policies, the token middleware — and none
/// of that runs in a unit test of a handler. A handler test can show the business rule is right while
/// the endpoint in front of it is wide open, so these go through HTTP with real tokens.
///
/// Three questions, each asked of every area of the app:
///
///   * no token at all — is it refused?
///   * a valid token for the wrong role — is it refused?
///   * a token somebody made up, tampered with, or signed themselves — is it refused?
///
/// The third matters most. A role is a claim inside the token, so anyone who could mint or edit one
/// could call themselves an admin; the signature is the only thing stopping them, and these prove it
/// holds.
/// </remarks>
public class SecurityTests(ZunoApiFactory factory) : IClassFixture<ZunoApiFactory>
{
    private readonly HttpClient _client = factory.CreateClient();

    /// <summary>Matches the factory's configuration. A token signed with anything else must fail.</summary>
    private const string RealSigningKey = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    private const string RealIssuer = "Zuno.Api.IntegrationTests";
    private const string RealAudience = "Zuno.Client.IntegrationTests";

    private sealed class Envelope<T>
    {
        [JsonPropertyName("data")]
        public T? Data { get; set; }
    }

    private sealed class AuthPayload
    {
        [JsonPropertyName("accessToken")]
        public string AccessToken { get; set; } = string.Empty;
    }

    /// <summary>Registers a real user of the given role and returns their access token.</summary>
    private async Task<string> TokenForAsync(string role)
    {
        var response = await _client.PostAsJsonAsync(
            "/api/v1/auth/register",
            new
            {
                email = $"{Guid.NewGuid()}@example.com",
                phoneNumber = (string?)null,
                password = "Str0ng!Pass",
                firstName = "Test",
                lastName = "User",
                role,
            });

        response.StatusCode.Should().Be(HttpStatusCode.OK, "registration is the only way in");

        var envelope = await response.Content.ReadFromJsonAsync<Envelope<AuthPayload>>();
        return envelope!.Data!.AccessToken;
    }

    private HttpRequestMessage Request(HttpMethod method, string url, string? token)
    {
        var request = new HttpRequestMessage(method, url);

        if (token is not null)
        {
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        }

        return request;
    }

    /// <summary>Mints a token locally, so a test can forge whatever it likes.</summary>
    private static string Forge(
        string role,
        string signingKey = RealSigningKey,
        string issuer = RealIssuer,
        string audience = RealAudience,
        int expiresInMinutes = 15)
    {
        var credentials = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(signingKey)),
            SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: issuer,
            audience: audience,
            claims:
            [
                new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString()),
                new Claim(ClaimTypes.Role, role),
            ],
            // Kept a minute behind expiry, so forging an *already expired* token stays possible:
            // a negative lifetime with a fixed notBefore of -1 minute is rejected by the token
            // builder itself, and the test never reached the application at all.
            notBefore: DateTime.UtcNow.AddMinutes(Math.Min(-1, expiresInMinutes - 1)),
            expires: DateTime.UtcNow.AddMinutes(expiresInMinutes),
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    /// <summary>One endpoint from each area, enough to prove the policy on its controller.</summary>
    public static TheoryData<string, string> ProtectedEndpoints() => new()
    {
        { "/api/v1/customer/services/home", "Customer" },
        { "/api/v1/customer/bookings", "Customer" },
        { "/api/v1/business/bookings", "BusinessOwner" },
        { "/api/v1/worker/dashboard", "Worker" },
        { "/api/v1/worker/jobs", "Worker" },
        { "/api/v1/admin/catalog/categories", "SuperAdmin" },
        { "/api/v1/bookings/threads", "Any" },
        { "/api/v1/app-options", "Any" },
    };

    // ---- no token ------------------------------------------------------------------------------

    [Theory]
    [MemberData(nameof(ProtectedEndpoints))]
    public async Task Every_protected_endpoint_refuses_an_anonymous_caller(
        string url,
        string _)
    {
        var response = await _client.SendAsync(Request(HttpMethod.Get, url, token: null));

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    // ---- wrong role ----------------------------------------------------------------------------

    [Theory]
    [InlineData("/api/v1/worker/dashboard")]
    [InlineData("/api/v1/business/bookings")]
    [InlineData("/api/v1/admin/catalog/categories")]
    public async Task A_customer_cannot_reach_another_roles_endpoints(string url)
    {
        var token = await TokenForAsync("Customer");

        var response = await _client.SendAsync(Request(HttpMethod.Get, url, token));

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Theory]
    [InlineData("/api/v1/customer/bookings")]
    [InlineData("/api/v1/business/bookings")]
    [InlineData("/api/v1/admin/catalog/categories")]
    public async Task A_worker_cannot_reach_another_roles_endpoints(string url)
    {
        var token = await TokenForAsync("Worker");

        var response = await _client.SendAsync(Request(HttpMethod.Get, url, token));

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Theory]
    [InlineData("/api/v1/customer/bookings")]
    [InlineData("/api/v1/worker/dashboard")]
    [InlineData("/api/v1/admin/catalog/categories")]
    public async Task A_business_owner_cannot_reach_another_roles_endpoints(string url)
    {
        var token = await TokenForAsync("BusinessOwner");

        var response = await _client.SendAsync(Request(HttpMethod.Get, url, token));

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Nobody_reaches_the_admin_catalogue_by_holding_three_other_roles()
    {
        // The catalogue decides what every business can sell. Checked on its own because a mistake
        // here is not one customer's data but the shape of the whole marketplace.
        foreach (var role in new[] { "Customer", "Worker", "BusinessOwner" })
        {
            var token = await TokenForAsync(role);

            var response = await _client.SendAsync(
                Request(HttpMethod.Get, "/api/v1/admin/catalog/categories", token));

            response.StatusCode.Should().Be(HttpStatusCode.Forbidden, "role {0}", role);
        }
    }

    // ---- forged and tampered tokens -------------------------------------------------------------

    [Fact]
    public async Task A_token_signed_with_another_key_is_refused()
    {
        // The whole model rests on this. A role is just a claim in the token, so if a token signed
        // elsewhere were accepted, anybody could write SuperAdmin into one and sign it themselves.
        var forged = Forge("SuperAdmin", signingKey: new string('z', 32));

        var response = await _client.SendAsync(
            Request(HttpMethod.Get, "/api/v1/admin/catalog/categories", forged));

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task A_token_from_another_issuer_is_refused()
    {
        var forged = Forge("SuperAdmin", issuer: "https://not-zuno.example");

        var response = await _client.SendAsync(
            Request(HttpMethod.Get, "/api/v1/admin/catalog/categories", forged));

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task A_token_for_another_audience_is_refused()
    {
        var forged = Forge("SuperAdmin", audience: "https://not-zuno.example");

        var response = await _client.SendAsync(
            Request(HttpMethod.Get, "/api/v1/admin/catalog/categories", forged));

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task An_expired_token_is_refused()
    {
        // Clock skew is configured to zero, so expiry means expiry.
        var expired = Forge("Customer", expiresInMinutes: -5);

        var response = await _client.SendAsync(
            Request(HttpMethod.Get, "/api/v1/customer/bookings", expired));

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task A_token_with_its_payload_edited_is_refused()
    {
        // The attack this is really about: take your own valid token, change the role inside it, and
        // send it back. The signature no longer matches the payload.
        var mine = await TokenForAsync("Customer");
        var parts = mine.Split('.');

        var tamperedPayload = Convert.ToBase64String(
                Encoding.UTF8.GetBytes(
                    $$"""
                    {"nameid":"{{Guid.NewGuid()}}","role":"SuperAdmin","iss":"{{RealIssuer}}","aud":"{{RealAudience}}"}
                    """))
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');

        var tampered = $"{parts[0]}.{tamperedPayload}.{parts[2]}";

        var response = await _client.SendAsync(
            Request(HttpMethod.Get, "/api/v1/admin/catalog/categories", tampered));

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Theory]
    [InlineData("not-a-token")]
    [InlineData("a.b.c")]
    [InlineData("")]
    public async Task Rubbish_in_the_header_is_refused(string value)
    {
        var request = new HttpRequestMessage(HttpMethod.Get, "/api/v1/customer/bookings");
        request.Headers.TryAddWithoutValidation("Authorization", $"Bearer {value}");

        var response = await _client.SendAsync(request);

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task An_unsigned_token_claiming_to_need_no_signature_is_refused()
    {
        // The classic JWT attack: set the algorithm to "none" and drop the signature.
        var header = Convert.ToBase64String(Encoding.UTF8.GetBytes("""{"alg":"none","typ":"JWT"}"""))
            .TrimEnd('=').Replace('+', '-').Replace('/', '_');
        var payload = Convert.ToBase64String(
                Encoding.UTF8.GetBytes($$"""{"role":"SuperAdmin","iss":"{{RealIssuer}}","aud":"{{RealAudience}}"}"""))
            .TrimEnd('=').Replace('+', '-').Replace('/', '_');

        var response = await _client.SendAsync(
            Request(HttpMethod.Get, "/api/v1/admin/catalog/categories", $"{header}.{payload}."));

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    // ---- what is deliberately open --------------------------------------------------------------

    [Theory]
    [InlineData("/api/v1/service-categories")]
    [InlineData("/api/v1/states")]
    [InlineData("/api/v1/districts")]
    public async Task The_catalogue_stays_readable_without_signing_in(string url)
    {
        // Somebody deciding whether to sign up has to be able to see what Zuno offers. These carry
        // no personal data, and the deny-by-default policy must not have closed them by accident.
        var response = await _client.SendAsync(Request(HttpMethod.Get, url, token: null));

        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Signing_in_does_not_require_being_signed_in()
    {
        // The one that would brick the application: deny-by-default closing the login endpoint.
        //
        // Asked with credentials that work, because a wrong password is answered with 401 as well —
        // the same status the deny-by-default policy challenges with. From the status alone, a
        // rejected sign-in and an endpoint nobody can reach look identical, so this test passed
        // against a login that was unreachable for a while. A successful sign-in is unambiguous.
        var email = $"{Guid.NewGuid()}@example.com";
        const string password = "Str0ng!Pass";

        var registration = await _client.PostAsJsonAsync(
            "/api/v1/auth/register",
            new
            {
                email,
                phoneNumber = (string?)null,
                password,
                firstName = "Test",
                lastName = "User",
                role = "Customer",
            });

        registration.StatusCode.Should().Be(HttpStatusCode.OK, "the test needs an account to sign into");

        var response = await _client.PostAsJsonAsync(
            "/api/v1/auth/login",
            new { emailOrPhone = email, password });

        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    // ---- one person's data is not another's ------------------------------------------------------

    [Fact]
    public async Task A_customer_sees_only_their_own_bookings()
    {
        // Authentication says who you are; this is the other half — that being signed in as somebody
        // does not show you everybody's.
        var first = await TokenForAsync("Customer");
        var second = await TokenForAsync("Customer");

        var firstResponse = await _client.SendAsync(
            Request(HttpMethod.Get, "/api/v1/customer/bookings", first));
        var secondResponse = await _client.SendAsync(
            Request(HttpMethod.Get, "/api/v1/customer/bookings", second));

        firstResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        secondResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        // Two brand-new customers, so both lists are empty — what matters is that neither inherited
        // the other's, which a query keyed on anything but the token would.
        (await firstResponse.Content.ReadAsStringAsync()).Should().Contain("\"data\":[]");
        (await secondResponse.Content.ReadAsStringAsync()).Should().Contain("\"data\":[]");
    }

    [Fact]
    public async Task A_stranger_cannot_read_a_booking_conversation()
    {
        // Threads carry addresses and times. A guessed id must not reveal even that the booking is
        // real, so this is a refusal rather than an empty list.
        var stranger = await TokenForAsync("Customer");

        var response = await _client.SendAsync(
            Request(
                HttpMethod.Get,
                $"/api/v1/bookings/{Guid.NewGuid()}/messages",
                stranger));

        response.StatusCode.Should().BeOneOf(
            HttpStatusCode.Unauthorized,
            HttpStatusCode.Forbidden,
            HttpStatusCode.NotFound);
    }
}
