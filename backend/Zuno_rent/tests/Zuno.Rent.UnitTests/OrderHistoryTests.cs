using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Orders;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.UnitTests;

/// <summary>
/// Scenario 1 as a record: B books 300, they go out, 200 more are added, those go out, everything
/// comes back — every step kept with its time and pieces, and never edited.
/// </summary>
public class OrderHistoryTests : IDisposable
{
    private readonly TestRent _rent = new();

    public void Dispose() => _rent.Dispose();

    private RentalOrderCreateHandlers Create => new(_rent.User, _rent.Db, TimeProvider.System);

    private ChangeRentalOrderStatusCommandHandler Change => new(_rent.User, _rent.Db);

    private GetRentalOrderHistoryQueryHandler History => new(_rent.User, _rent.Db);

    private async Task<Guid> ChairsAsync() =>
        (await _rent.SaveHandlers.Handle(
            TestRent.Machine(c => { c.Name = "Plastic chair"; c.QuantityOwned = 2000; }), default)).Id;

    private CreateRentalOrderCommand Book(Guid item, int quantity) => new()
    {
        RentalItemId = item,
        Quantity = quantity,
        StartDate = DateTimeOffset.UtcNow.AddHours(1),
        EndDate = DateTimeOffset.UtcNow.AddDays(3),
        CustomerName = "B",
        DeliveryAddress = "Kakkanad",
    };

    private Task Move(Guid order, string to) =>
        Change.Handle(new ChangeRentalOrderStatusCommand { Id = order, ToStatus = to }, default);

    /// <summary>Takes everything due in cash — an order is returned only once it is paid.</summary>
    private async Task PayAll(Guid order)
    {
        var due = (await new RentalOrderQueryHandlers(_rent.User, _rent.Db, _rent.Settings)
            .Handle(new GetRentalOrderQuery { Id = order }, default)).Balance;
        await new RentalPaymentHandlers(_rent.User, _rent.Db, new FakePaymentGateway(), TimeProvider.System)
            .Handle(new RecordRentalPaymentCommand { Id = order, Method = "Cash", Amount = due }, default);
    }

    [Fact]
    public async Task Scenario_1_keeps_every_step_of_300_then_200_extra()
    {
        var chairs = await ChairsAsync();
        var b = await Create.Handle(Book(chairs, 300), default);
        await Move(b.Id, "OnRent");
        var extra = await Create.Handle(new AddRentalOrderAddOnCommand { ParentOrderId = b.Id, Quantity = 200 }, default);
        await Move(extra.Id, "OnRent");
        await PayAll(b.Id);
        await Move(b.Id, "Returned");
        await PayAll(extra.Id);
        await Move(extra.Id, "Returned");

        var history = await History.Handle(new GetRentalOrderHistoryQuery { RentalOrderId = b.Id }, default);

        history.Select(h => (h.Title, h.Quantity, h.OnAddOn)).Should().Equal(
            ("Booked", 300, false),
            ("On rent", 300, false),
            ("Booked", 200, true),
            ("Extra pieces added", 200, false),
            ("On rent", 200, true),
            ("Payment received", 300, false),
            ("Returned", 300, false),
            ("Payment received", 200, true),
            ("Returned", 200, true));
        history.Single(h => h.Title == "Extra pieces added").RelatedOrderId.Should().Be(extra.Id);
        history.Should().BeInAscendingOrder(h => h.At);

        // Both orders stay as they were made: 300 and 200, never merged into 500.
        (await _rent.Db.RentalOrders.SingleAsync(o => o.Id == b.Id)).Quantity.Should().Be(300);
        (await _rent.Db.RentalOrders.SingleAsync(o => o.Id == extra.Id)).Quantity.Should().Be(200);
    }

    [Fact]
    public async Task An_add_on_shows_its_own_steps_only()
    {
        var chairs = await ChairsAsync();
        var b = await Create.Handle(Book(chairs, 300), default);
        var extra = await Create.Handle(new AddRentalOrderAddOnCommand { ParentOrderId = b.Id, Quantity = 200 }, default);

        var history = await History.Handle(new GetRentalOrderHistoryQuery { RentalOrderId = extra.Id }, default);

        history.Should().ContainSingle().Which.Should().BeEquivalentTo(new { Title = "Booked", Quantity = 200, OnAddOn = false });
    }

    [Fact]
    public async Task A_cancelled_order_records_the_cancel()
    {
        var chairs = await ChairsAsync();
        var b = await Create.Handle(Book(chairs, 50), default);
        await Move(b.Id, "Cancelled");

        var history = await History.Handle(new GetRentalOrderHistoryQuery { RentalOrderId = b.Id }, default);

        history.Select(h => h.Title).Should().Equal("Booked", "Cancelled");
        history.Last().Tone.Should().Be("waiting");
    }

    [Fact]
    public async Task History_cannot_be_edited_or_removed()
    {
        var chairs = await ChairsAsync();
        await Create.Handle(Book(chairs, 300), default);
        var step = await _rent.Db.RentalOrderEvents.SingleAsync();

        step.Quantity = 500;
        var edit = () => _rent.Db.SaveChangesAsync();
        await edit.Should().ThrowAsync<InvalidOperationException>();
        _rent.Db.ChangeTracker.Clear();

        _rent.Db.RentalOrderEvents.Remove(await _rent.Db.RentalOrderEvents.SingleAsync());
        var remove = () => _rent.Db.SaveChangesAsync();
        await remove.Should().ThrowAsync<InvalidOperationException>();
    }

    [Fact]
    public async Task Another_business_cannot_read_the_history()
    {
        var chairs = await ChairsAsync();
        var b = await Create.Handle(Book(chairs, 10), default);
        _rent.As(TestRent.OwnerB);

        var act = () => History.Handle(new GetRentalOrderHistoryQuery { RentalOrderId = b.Id }, default);

        await act.Should().ThrowAsync<ForbiddenException>();
    }
}
