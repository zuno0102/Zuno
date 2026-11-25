using System.Net;
using System.Text;
using FluentAssertions;
using Microsoft.Extensions.Options;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Domain.Enums;
using Zuno.Infrastructure.Services;

namespace Zuno.Infrastructure.UnitTests.Services;

/// <summary>
/// The Service API reading a business's listings from Rent and Marketplace: a server waking from
/// sleep is waited for; the key travels with every call; nothing set up is unavailable.
/// </summary>
public class AreaListingsClientTests
{
    private sealed class ScriptedHandler(params Func<HttpResponseMessage>[] answers) : HttpMessageHandler
    {
        private int _next;

        public List<HttpRequestMessage> Seen { get; } = [];

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Seen.Add(request);
            return Task.FromResult(answers[Math.Min(_next++, answers.Length - 1)]());
        }
    }

    private static HttpResponseMessage Live(Guid id) => new(HttpStatusCode.OK)
    {
        Content = new StringContent(
            $$"""{"success":true,"data":[{"id":"{{id}}","createdDate":"2026-11-20T10:00:00+00:00"}]}""",
            Encoding.UTF8,
            "application/json"),
    };

    private static AreaListingsClient Client(ScriptedHandler handler, string key = "test-key", string rentUrl = "http://rent.test")
    {
        var factory = new Mock<IHttpClientFactory>();
        factory.Setup(f => f.CreateClient(It.IsAny<string>()))
            .Returns(() => new HttpClient(handler, disposeHandler: false) { BaseAddress = new Uri(rentUrl + "/") });
        return new AreaListingsClient(
            factory.Object,
            Options.Create(new RentApiSettings { BaseUrl = rentUrl }),
            Options.Create(new MarketplaceApiSettings { BaseUrl = "http://market.test" }),
            Options.Create(new InternalApiSettings { Key = key }));
    }

    [Fact]
    public async Task A_server_waking_from_sleep_is_waited_for()
    {
        var id = Guid.NewGuid();
        var handler = new ScriptedHandler(
            () => new HttpResponseMessage(HttpStatusCode.ServiceUnavailable),
            () => new HttpResponseMessage(HttpStatusCode.BadGateway),
            () => Live(id));

        var live = await Client(handler).LiveAsync(ListingArea.Rent, Guid.NewGuid(), CancellationToken.None);

        live.Select(l => l.Id).Should().Equal(id);
        handler.Seen.Should().HaveCount(3);
        handler.Seen.Should().OnlyContain(r => r.Headers.GetValues(InternalApiSettings.HeaderName).Single() == "test-key");
    }

    [Fact]
    public async Task A_refusal_is_not_retried()
    {
        var handler = new ScriptedHandler(() => new HttpResponseMessage(HttpStatusCode.NotFound));

        var read = () => Client(handler).LiveAsync(ListingArea.Rent, Guid.NewGuid(), CancellationToken.None);

        await read.Should().ThrowAsync<AreaUnavailableException>();
        handler.Seen.Should().HaveCount(1, "a wrong key is answered 404, which waiting does not change");
    }

    [Fact]
    public async Task Without_a_key_or_an_address_the_area_is_unavailable_and_nothing_is_sent()
    {
        var handler = new ScriptedHandler(() => Live(Guid.NewGuid()));

        var noKey = () => Client(handler, key: "").LiveAsync(ListingArea.Rent, Guid.NewGuid(), CancellationToken.None);
        var noAddress = () => Client(handler, rentUrl: "").LiveAsync(ListingArea.Rent, Guid.NewGuid(), CancellationToken.None);

        await noKey.Should().ThrowAsync<AreaUnavailableException>();
        await noAddress.Should().ThrowAsync<AreaUnavailableException>();
        handler.Seen.Should().BeEmpty();
    }
}
