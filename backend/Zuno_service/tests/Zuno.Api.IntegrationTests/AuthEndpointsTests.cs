using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using FluentAssertions;
using Zuno.Application.Modules.Authentication.DTOs;

namespace Zuno.Api.IntegrationTests;

public class AuthEndpointsTests(ZunoApiFactory factory) : IClassFixture<ZunoApiFactory>
{
    private readonly HttpClient _client = factory.CreateClient();

    private static object RegisterPayload(string email) => new
    {
        email,
        phoneNumber = (string?)null,
        password = "Str0ng!Pass",
        firstName = "Asha",
        lastName = "Rao",
        role = "Customer",
    };

    private sealed class Envelope<T>
    {
        [JsonPropertyName("data")]
        public T? Data { get; set; }
    }

    private static async Task<T?> UnwrapAsync<T>(HttpResponseMessage response)
    {
        var envelope = await response.Content.ReadFromJsonAsync<Envelope<T>>();
        return envelope is null ? default : envelope.Data;
    }

    [Fact]
    public async Task Register_Then_Login_Then_Refresh_Should_Succeed()
    {
        var email = $"{Guid.NewGuid()}@example.com";

        var registerResponse = await _client.PostAsJsonAsync("/api/v1/auth/register", RegisterPayload(email));
        registerResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        var registerBody = await UnwrapAsync<AuthResponseDto>(registerResponse);
        registerBody.Should().NotBeNull();
        registerBody!.User.Email.Should().Be(email);

        var loginResponse = await _client.PostAsJsonAsync("/api/v1/auth/login", new
        {
            emailOrPhone = email,
            password = "Str0ng!Pass",
        });
        loginResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        var loginBody = await UnwrapAsync<AuthResponseDto>(loginResponse);
        loginBody.Should().NotBeNull();

        var meRequest = new HttpRequestMessage(HttpMethod.Get, "/api/v1/auth/me");
        meRequest.Headers.Add("Authorization", $"Bearer {loginBody!.AccessToken}");
        var meResponse = await _client.SendAsync(meRequest);
        meResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        var refreshResponse = await _client.PostAsJsonAsync("/api/v1/auth/refresh-token", new
        {
            refreshToken = loginBody.RefreshToken,
        });
        refreshResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        var refreshBody = await UnwrapAsync<AuthResponseDto>(refreshResponse);
        refreshBody.Should().NotBeNull();
        refreshBody!.RefreshToken.Should().NotBe(loginBody.RefreshToken);
    }

    [Fact]
    public async Task Reusing_A_Rotated_Refresh_Token_Should_Revoke_The_Whole_Chain()
    {
        var email = $"{Guid.NewGuid()}@example.com";
        await _client.PostAsJsonAsync("/api/v1/auth/register", RegisterPayload(email));

        var loginResponse = await _client.PostAsJsonAsync("/api/v1/auth/login", new
        {
            emailOrPhone = email,
            password = "Str0ng!Pass",
        });
        var loginBody = await UnwrapAsync<AuthResponseDto>(loginResponse);

        // First refresh — rotates the token, the original becomes revoked.
        var firstRefresh = await _client.PostAsJsonAsync("/api/v1/auth/refresh-token", new
        {
            refreshToken = loginBody!.RefreshToken,
        });
        firstRefresh.StatusCode.Should().Be(HttpStatusCode.OK);

        // Replaying the original (now-rotated) refresh token should be rejected.
        var replay = await _client.PostAsJsonAsync("/api/v1/auth/refresh-token", new
        {
            refreshToken = loginBody.RefreshToken,
        });
        replay.StatusCode.Should().Be(HttpStatusCode.Unauthorized);

        // The reuse-detection should have also revoked the token issued by the first refresh.
        var firstRefreshBody = await UnwrapAsync<AuthResponseDto>(firstRefresh);
        var secondRefresh = await _client.PostAsJsonAsync("/api/v1/auth/refresh-token", new
        {
            refreshToken = firstRefreshBody!.RefreshToken,
        });
        secondRefresh.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Login_With_Wrong_Password_Should_Return_Unauthorized()
    {
        var email = $"{Guid.NewGuid()}@example.com";
        await _client.PostAsJsonAsync("/api/v1/auth/register", RegisterPayload(email));

        var response = await _client.PostAsJsonAsync("/api/v1/auth/login", new
        {
            emailOrPhone = email,
            password = "WrongPassword1!",
        });

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Register_With_Weak_Password_Should_Return_BadRequest()
    {
        var email = $"{Guid.NewGuid()}@example.com";

        var response = await _client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email,
            phoneNumber = (string?)null,
            password = "weak",
            firstName = "Asha",
            lastName = "Rao",
            role = "Customer",
        });

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }
}
