using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Application.Orders;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.UnitTests;

/// <summary>
/// The two scenarios the business raised: booking more than the dates leave (A 1000 + B 700 of 2000,
/// so C can have 300, not 500), and a customer who needs more after delivery (B gets 300, then 200
/// more as a linked add-on).
/// </summary>
public class AvailabilityAndAddOnTests : IDisposable
{
    private static readonly DateTimeOffset Nov1 = new(2026, 11, 1, 0, 0, 0, TimeSpan.FromHours(5.5));
    private static readonly DateTimeOffset Nov3 = Nov1.AddDays(2);

    private readonly TestRent _rent = new();

    public void Dispose() => _rent.Dispose();

    private RentalOrderCreateHandlers Create => new(_rent.User, _rent.Db, new FixedClock(Nov1.AddDays(-5)));

    private async Task<Guid> ChairsAsync(int quantity = 2000, bool available = true) =>
        (await _rent.SaveHandlers.Handle(
            TestRent.Machine(c => { c.Name = "Plastic chair"; c.QuantityOwned = quantity; c.IsAvailable = available; }), default)).Id;

    private static CreateRentalOrderCommand Book(Guid item, int quantity, DateTimeOffset? start = null, DateTimeOffset? end = null, string customer = "C") => new()
    {
        RentalItemId = item,
        Quantity = quantity,
        StartDate = start ?? Nov1,
        EndDate = end ?? Nov3,
        CustomerName = customer,
        DeliveryAddress = "Kakkanad",
    };

    private Task<RentalAvailabilityDtoView> AvailableAsync(Guid item, DateTimeOffset? start = null, DateTimeOffset? end = null) =>
        Create.Handle(new GetRentalAvailabilityQuery { RentalItemId = item, StartDate = start ?? Nov1, EndDate = end ?? Nov3 }, default)
            .ContinueWith(t => new RentalAvailabilityDtoView(t.Result.Total, t.Result.Held, t.Result.Available));

    private sealed record RentalAvailabilityDtoView(int Total, int Held, int Available);

    [Fact]
    public async Task Scenario_2_only_300_left_so_500_is_refused_and_300_is_taken()
    {
        var chairs = await ChairsAsync(2000);
        await Create.Handle(Book(chairs, 1000, customer: "A"), default);
        await Create.Handle(Book(chairs, 700, Nov1.AddDays(1), Nov3.AddDays(1), customer: "B"), default);

        (await AvailableAsync(chairs)).Should().Be(new RentalAvailabilityDtoView(2000, 1700, 300));

        var tooMany = () => Create.Handle(Book(chairs, 500, customer: "C"), default);
        await tooMany.Should().ThrowAsync<DomainException>().WithMessage("Only 300 Plastic chair available for 1 Nov – 3 Nov*");

        (await Create.Handle(Book(chairs, 300, customer: "C"), default)).StatusName.Should().Be("Booked");
        (await AvailableAsync(chairs)).Available.Should().Be(0);
        await ((Func<Task>)(() => Create.Handle(Book(chairs, 1, customer: "D"), default)))
            .Should().ThrowAsync<DomainException>().WithMessage("Only 0*");
    }

    [Fact]
    public async Task Orders_on_other_dates_do_not_count()
    {
        var chairs = await ChairsAsync(2000);
        await Create.Handle(Book(chairs, 2000, customer: "Weekend 1"), default);

        (await AvailableAsync(chairs, Nov1.AddDays(7), Nov3.AddDays(7))).Available.Should().Be(2000);
        (await AvailableAsync(chairs, Nov3, Nov3.AddDays(1))).Available.Should().Be(2000, "a rental ending as another starts does not overlap");
        (await AvailableAsync(chairs, Nov3.AddHours(-1), Nov3.AddDays(1))).Available.Should().Be(0);
    }

    [Theory]
    [InlineData(RentalOrderStatus.Returned)]
    [InlineData(RentalOrderStatus.Cancelled)]
    public async Task Finished_orders_free_their_pieces(RentalOrderStatus status)
    {
        var chairs = await ChairsAsync(2000);
        var order = await Create.Handle(Book(chairs, 1500), default);
        var entity = await _rent.Db.RentalOrders.SingleAsync(o => o.Id == order.Id);
        entity.Status = status;
        await _rent.Db.SaveChangesAsync();

        (await AvailableAsync(chairs)).Available.Should().Be(2000);
    }

    [Fact]
    public async Task A_switched_off_item_has_nothing_to_book()
    {
        var chairs = await ChairsAsync(2000, available: false);

        (await AvailableAsync(chairs)).Available.Should().Be(0);
        await ((Func<Task>)(() => Create.Handle(Book(chairs, 1), default)))
            .Should().ThrowAsync<DomainException>().WithMessage("*switched off*");
    }

    [Fact]
    public async Task Scenario_1_B_gets_200_more_after_delivery_as_a_linked_add_on()
    {
        var chairs = await ChairsAsync(2000);
        await Create.Handle(Book(chairs, 500, customer: "A"), default);
        var b = await Create.Handle(Book(chairs, 300, customer: "B"), default);
        await new ChangeRentalOrderStatusCommandHandler(_rent.User, _rent.Db, TimeProvider.System)
            .Handle(new ChangeRentalOrderStatusCommand { Id = b.Id, ToStatus = "OnRent" }, default);

        var addOn = await Create.Handle(new AddRentalOrderAddOnCommand { ParentOrderId = b.Id, Quantity = 200 }, default);

        addOn.ParentOrderId.Should().Be(b.Id);
        addOn.CustomerName.Should().Be("B");
        addOn.StatusName.Should().Be("Booked");
        addOn.Quantity.Should().Be(200);
        addOn.EndDate.Should().Be(Nov3, "the extra pieces go back with the first ones");

        var parent = await new RentalOrderQueryHandlers(_rent.User, _rent.Db, _rent.Settings)
            .Handle(new GetRentalOrderQuery { Id = b.Id }, default);
        parent.AddOns.Should().ContainSingle(a => a.Quantity == 200 && a.StatusName == "Booked");

        var stock = (await new GetMyRentalStockQueryHandler(_rent.User, _rent.Db, _rent.Settings)
            .Handle(new GetMyRentalStockQuery(), default)).Items.Single();
        (stock.QuantityOut, stock.QuantityBooked).Should().Be((300, 700), "B's 300 are out; A's 500 and B's extra 200 are booked");
    }

    [Fact]
    public async Task An_add_on_beyond_what_is_left_is_refused()
    {
        var chairs = await ChairsAsync(1000);
        var b = await Create.Handle(Book(chairs, 900, customer: "B"), default);

        var act = () => Create.Handle(new AddRentalOrderAddOnCommand { ParentOrderId = b.Id, Quantity = 200 }, default);

        await act.Should().ThrowAsync<DomainException>().WithMessage("Only 100*");
    }

    [Theory]
    [InlineData(RentalOrderStatus.Returned)]
    [InlineData(RentalOrderStatus.Cancelled)]
    public async Task No_add_on_on_a_finished_order(RentalOrderStatus status)
    {
        var chairs = await ChairsAsync();
        var b = await Create.Handle(Book(chairs, 10), default);
        var entity = await _rent.Db.RentalOrders.SingleAsync(o => o.Id == b.Id);
        entity.Status = status;
        await _rent.Db.SaveChangesAsync();

        var act = () => Create.Handle(new AddRentalOrderAddOnCommand { ParentOrderId = b.Id, Quantity = 1 }, default);

        await act.Should().ThrowAsync<DomainException>().WithMessage("*finished*");
    }

    [Fact]
    public async Task Another_business_cannot_book_check_or_add_to_my_items()
    {
        var chairs = await ChairsAsync();
        var b = await Create.Handle(Book(chairs, 10), default);
        _rent.As(TestRent.OwnerB);

        await ((Func<Task>)(() => Create.Handle(Book(chairs, 1), default))).Should().ThrowAsync<ForbiddenException>();
        await ((Func<Task>)(() => AvailableAsync(chairs))).Should().ThrowAsync<ForbiddenException>();
        await ((Func<Task>)(() => Create.Handle(new AddRentalOrderAddOnCommand { ParentOrderId = b.Id, Quantity = 1 }, default)))
            .Should().ThrowAsync<ForbiddenException>();
    }

    public static TheoryData<Action<CreateRentalOrderCommand>> BadOrders => new()
    {
        c => c.Quantity = 0,
        c => c.EndDate = c.StartDate,
        c => c.EndDate = c.StartDate.AddDays(-1),
        c => { c.StartDate = Nov1.AddDays(-30); c.EndDate = Nov1.AddDays(-28); },
        c => c.EndDate = c.StartDate.AddDays(400),
        c => c.CustomerName = "  ",
        c => c.CustomerName = new string('x', 201),
        c => c.DeliveryAddress = "",
        c => c.DeliveryAddress = new string('x', 501),
        c => c.CustomerPhone = "call me",
        c => c.DistrictId = Guid.NewGuid(),
    };

    [Theory]
    [MemberData(nameof(BadOrders))]
    public async Task Bad_order_fields_are_refused(Action<CreateRentalOrderCommand> breakIt)
    {
        var command = Book(Guid.NewGuid(), 5);
        breakIt(command);

        var result = await new CreateRentalOrderCommandValidator(_rent.Db, _rent.Settings, new FixedClock(Nov1.AddDays(-5)))
            .ValidateAsync(command);

        result.IsValid.Should().BeFalse();
    }

    [Fact]
    public async Task A_good_order_passes_validation()
    {
        var result = await new CreateRentalOrderCommandValidator(_rent.Db, _rent.Settings, new FixedClock(Nov1.AddDays(-5)))
            .ValidateAsync(Book(Guid.NewGuid(), 5));

        result.IsValid.Should().BeTrue(string.Join("; ", result.Errors));
    }

    private sealed class FixedClock(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now.ToUniversalTime();
    }
}
