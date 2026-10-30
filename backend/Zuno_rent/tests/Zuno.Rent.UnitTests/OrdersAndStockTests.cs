using FluentAssertions;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.UnitTests;

/// <summary>In, out and total per item, and the orders that say where the pieces went.</summary>
public class OrdersAndStockTests : IDisposable
{
    private readonly TestRent _rent = new();

    public void Dispose() => _rent.Dispose();

    private GetMyRentalStockQueryHandler Stock => new(_rent.User, _rent.Db, _rent.Settings);

    private GetRentalItemOrdersQueryHandler Orders => new(_rent.User, _rent.Db, _rent.Settings);

    private async Task<Guid> ChairsAsync(int quantity = 1000)
    {
        var dto = await _rent.SaveHandlers.Handle(
            TestRent.Machine(c => { c.Name = "Plastic chair"; c.QuantityOwned = quantity; }), default);
        return dto.Id;
    }

    private async Task OrderAsync(Guid itemId, int quantity, RentalOrderStatus status, int startInDays = 0, string customer = "Rahul")
    {
        _rent.Db.RentalOrders.Add(new RentalOrder
        {
            RentalItemId = itemId,
            OwnerUserId = TestRent.OwnerA,
            CustomerUserId = Guid.NewGuid(),
            CustomerName = customer,
            Quantity = quantity,
            StartDate = DateTimeOffset.UtcNow.AddDays(startInDays),
            EndDate = DateTimeOffset.UtcNow.AddDays(startInDays + 2),
            DeliveryAddress = "St. Mary's Hall, Kakkanad",
            DistrictId = TestRent.Ernakulam,
            Status = status,
        });
        await _rent.Db.SaveChangesAsync();
        _rent.Db.ChangeTracker.Clear();
    }

    [Fact]
    public async Task Only_pieces_on_rent_are_out()
    {
        var chairs = await ChairsAsync();
        await OrderAsync(chairs, 200, RentalOrderStatus.OnRent);
        await OrderAsync(chairs, 100, RentalOrderStatus.OnRent);
        await OrderAsync(chairs, 50, RentalOrderStatus.Booked);
        await OrderAsync(chairs, 40, RentalOrderStatus.Returned);
        await OrderAsync(chairs, 30, RentalOrderStatus.Cancelled);

        var row = (await Stock.Handle(new GetMyRentalStockQuery(), default)).Items.Single();

        row.Name.Should().Be("Plastic chair");
        row.QuantityTotal.Should().Be(1000);
        row.QuantityOut.Should().Be(300);
        row.QuantityIn.Should().Be(700);
    }

    [Fact]
    public async Task An_item_with_no_orders_is_all_in()
    {
        await ChairsAsync(50);

        var row = (await Stock.Handle(new GetMyRentalStockQuery(), default)).Items.Single();

        (row.QuantityIn, row.QuantityOut, row.QuantityTotal).Should().Be((50, 0, 50));
    }

    [Fact]
    public async Task Stock_is_only_the_callers_items_sorted_by_name()
    {
        await _rent.SaveHandlers.Handle(TestRent.Machine(c => c.Name = "Sheet"), default);
        await _rent.SaveHandlers.Handle(TestRent.Machine(c => c.Name = "Bench"), default);
        _rent.As(TestRent.OwnerB);
        await _rent.SaveHandlers.Handle(TestRent.Machine(c => c.Name = "Other business"), default);
        _rent.As(TestRent.OwnerA);

        var page = await Stock.Handle(new GetMyRentalStockQuery(), default);

        page.Items.Select(i => i.Name).Should().Equal("Bench", "Sheet");
        page.TotalCount.Should().Be(2);
    }

    [Fact]
    public async Task Quantity_cannot_go_below_what_is_out()
    {
        var chairs = await ChairsAsync();
        await OrderAsync(chairs, 300, RentalOrderStatus.OnRent);

        var quick = () => new UpdateRentalStockCommandHandler(_rent.User, _rent.Db)
            .Handle(new UpdateRentalStockCommand { Id = chairs, QuantityOwned = 299, IsAvailable = true }, default);
        await quick.Should().ThrowAsync<DomainException>().WithMessage("300 are out*");
        _rent.Db.ChangeTracker.Clear();

        var full = () => _rent.SaveHandlers.Handle(
            TestRent.Edit(chairs, c => { c.Name = "Plastic chair"; c.QuantityOwned = 100; }), default);
        await full.Should().ThrowAsync<DomainException>();
        _rent.Db.ChangeTracker.Clear();

        var ok = await new UpdateRentalStockCommandHandler(_rent.User, _rent.Db)
            .Handle(new UpdateRentalStockCommand { Id = chairs, QuantityOwned = 300, IsAvailable = true }, default);
        ok.QuantityOwned.Should().Be(300, "exactly what is out is allowed");
    }

    [Fact]
    public async Task Orders_list_where_the_pieces_went_newest_first_with_status_names()
    {
        var chairs = await ChairsAsync();
        await OrderAsync(chairs, 200, RentalOrderStatus.Returned, startInDays: -10, customer: "Anu");
        await OrderAsync(chairs, 300, RentalOrderStatus.OnRent, startInDays: 0, customer: "Rahul");
        await OrderAsync(chairs, 100, RentalOrderStatus.Booked, startInDays: 5, customer: "Joseph");

        var page = await Orders.Handle(new GetRentalItemOrdersQuery { RentalItemId = chairs }, default);

        page.Items.Select(o => o.CustomerName).Should().Equal("Joseph", "Rahul", "Anu");
        var onRent = page.Items[1];
        onRent.Quantity.Should().Be(300);
        onRent.StatusName.Should().Be("On rent");
        onRent.StatusTone.Should().Be("danger");
        onRent.IsOut.Should().BeTrue();
        onRent.DeliveryAddress.Should().Be("St. Mary's Hall, Kakkanad");
        onRent.DistrictName.Should().Be("Ernakulam");
        page.Items[2].IsOut.Should().BeFalse();
    }

    [Fact]
    public async Task Another_business_cannot_read_an_items_orders()
    {
        var chairs = await ChairsAsync();
        await OrderAsync(chairs, 10, RentalOrderStatus.OnRent);
        _rent.As(TestRent.OwnerB);

        var act = () => Orders.Handle(new GetRentalItemOrdersQuery { RentalItemId = chairs }, default);
        await act.Should().ThrowAsync<ForbiddenException>();

        var missing = () => Orders.Handle(new GetRentalItemOrdersQuery { RentalItemId = Guid.NewGuid() }, default);
        await missing.Should().ThrowAsync<EntityNotFoundException>();
    }

    [Fact]
    public async Task A_status_marked_out_in_the_table_changes_out_stock()
    {
        var chairs = await ChairsAsync();
        await OrderAsync(chairs, 50, RentalOrderStatus.Booked);
        var booked = _rent.Db.RentalOrderStatuses.Single(s => s.Code == RentalOrderStatus.Booked);
        booked.CountsAsOut = true;
        await _rent.Db.SaveChangesAsync();

        (await Stock.Handle(new GetMyRentalStockQuery(), default)).Items.Single().QuantityOut.Should().Be(50);
    }
}
