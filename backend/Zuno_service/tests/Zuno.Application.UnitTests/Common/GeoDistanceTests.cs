using FluentAssertions;
using Zuno.Application.Common;
using Xunit;

namespace Zuno.Application.UnitTests.Common;

/// <summary>
/// The distance arithmetic the whole nearby-jobs feature rests on.
/// </summary>
/// <remarks>
/// Checked against real Kerala places rather than synthetic numbers, because a transposed latitude or
/// a degrees/radians slip still produces plausible-looking output — it just puts every job in the
/// wrong place. Known landmarks are the only assertion that catches that.
/// </remarks>
public class GeoDistanceTests
{
    // Coordinates as seeded in DistrictCentroidData.
    private const double TrivandrumLat = 8.5241, TrivandrumLon = 76.9366;
    private const double KollamLat = 8.8932, KollamLon = 76.6141;
    private const double KochiLat = 9.9816, KochiLon = 76.2999;

    // Kazhakoottam is inside Thiruvananthapuram district — the case a district centre cannot express,
    // and the reason posts carry their own coordinates.
    private const double KazhakoottamLat = 8.5686, KazhakoottamLon = 76.8742;

    [Theory]
    // Straight-line, which is shorter than the road. The user quoted 15 / 65 / 200 km by road for
    // these three; the ratio runs about 1.13 to 1.8, which is why the app offers coarse radius steps
    // rather than inviting an argument about a single kilometre.
    [InlineData(KazhakoottamLat, KazhakoottamLon, 8.3)]
    [InlineData(KollamLat, KollamLon, 54.1)]
    [InlineData(KochiLat, KochiLon, 176.5)]
    public void Measures_real_distances_from_Trivandrum(double lat, double lon, double expectedKm)
    {
        var actual = GeoDistance.HaversineKm(TrivandrumLat, TrivandrumLon, lat, lon);

        actual.Should().BeApproximately(expectedKm, 2.0);
    }

    [Fact]
    public void A_point_is_no_distance_from_itself()
    {
        GeoDistance.HaversineKm(TrivandrumLat, TrivandrumLon, TrivandrumLat, TrivandrumLon)
            .Should().Be(0);
    }

    [Fact]
    public void Distance_does_not_depend_on_direction()
    {
        var there = GeoDistance.HaversineKm(TrivandrumLat, TrivandrumLon, KochiLat, KochiLon);
        var back = GeoDistance.HaversineKm(KochiLat, KochiLon, TrivandrumLat, TrivandrumLon);

        back.Should().BeApproximately(there, 0.001);
    }

    [Fact]
    public void Latitude_alone_is_about_111km_per_degree()
    {
        // The sanity check on the formula's scale. One degree north, nothing east.
        GeoDistance.HaversineKm(8.0, 76.0, 9.0, 76.0).Should().BeApproximately(111.2, 0.5);
    }

    public class TheBoundingBox
    {
        [Fact]
        public void Is_wider_in_longitude_than_in_latitude()
        {
            // True everywhere in India, because a degree of longitude is shorter than a degree of
            // latitude once away from the equator. If this ever inverts, the cosine has been dropped.
            var box = GeoDistance.BoundingBox(TrivandrumLat, TrivandrumLon, 50);

            var latitudeSpan = box.MaxLatitude - box.MinLatitude;
            var longitudeSpan = box.MaxLongitude - box.MinLongitude;

            longitudeSpan.Should().BeGreaterThan(latitudeSpan);
        }

        [Fact]
        public void Contains_everything_inside_the_radius()
        {
            // The property that makes the two-step search correct: the box may be generous, but it
            // must never omit a point the radius includes, or that job is lost.
            var box = GeoDistance.BoundingBox(TrivandrumLat, TrivandrumLon, 60);

            ((double)box.MinLatitude).Should().BeLessThan(KollamLat);
            ((double)box.MaxLatitude).Should().BeGreaterThan(KollamLat);
            ((double)box.MinLongitude).Should().BeLessThan(KollamLon);
            ((double)box.MaxLongitude).Should().BeGreaterThan(KollamLon);
        }

        [Fact]
        public void Admits_corners_that_are_beyond_the_radius()
        {
            // States the reason the in-memory step is not optional. The corner of a box around a
            // 15km circle is about 21km out, so a box-only filter would silently widen the search.
            var box = GeoDistance.BoundingBox(TrivandrumLat, TrivandrumLon, 15);

            var cornerDistance = GeoDistance.HaversineKm(
                TrivandrumLat,
                TrivandrumLon,
                (double)box.MaxLatitude,
                (double)box.MaxLongitude);

            cornerDistance.Should().BeGreaterThan(15);
            cornerDistance.Should().BeApproximately(21.2, 1.0);
        }

        [Fact]
        public void Never_leaves_the_valid_range()
        {
            var box = GeoDistance.BoundingBox(8.5, 76.9, 500);

            ((double)box.MinLatitude).Should().BeGreaterThanOrEqualTo(-90);
            ((double)box.MaxLatitude).Should().BeLessThanOrEqualTo(90);
            ((double)box.MinLongitude).Should().BeGreaterThanOrEqualTo(-180);
            ((double)box.MaxLongitude).Should().BeLessThanOrEqualTo(180);
        }

        [Fact]
        public void Survives_a_coordinate_at_the_pole()
        {
            // Unreachable for an Indian app, so this exists for the case that does happen: a latitude
            // and longitude transposed on write, or a spoofed fix. Dividing by a cosine near zero
            // would otherwise give an infinite span.
            var box = GeoDistance.BoundingBox(90, 0, 25);

            box.MinLongitude.Should().Be(-180);
            box.MaxLongitude.Should().Be(180);
        }
    }
}
