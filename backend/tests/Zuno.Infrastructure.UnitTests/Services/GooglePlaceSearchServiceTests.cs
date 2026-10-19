using System.Net;
using System.Text;
using FluentAssertions;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging.Abstractions;
using Zuno.Infrastructure.Services;

namespace Zuno.Infrastructure.UnitTests.Services;

/// <summary>
/// Google's answers turned into the address fields a form has — checked against the shapes Google
/// actually returns, so no key or network is needed.
/// </summary>
public class GooglePlaceSearchServiceTests
{
    private sealed class CannedHandler(HttpStatusCode status, string body) : HttpMessageHandler
    {
        public List<HttpRequestMessage> Requests { get; } = [];

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Requests.Add(request);
            return Task.FromResult(new HttpResponseMessage(status)
            {
                Content = new StringContent(body, Encoding.UTF8, "application/json"),
            });
        }
    }

    private static (GooglePlaceSearchService Service, CannedHandler Handler) Service(string body, HttpStatusCode status = HttpStatusCode.OK)
    {
        var handler = new CannedHandler(status, body);
        var service = new GooglePlaceSearchService(
            new HttpClient(handler),
            new MemoryCache(new MemoryCacheOptions()),
            "test-key",
            NullLogger<GooglePlaceSearchService>.Instance);
        return (service, handler);
    }

    private const string TextSearchBody = """
    {
      "places": [{
        "displayName": { "text": "M.K. Auditorium" },
        "formattedAddress": "Verkilambi - Meycode Rd, Verkilambi, Tamil Nadu 629175, India",
        "location": { "latitude": 8.29812, "longitude": 77.27341 },
        "addressComponents": [
          { "longText": "Verkilambi - Meycode Road", "types": ["route"] },
          { "longText": "Verkilambi", "types": ["locality", "political"] },
          { "longText": "Kanniyakumari", "types": ["administrative_area_level_3", "political"] },
          { "longText": "Tamil Nadu", "types": ["administrative_area_level_1", "political"] },
          { "longText": "629175", "types": ["postal_code"] }
        ]
      }]
    }
    """;

    [Fact]
    public async Task Search_Finds_A_Local_Landmark_With_Its_Address_Parts()
    {
        var (service, handler) = Service(TextSearchBody);

        var results = await service.SearchAsync("M.K. Auditorium Verkilambi");

        var place = results.Should().ContainSingle().Subject;
        place.Name.Should().Be("M.K. Auditorium");
        place.Latitude.Should().Be(8.29812);
        place.Street.Should().Be("Verkilambi - Meycode Road");
        place.City.Should().Be("Verkilambi");
        place.State.Should().Be("Tamil Nadu");
        place.PostalCode.Should().Be("629175");

        var request = handler.Requests.Single();
        request.Headers.GetValues("X-Goog-Api-Key").Should().Equal("test-key");
        request.RequestUri!.Host.Should().Be("places.googleapis.com");
    }

    [Fact]
    public async Task Search_Is_Cached_So_The_Same_Words_Are_Paid_For_Once()
    {
        var (service, handler) = Service(TextSearchBody);

        await service.SearchAsync("Verkilambi");
        await service.SearchAsync("  verkilambi ");

        handler.Requests.Should().HaveCount(1);
    }

    [Fact]
    public async Task Search_Shorter_Than_Three_Letters_Asks_Nothing()
    {
        var (service, handler) = Service(TextSearchBody);

        (await service.SearchAsync("ve")).Should().BeEmpty();
        handler.Requests.Should().BeEmpty();
    }

    [Fact]
    public async Task Search_Refused_By_Google_Answers_Nothing_Found_Rather_Than_Failing()
    {
        var (service, _) = Service("""{ "error": { "status": "PERMISSION_DENIED" } }""", HttpStatusCode.Forbidden);

        (await service.SearchAsync("Verkilambi")).Should().BeEmpty();
    }

    [Fact]
    public async Task Reverse_Names_A_Pinned_House_And_Keeps_The_Callers_Point()
    {
        var (service, handler) = Service("""
        {
          "status": "OK",
          "results": [{
            "formatted_address": "14/2, Swamiyarmadam Rd, Verkilambi, Kalkulam, Tamil Nadu 629175, India",
            "address_components": [
              { "long_name": "Swamiyarmadam Road", "types": ["route"] },
              { "long_name": "Verkilambi", "types": ["sublocality_level_1", "sublocality", "political"] },
              { "long_name": "Kalkulam", "types": ["locality", "political"] },
              { "long_name": "Tamil Nadu", "types": ["administrative_area_level_1", "political"] },
              { "long_name": "629175", "types": ["postal_code"] }
            ]
          }]
        }
        """);

        var place = await service.ReverseAsync(8.298765, 77.270123, precise: true);

        place.Should().NotBeNull();
        place!.Latitude.Should().Be(8.298765);
        place.Name.Should().Be("Swamiyarmadam Road");
        place.Street.Should().Be("Swamiyarmadam Road");
        place.Locality.Should().Be("Verkilambi");
        place.City.Should().Be("Kalkulam");
        place.PostalCode.Should().Be("629175");
        handler.Requests.Single().RequestUri!.ToString().Should().Contain("latlng=8.298765,77.270123");
    }

    [Fact]
    public async Task Reverse_Over_The_Sea_Is_Simply_Unnamed()
    {
        var (service, _) = Service("""{ "status": "ZERO_RESULTS", "results": [] }""");

        (await service.ReverseAsync(5.0, 75.0)).Should().BeNull();
    }
}
