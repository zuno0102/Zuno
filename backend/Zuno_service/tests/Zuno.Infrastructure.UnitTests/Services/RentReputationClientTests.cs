using System.Net;
using System.Text;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Settings;
using Zuno.Infrastructure.Services;

namespace Zuno.Infrastructure.UnitTests.Services;

/// <summary>
/// Reading each business's Rent record: both answer shapes, bad rows skipped, and every failure
/// reported as "unknown" so the stored figures are kept.
/// </summary>
public class RentReputationClientTests
{
    private const string Owner = "6f1c2a8e-3d4b-4c5a-9e7f-112233445566";

    private static readonly string Enveloped = $$"""
    { "success": true, "data": { "items": [
        { "ownerUserId": "{{Owner}}", "ratingSum": 12.0, "ratingCount": 3, "successfulOrders": 4 } ] } }
    """;

    private sealed class Answer(Func<HttpResponseMessage> respond) : HttpMessageHandler
    {
        public int Calls { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(respond());
        }
    }

    private static (RentReputationClient Client, Answer Handler) Client(
        Func<HttpResponseMessage> respond, string baseUrl = "http://localhost:5057/")
    {
        var handler = new Answer(respond);
        var http = new HttpClient(handler) { BaseAddress = new Uri("http://localhost:5057/") };
        var settings = Options.Create(new RentApiSettings { BaseUrl = baseUrl });
        return (new RentReputationClient(http, settings, NullLogger<RentReputationClient>.Instance), handler);
    }

    private static HttpResponseMessage Json(string body, HttpStatusCode status = HttpStatusCode.OK) =>
        new(status) { Content = new StringContent(body, Encoding.UTF8, "application/json") };

    [Fact]
    public void Parse_ReadsItemsInsideTheEnvelope()
    {
        var rows = RentReputationClient.Parse(Enveloped);

        rows.Should().ContainSingle().Which.Should().Be(
            new Application.Common.Interfaces.RentReputation(Guid.Parse(Owner), 12m, 3, 4));
    }

    [Fact]
    public void Parse_ReadsTopLevelItems_AnyCase()
    {
        var rows = RentReputationClient.Parse($$"""
        { "Items": [ { "OwnerUserId": "{{Owner}}", "RatingSum": 9.5, "RatingCount": 2, "SuccessfulOrders": 1 } ] }
        """);

        rows.Should().ContainSingle().Which.RatingSum.Should().Be(9.5m);
    }

    [Fact]
    public void Parse_SkipsRowsItCannotTrust()
    {
        var rows = RentReputationClient.Parse($$"""
        { "data": { "items": [
            { "ownerUserId": "not-a-guid", "ratingSum": 5, "ratingCount": 1, "successfulOrders": 1 },
            { "ratingSum": 5, "ratingCount": 1, "successfulOrders": 1 },
            { "ownerUserId": "{{Owner}}", "ratingSum": -5, "ratingCount": 1, "successfulOrders": 1 },
            { "ownerUserId": "{{Owner}}", "ratingSum": "x", "ratingCount": 1, "successfulOrders": 1 },
            "junk",
            { "ownerUserId": "{{Owner}}", "ratingCount": 0 }
        ] } }
        """);

        // Only the last survives; its missing figures read as none.
        rows.Should().ContainSingle().Which.Should().Be(
            new Application.Common.Interfaces.RentReputation(Guid.Parse(Owner), 0m, 0, 0));
    }

    [Theory]
    [InlineData("""{ "success": true, "data": {} }""")]
    [InlineData("""{ "items": 5 }""")]
    [InlineData("""[ 1, 2 ]""")]
    public void Parse_WithoutAnItemsList_IsNull(string json) => RentReputationClient.Parse(json).Should().BeNull();

    [Fact]
    public void Parse_AnEmptyList_IsAnEmptyList() =>
        RentReputationClient.Parse("""{ "data": { "items": [] } }""").Should().BeEmpty();

    [Fact]
    public async Task GetAll_ReadsTheAnswer()
    {
        var (client, _) = Client(() => Json(Enveloped));

        var rows = await client.GetAllAsync(default);

        rows.Should().ContainSingle().Which.SuccessfulOrders.Should().Be(4);
    }

    [Theory]
    [InlineData(HttpStatusCode.InternalServerError)]
    [InlineData(HttpStatusCode.ServiceUnavailable)]
    [InlineData(HttpStatusCode.NotFound)]
    public async Task GetAll_WhenRentAnswersAnError_IsNull(HttpStatusCode status)
    {
        var (client, _) = Client(() => Json("{}", status));

        (await client.GetAllAsync(default)).Should().BeNull();
    }

    [Fact]
    public async Task GetAll_WhenRentAnswersNonsense_IsNull()
    {
        var (client, _) = Client(() => Json("<html>asleep</html>"));

        (await client.GetAllAsync(default)).Should().BeNull();
    }

    [Fact]
    public async Task GetAll_WhenRentIsUnreachable_IsNull()
    {
        var (client, _) = Client(() => throw new HttpRequestException("connection refused"));

        (await client.GetAllAsync(default)).Should().BeNull();
    }

    [Fact]
    public async Task GetAll_WhenRentTimesOut_IsNull()
    {
        var (client, _) = Client(() => throw new TaskCanceledException("timed out"));

        (await client.GetAllAsync(default)).Should().BeNull();
    }

    [Fact]
    public async Task GetAll_WhenNotConfigured_IsNull_WithoutCallingAnything()
    {
        var (client, handler) = Client(() => Json(Enveloped), baseUrl: " ");

        (await client.GetAllAsync(default)).Should().BeNull();
        handler.Calls.Should().Be(0);
    }

    [Fact]
    public async Task GetAll_WhenTheCallerCancels_Throws()
    {
        using var cancelled = new CancellationTokenSource();
        await cancelled.CancelAsync();
        var (client, _) = Client(() => throw new TaskCanceledException());

        var act = () => client.GetAllAsync(cancelled.Token);

        await act.Should().ThrowAsync<OperationCanceledException>();
    }
}
