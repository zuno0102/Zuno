using FluentAssertions;
using Zuno.Application.Modules.Catalog.Commands;

namespace Zuno.Application.UnitTests.Modules.Catalog;

/// <summary>
/// The name an app owner types, turned into the handle stored beside it.
/// </summary>
/// <remarks>
/// Worth its own tests because the first version split on a list of known separators and passed
/// everything else straight through — so a category named "!!!" produced the slug "!!!" and was
/// accepted. An empty result is the signal the handler refuses on, so anything that quietly
/// returns non-empty for junk defeats that check.
/// </remarks>
public class CatalogSlugTests
{
    [Theory]
    // The shapes the seeded rows already have, so an app-owner-added row is indistinguishable.
    [InlineData("Cleaning", "cleaning")]
    [InlineData("Acrylic painting", "acrylic-painting")]
    [InlineData("Sofa & carpet cleaning", "sofa-carpet-cleaning")]
    [InlineData("Beauty & Wellness", "beauty-wellness")]
    [InlineData("Wedding catering", "wedding-catering")]
    public void Should_Match_The_Shape_Of_The_Seeded_Slugs(string name, string expected) =>
        CatalogSlug.From(name).Should().Be(expected);

    [Theory]
    [InlineData("  House warming  ", "house-warming")]
    [InlineData("Tap  &  mixer   repair", "tap-mixer-repair")]
    [InlineData("A/C & fridge repair", "a-c-fridge-repair")]
    [InlineData("Catering (events)", "catering-events")]
    [InlineData("--Painting--", "painting")]
    public void Should_Collapse_Runs_Of_Punctuation_And_Never_Trail_A_Hyphen(
        string name, string expected) =>
        CatalogSlug.From(name).Should().Be(expected);

    [Fact]
    public void Should_Keep_Digits() =>
        CatalogSlug.From("Catering 2026").Should().Be("catering-2026");

    [Theory]
    [InlineData("!!!")]
    [InlineData("   ")]
    [InlineData("")]
    [InlineData("---")]
    [InlineData("&&&")]
    [InlineData("...")]
    public void Should_Be_Empty_For_A_Name_With_Nothing_Usable_In_It(string name) =>
        // The handler refuses on empty. This is the assertion that stops "!!!" becoming a category.
        CatalogSlug.From(name).Should().BeEmpty();
}
