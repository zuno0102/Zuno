using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.UnitTests;

/// <summary>
/// Before a rent item goes live, Rent asks the business's plan (held by the Service API) with its own
/// live count; and the Service API reads, pauses and resumes a business's items when a plan ends or renews.
/// </summary>
public class PlanGateTests : IDisposable
{
    private readonly TestRent _rent = new();

    public void Dispose() => _rent.Dispose();

    private async Task<Guid> ItemAsync(string name, bool available = true)
    {
        var id = (await _rent.SaveHandlers.Handle(TestRent.Machine(c =>
        {
            c.Name = name;
            c.IsAvailable = available;
        }), default)).Id;
        _rent.Db.ChangeTracker.Clear();
        return id;
    }

    [Fact]
    public async Task A_new_live_item_asks_the_plan_with_the_items_already_live()
    {
        await ItemAsync("Tent");
        await ItemAsync("Chairs");

        _rent.PlanGate.Asked.Should().Equal(0, 1);
    }

    [Fact]
    public async Task A_refused_item_is_not_saved()
    {
        _rent.PlanGate.RefuseWith = "The Basic plan allows 1 live listing in total.";

        var add = () => _rent.SaveHandlers.Handle(TestRent.Machine(c => c.Name = "Tent"), default);

        await add.Should().ThrowAsync<PlanLimitException>().WithMessage("The Basic plan allows 1*");
        (await _rent.Db.RentalItems.CountAsync()).Should().Be(0);
    }

    [Fact]
    public async Task An_item_saved_switched_off_does_not_ask()
    {
        await ItemAsync("Tent", available: false);

        _rent.PlanGate.Asked.Should().BeEmpty();
    }

    [Fact]
    public async Task Switching_an_item_on_asks_but_editing_a_live_one_does_not()
    {
        var live = await ItemAsync("Tent");
        var off = await ItemAsync("Chairs", available: false);
        _rent.PlanGate.Asked.Clear();

        await _rent.SaveHandlers.Handle(TestRent.Edit(live, c => c.Name = "Big tent"), default);
        _rent.Db.ChangeTracker.Clear();
        _rent.PlanGate.Asked.Should().BeEmpty("a business already over the Basic limit can still edit what is up");

        await new UpdateRentalStockCommandHandler(_rent.User, _rent.Db, _rent.PlanGate)
            .Handle(new UpdateRentalStockCommand { Id = off, QuantityOwned = 10, IsAvailable = true }, default);
        _rent.PlanGate.Asked.Should().Equal([1], "the item being switched on is left out of the count");
    }

    [Fact]
    public async Task Switching_on_refused_leaves_the_item_off()
    {
        var off = await ItemAsync("Chairs", available: false);
        _rent.PlanGate.RefuseWith = "Get a plan with Rent to add more.";

        var on = () => new UpdateRentalStockCommandHandler(_rent.User, _rent.Db, _rent.PlanGate)
            .Handle(new UpdateRentalStockCommand { Id = off, QuantityOwned = 10, IsAvailable = true }, default);

        await on.Should().ThrowAsync<PlanLimitException>();
        _rent.Db.ChangeTracker.Clear();
        (await _rent.Db.RentalItems.SingleAsync(i => i.Id == off)).IsAvailable.Should().BeFalse();
    }

    [Fact]
    public async Task The_service_api_reads_pauses_and_resumes_only_that_business_items()
    {
        var first = await ItemAsync("Tent");
        var second = await ItemAsync("Chairs");
        await ItemAsync("Broken stove", available: false);
        _rent.As(TestRent.OwnerB);
        var someoneElse = await ItemAsync("Their tent");
        var internalHandlers = new InternalListingHandlers(_rent.Db);

        (await internalHandlers.Handle(new GetLiveListingsQuery(TestRent.OwnerA), default))
            .Select(l => l.Id).Should().BeEquivalentTo([first, second]);

        await internalHandlers.Handle(new SetListingsLiveCommand(TestRent.OwnerA, [second, someoneElse], Live: false), default);
        _rent.Db.ChangeTracker.Clear();
        (await internalHandlers.Handle(new GetLiveListingsQuery(TestRent.OwnerA), default)).Select(l => l.Id).Should().Equal(first);
        (await _rent.Db.RentalItems.SingleAsync(i => i.Id == someoneElse)).IsAvailable.Should().BeTrue("not that business's item");

        await internalHandlers.Handle(new SetListingsLiveCommand(TestRent.OwnerA, [second], Live: true), default);
        _rent.Db.ChangeTracker.Clear();
        (await internalHandlers.Handle(new GetLiveListingsQuery(TestRent.OwnerA), default)).Should().HaveCount(2);
    }
}
