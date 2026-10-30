using FluentAssertions;
using Zuno.Rent.Application.Items;

namespace Zuno.Rent.UnitTests;

/// <summary>The counts behind the business home screen's Rent tiles, and the list filter they open.</summary>
public class SummaryTests : IDisposable
{
    private readonly TestRent _rent = new();

    public void Dispose() => _rent.Dispose();

    private GetMyRentalSummaryQueryHandler Summary => new(_rent.User, _rent.Db);

    private GetMyRentalItemsQueryHandler List => new(_rent.User, _rent.Db, _rent.Settings);

    private async Task SeedAsync()
    {
        await _rent.SaveHandlers.Handle(TestRent.Machine(), default);
        await _rent.SaveHandlers.Handle(
            TestRent.Machine(c => { c.Name = "Plastic chair"; c.QuantityOwned = 200; }), default);
        await _rent.SaveHandlers.Handle(
            TestRent.Machine(c => { c.Name = "Generator"; c.QuantityOwned = 2; c.IsAvailable = false; }), default);
    }

    [Fact]
    public async Task No_items_is_all_zero()
    {
        var summary = await Summary.Handle(new GetMyRentalSummaryQuery(), default);

        summary.Should().BeEquivalentTo(new RentalSummaryDto());
    }

    [Fact]
    public async Task Counts_items_and_the_pieces_that_can_be_rented_now()
    {
        await SeedAsync();

        var summary = await Summary.Handle(new GetMyRentalSummaryQuery(), default);

        summary.TotalItems.Should().Be(3);
        summary.AvailableItems.Should().Be(2);
        summary.UnavailableItems.Should().Be(1);
        summary.UnitsAvailable.Should().Be(201, "1 machine and 200 chairs; the switched-off generators do not count");
    }

    [Fact]
    public async Task Another_business_sees_only_its_own_counts()
    {
        await SeedAsync();
        _rent.As(TestRent.OwnerB);

        (await Summary.Handle(new GetMyRentalSummaryQuery(), default)).TotalItems.Should().Be(0);
    }

    [Fact]
    public async Task Deleted_items_are_not_counted()
    {
        await SeedAsync();
        var chair = (await List.Handle(new GetMyRentalItemsQuery(), default)).Items.Single(i => i.Name == "Plastic chair");
        await new DeleteRentalItemCommandHandler(_rent.User, _rent.Db).Handle(new DeleteRentalItemCommand { Id = chair.Id }, default);

        var summary = await Summary.Handle(new GetMyRentalSummaryQuery(), default);

        summary.TotalItems.Should().Be(2);
        summary.UnitsAvailable.Should().Be(1);
    }

    [Theory]
    [InlineData(true, new[] { "Plastic chair", "Cutting machine" })]
    [InlineData(false, new[] { "Generator" })]
    [InlineData(null, new[] { "Generator", "Plastic chair", "Cutting machine" })]
    public async Task The_list_filters_by_availability(bool? isAvailable, string[] expected)
    {
        await SeedAsync();

        var page = await List.Handle(new GetMyRentalItemsQuery { IsAvailable = isAvailable }, default);

        page.Items.Select(i => i.Name).Should().BeEquivalentTo(expected);
        page.TotalCount.Should().Be(expected.Length);
    }
}
