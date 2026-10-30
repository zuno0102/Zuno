using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Application.Orders;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.UnitTests;

/// <summary>Rent order steps from the transition table, booked stock, counts, and messages with the customer.</summary>
public class RentalOrderManagementTests : IDisposable
{
    private readonly TestRent _rent = new();

    public void Dispose() => _rent.Dispose();

    private ChangeRentalOrderStatusCommandHandler Change => new(_rent.User, _rent.Db);

    private RentalOrderQueryHandlers Queries => new(_rent.User, _rent.Db, _rent.Settings);

    private RentalOrderMessageHandlers Messages => new(_rent.User, _rent.Db, TimeProvider.System, _rent.Settings);

    private async Task<Guid> ChairsAsync(int quantity = 1000) =>
        (await _rent.SaveHandlers.Handle(
            TestRent.Machine(c => { c.Name = "Plastic chair"; c.QuantityOwned = quantity; }), default)).Id;

    private async Task<Guid> OrderAsync(Guid itemId, int quantity, RentalOrderStatus status, string customer = "Rahul", int startInDays = 0)
    {
        var order = new RentalOrder
        {
            RentalItemId = itemId,
            OwnerUserId = TestRent.OwnerA,
            CustomerUserId = Guid.NewGuid(),
            CustomerName = customer,
            Quantity = quantity,
            StartDate = DateTimeOffset.UtcNow.AddDays(startInDays),
            EndDate = DateTimeOffset.UtcNow.AddDays(startInDays + 2),
            DeliveryAddress = "Kakkanad",
            Status = status,
        };
        _rent.Db.RentalOrders.Add(order);
        await _rent.Db.SaveChangesAsync();
        _rent.Db.ChangeTracker.Clear();
        return order.Id;
    }

    private async Task CustomerWritesAsync(Guid orderId, string body)
    {
        _rent.Db.RentalOrderMessages.Add(new RentalOrderMessage
        {
            RentalOrderId = orderId,
            SenderUserId = Guid.NewGuid(),
            SenderRole = RentalMessageSenderRole.Customer,
            Body = body,
        });
        await _rent.Db.SaveChangesAsync();
        _rent.Db.ChangeTracker.Clear();
    }

    private Task<RentalOrderDto> MoveAsync(Guid orderId, string to) =>
        Change.Handle(new ChangeRentalOrderStatusCommand { Id = orderId, ToStatus = to }, default);

    [Fact]
    public async Task A_booked_order_offers_send_out_and_cancel_from_the_table()
    {
        var order = await OrderAsync(await ChairsAsync(), 100, RentalOrderStatus.Booked);

        var dto = await Queries.Handle(new GetRentalOrderQuery { Id = order }, default);

        dto.ItemName.Should().Be("Plastic chair");
        dto.Actions.Select(a => (a.ToStatus, a.Label, a.ConfirmFirst)).Should().Equal(
            ("OnRent", "Send out", false),
            ("Cancelled", "Cancel order", true));
    }

    [Fact]
    public async Task Send_out_then_return_moves_stock_from_booked_to_out_to_in()
    {
        var chairs = await ChairsAsync();
        var order = await OrderAsync(chairs, 300, RentalOrderStatus.Booked);
        var stock = new GetMyRentalStockQueryHandler(_rent.User, _rent.Db, _rent.Settings);

        var line = (await stock.Handle(new GetMyRentalStockQuery(), default)).Items.Single();
        (line.QuantityIn, line.QuantityBooked, line.QuantityOut).Should().Be((1000, 300, 0));

        (await MoveAsync(order, "OnRent")).StatusName.Should().Be("On rent");
        line = (await stock.Handle(new GetMyRentalStockQuery(), default)).Items.Single();
        (line.QuantityIn, line.QuantityBooked, line.QuantityOut).Should().Be((700, 0, 300));

        var returned = await MoveAsync(order, "Returned");
        returned.Actions.Should().BeEmpty("a returned order has no next step");
        line = (await stock.Handle(new GetMyRentalStockQuery(), default)).Items.Single();
        (line.QuantityIn, line.QuantityBooked, line.QuantityOut).Should().Be((1000, 0, 0));
    }

    [Theory]
    [InlineData(RentalOrderStatus.Booked, "Returned")]
    [InlineData(RentalOrderStatus.OnRent, "Booked")]
    [InlineData(RentalOrderStatus.Returned, "OnRent")]
    [InlineData(RentalOrderStatus.Cancelled, "OnRent")]
    public async Task A_step_not_in_the_table_is_refused(RentalOrderStatus from, string to)
    {
        var order = await OrderAsync(await ChairsAsync(), 10, from);

        var act = () => MoveAsync(order, to);

        await act.Should().ThrowAsync<DomainException>();
        (await _rent.Db.RentalOrders.SingleAsync()).Status.Should().Be(from);
    }

    [Fact]
    public async Task Sending_out_more_than_is_in_stock_is_refused()
    {
        var chairs = await ChairsAsync(1000);
        await OrderAsync(chairs, 800, RentalOrderStatus.OnRent);
        var order = await OrderAsync(chairs, 300, RentalOrderStatus.Booked);

        var act = () => MoveAsync(order, "OnRent");

        await act.Should().ThrowAsync<DomainException>().WithMessage("Only 200 Plastic chair in stock*");
    }

    [Fact]
    public async Task Another_business_cannot_see_or_move_an_order()
    {
        var order = await OrderAsync(await ChairsAsync(), 10, RentalOrderStatus.Booked);
        _rent.As(TestRent.OwnerB);

        await ((Func<Task>)(() => MoveAsync(order, "OnRent"))).Should().ThrowAsync<ForbiddenException>();
        await ((Func<Task>)(() => Queries.Handle(new GetRentalOrderQuery { Id = order }, default))).Should().ThrowAsync<ForbiddenException>();
        await ((Func<Task>)(() => Messages.Handle(new GetRentalOrderMessagesQuery { RentalOrderId = order }, default))).Should().ThrowAsync<ForbiddenException>();
        (await Queries.Handle(new GetMyRentalOrdersQuery(), default)).TotalCount.Should().Be(0);
    }

    [Fact]
    public async Task Counts_list_every_status_in_order_and_the_list_filters()
    {
        var chairs = await ChairsAsync();
        await OrderAsync(chairs, 10, RentalOrderStatus.Booked);
        await OrderAsync(chairs, 10, RentalOrderStatus.Booked);
        await OrderAsync(chairs, 10, RentalOrderStatus.OnRent);

        var counts = await Queries.Handle(new GetRentalOrderCountsQuery(), default);

        counts.Select(c => (c.Name, c.Count)).Should().Equal(
            ("Booked", 2), ("On rent", 1), ("Returned", 0), ("Cancelled", 0), ("Awaiting advance", 0));
        (await Queries.Handle(new GetMyRentalOrdersQuery { Status = "Booked" }, default)).TotalCount.Should().Be(2);
        (await Queries.Handle(new GetMyRentalOrdersQuery { Status = "Nonsense" }, default)).TotalCount.Should().Be(0);
    }

    [Fact]
    public async Task Opening_a_conversation_marks_the_customers_messages_read()
    {
        var order = await OrderAsync(await ChairsAsync(), 10, RentalOrderStatus.Booked, customer: "Anu");
        await CustomerWritesAsync(order, "Can you deliver by 9 am?");

        (await Queries.Handle(new GetRentalOrderQuery { Id = order }, default)).UnreadMessages.Should().Be(1);
        (await Messages.Handle(new GetRentalOrderThreadsQuery(), default)).Single().UnreadCount.Should().Be(1);

        var thread = await Messages.Handle(new GetRentalOrderMessagesQuery { RentalOrderId = order }, default);

        thread.Single().Should().BeEquivalentTo(new { SenderRole = "Customer", IsMine = false, SenderName = "Anu", Body = "Can you deliver by 9 am?" });
        (await Queries.Handle(new GetRentalOrderQuery { Id = order }, default)).UnreadMessages.Should().Be(0);
    }

    [Fact]
    public async Task The_business_replies_and_the_thread_shows_it_last()
    {
        var order = await OrderAsync(await ChairsAsync(), 10, RentalOrderStatus.Booked, customer: "Anu");
        await CustomerWritesAsync(order, "Can you deliver by 9 am?");
        await Task.Delay(5);

        var sent = await Messages.Handle(new SendRentalOrderMessageCommand { RentalOrderId = order, Body = "  Yes, 8:30.  " }, default);

        sent.IsMine.Should().BeTrue();
        sent.Body.Should().Be("Yes, 8:30.");
        (await _rent.Db.RentalOrderMessages.SingleAsync(m => m.Id == sent.Id)).SenderUserId.Should().Be(TestRent.OwnerA);
        var thread = (await Messages.Handle(new GetRentalOrderThreadsQuery(), default)).Single();
        thread.LastMessage.Should().Be("Yes, 8:30.");
        thread.LastFromCustomer.Should().BeFalse();
        thread.ItemName.Should().Be("Plastic chair");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task An_empty_message_is_refused(string body)
    {
        var result = await new SendRentalOrderMessageCommandValidator()
            .ValidateAsync(new SendRentalOrderMessageCommand { RentalOrderId = Guid.NewGuid(), Body = body });

        result.IsValid.Should().BeFalse();
    }

    [Fact]
    public async Task A_message_over_1000_characters_is_refused()
    {
        var result = await new SendRentalOrderMessageCommandValidator()
            .ValidateAsync(new SendRentalOrderMessageCommand { RentalOrderId = Guid.NewGuid(), Body = new string('x', 1001) });

        result.IsValid.Should().BeFalse();
    }

    [Theory]
    [InlineData("OnRent", true)]
    [InlineData("onrent", true)]
    [InlineData("2", false)]
    [InlineData("Lost", false)]
    [InlineData("", false)]
    public async Task The_target_status_must_be_a_known_name(string to, bool valid)
    {
        var result = await new ChangeRentalOrderStatusCommandValidator()
            .ValidateAsync(new ChangeRentalOrderStatusCommand { Id = Guid.NewGuid(), ToStatus = to });

        result.IsValid.Should().Be(valid);
    }
}
