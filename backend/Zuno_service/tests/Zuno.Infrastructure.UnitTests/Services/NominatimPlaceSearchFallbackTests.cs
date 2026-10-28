using System.Net;
using System.Text;
using FluentAssertions;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging.Abstractions;
using Zuno.Infrastructure.Services;

namespace Zuno.Infrastructure.UnitTests.Services;

/// <summary>
/// Searching for a village the way people type it: "auttukonam, manalikarai" — a hamlet the free map
/// does not know, then the village it is in. The search used to find nothing; now it finds the
/// village and says which part it matched.
/// </summary>
public class NominatimPlaceSearchFallbackTests
{
    private const string ManalikaraiNominatim = """
    [{ "name": "Manalikarai", "display_name": "Manalikarai, Kalkulam, Kanniyakumari, Tamil Nadu, 629166, India",
       "lat": "8.2652", "lon": "77.3108",
       "address": { "village": "Manalikarai", "county": "Kalkulam", "state": "Tamil Nadu", "postcode": "629166" } }]
    """;

    private const string ManalikaraiPhoton = """
    { "features": [{ "geometry": { "coordinates": [77.3108, 8.2652] },
       "properties": { "name": "Manalikarai", "county": "Kalkulam", "state": "Tamil Nadu", "countrycode": "IN" } },
       { "geometry": { "coordinates": [10.0, 50.0] },
       "properties": { "name": "Somewhere abroad", "countrycode": "DE" } }] }
    """;

    /// <summary>Answers by which service and which words were asked; everything else finds nothing.</summary>
    private sealed class Router(Func<string, string?> answer) : HttpMessageHandler
    {
        public List<string> Asked { get; } = [];

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var url = Uri.UnescapeDataString(request.RequestUri!.ToString());
            Asked.Add(url);
            var isPhoton = url.Contains("photon.komoot.io");
            var body = answer(url) ?? (isPhoton ? """{ "features": [] }""" : "[]");
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(body, Encoding.UTF8, "application/json"),
            });
        }
    }

    private static (NominatimPlaceSearchService Service, Router Router) Service(Func<string, string?> answer)
    {
        var router = new Router(answer);
        var client = new HttpClient(router) { BaseAddress = new Uri("https://nominatim.openstreetmap.org") };
        return (new NominatimPlaceSearchService(client, new MemoryCache(new MemoryCacheOptions()), NullLogger<NominatimPlaceSearchService>.Instance), router);
    }

    [Fact]
    public async Task Hamlet_Plus_Village_Finds_The_Village_And_Says_Which_Part_Matched()
    {
        var (service, _) = Service(url =>
            url.Contains("nominatim") && url.Contains("q=manalikarai&") ? ManalikaraiNominatim : null);

        var results = await service.SearchAsync("auttukonam, manalikarai");

        var place = results.Should().ContainSingle().Subject;
        place.Name.Should().Be("Manalikarai");
        place.PostalCode.Should().Be("629166");
        place.MatchedText.Should().Be("manalikarai");
    }

    [Fact]
    public async Task A_Different_Spelling_Is_Found_Through_The_Forgiving_Search()
    {
        var (service, _) = Service(url => url.Contains("photon.komoot.io") && url.Contains("q=manalikkarai") ? ManalikaraiPhoton : null);

        var results = await service.SearchAsync("manalikkarai");

        // The foreign result is dropped; the village is found, and it matched the whole search.
        var place = results.Should().ContainSingle().Subject;
        place.Name.Should().Be("Manalikarai");
        place.Latitude.Should().Be(8.2652);
        place.Longitude.Should().Be(77.3108);
        place.City.Should().Be("Kalkulam");
        place.MatchedText.Should().BeNull();
    }

    [Fact]
    public async Task An_Exact_Match_Asks_Nothing_Further()
    {
        var (service, router) = Service(url => url.Contains("nominatim") ? ManalikaraiNominatim : null);

        await service.SearchAsync("manalikarai");

        router.Asked.Should().ContainSingle(because: "the forgiving and part-by-part searches are only for misses");
    }

    [Fact]
    public async Task Nothing_Anywhere_Is_Still_An_Empty_Answer_Not_An_Error()
    {
        var (service, _) = Service(_ => null);

        (await service.SearchAsync("auttukonam")).Should().BeEmpty();
    }
}
