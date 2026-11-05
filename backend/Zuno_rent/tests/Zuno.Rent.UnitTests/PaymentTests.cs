using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Customer;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Application.Orders;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.UnitTests;

/// <summary>
/// Money on rent orders: the price, the advance an item asks (fixed or per piece), taking it online
/// in the app or as cash / UPI QR offline, part payments, nothing returned until paid, holds that
/// lapse, and refunds — every payment a line in a record that is never edited.
/// </summary>
public class PaymentTests : IDisposable
{
    private static readonly Guid Customer = Guid.NewGuid();

    private readonly TestRent _rent = new();
    private readonly FakePaymentGateway _gateway = new();

    public void Dispose() => _rent.Dispose();

    private RentalOrderCreateHandlers Create => new(_rent.User, _rent.Db, TimeProvider.System);

    private RentalPaymentHandlers Payments => new(_rent.User, _rent.Db, _gateway, TimeProvider.System);

    private RentalOrderQueryHandlers Queries => new(_rent.User, _rent.Db, _rent.Settings);

    private readonly Directory _directory = new();

    private RentalPaymentSettingsHandler Settings => new(_rent.User, _rent.Db, _directory, TimeProvider.System);

    private CustomerRentalOrderHandlers CustomerOrders => new(_rent.User, _rent.Db, _directory, _rent.Settings, TimeProvider.System);

    private ChangeRentalOrderStatusCommandHandler Change => new(_rent.User, _rent.Db, TimeProvider.System);

    /// <summary>Tomorrow 00:00 to the day after, 23:59 — two days, as the app sends them.</summary>
    private static (DateTimeOffset Start, DateTimeOffset End) TwoDays()
    {
        var start = new DateTimeOffset(DateTime.UtcNow.Date.AddDays(1), TimeSpan.Zero);
        return (start, start.AddDays(2).AddMinutes(-1));
    }

    /// <summary>Chairs at ₹10 a day, with the advance asked, listed by business A.</summary>
    private async Task<Guid> ChairsAsync(string advanceType = "None", decimal? advance = null, int quantity = 2000)
    {
        _rent.As(TestRent.OwnerA);
        var id = (await _rent.SaveHandlers.Handle(TestRent.Machine(c =>
        {
            c.Name = "Plastic chair";
            c.Price = 10;
            c.QuantityOwned = quantity;
            c.AdvanceType = advanceType;
            c.AdvanceAmount = advance;
        }), default)).Id;
        _rent.Db.ChangeTracker.Clear();
        return id;
    }

    private Task<RentalOrderDto> OfflineAsync(Guid item, int quantity, string? advanceMethod = null, decimal? advanceAmount = null, bool? received = null)
    {
        _rent.As(TestRent.OwnerA);
        var (start, end) = TwoDays();
        return Create.Handle(new CreateRentalOrderCommand
        {
            RentalItemId = item,
            Quantity = quantity,
            StartDate = start,
            EndDate = end,
            CustomerName = "Anu",
            DeliveryAddress = "Kakkanad",
            AdvanceMethod = advanceMethod,
            AdvanceAmount = advanceAmount,
            // Left out, the server reads a method given as the money taken at the counter.
            AdvanceReceived = received,
        }, default);
    }

    private async Task<RentalOrderDto> BookInAppAsync(Guid item, int quantity)
    {
        var business = await _rent.Db.RentalBusinesses.FirstOrDefaultAsync(b => b.OwnerUserId == TestRent.OwnerA);
        if (business is null)
        {
            _rent.Db.RentalBusinesses.Add(new RentalBusiness { OwnerUserId = TestRent.OwnerA, Name = "Joy Rentals", IsVerified = true });
        }
        else
        {
            business.IsVerified = true;
        }

        await _rent.Db.SaveChangesAsync();
        _rent.As(Customer);
        var (start, end) = TwoDays();
        return await CustomerOrders.Handle(new BookRentalCommand
        {
            RentalItemId = item,
            Quantity = quantity,
            StartDate = start,
            EndDate = end,
            DeliveryAddress = "St. Mary's Hall",
            DistrictId = TestRent.Ernakulam,
        }, default);
    }

    private Task<RentalOrderDto> CollectAsync(Guid order, decimal amount, string method = "UpiQr", bool refund = false)
    {
        _rent.As(TestRent.OwnerA);
        return Payments.Handle(new RecordRentalPaymentCommand { Id = order, Method = method, Amount = amount, IsRefund = refund }, default);
    }

    private Task<RentalOrderDto> ReadAsync(Guid order)
    {
        _rent.As(TestRent.OwnerA);
        return Queries.Handle(new GetRentalOrderQuery { Id = order }, default);
    }

    private Task<RentalOrderDto> MoveAsync(Guid order, string to, string? refundMode = null)
    {
        _rent.As(TestRent.OwnerA);
        return Change.Handle(new ChangeRentalOrderStatusCommand { Id = order, ToStatus = to, RefundMode = refundMode }, default);
    }

    [Theory]
    [InlineData(RentalPriceType.Daily, 0, 23, 59, 1)]
    [InlineData(RentalPriceType.Daily, 2, 23, 59, 3)]
    [InlineData(RentalPriceType.Hourly, 0, 2, 30, 3)]
    [InlineData(RentalPriceType.Fixed, 5, 0, 0, 1)]
    public void The_rate_charges_whole_days_or_hours_and_never_less_than_one(
        RentalPriceType type, int days, int hours, int minutes, int units)
    {
        var start = new DateTimeOffset(2026, 11, 1, 0, 0, 0, TimeSpan.Zero);
        var end = start.AddDays(days).AddHours(hours).AddMinutes(minutes);

        RentalCharge.Units(type, start, end).Should().Be(units);
    }

    [Theory]
    [InlineData(RentalAdvanceType.None, null, 100, 2000, 0)]
    [InlineData(RentalAdvanceType.PerOrder, 500, 100, 2000, 500)]
    [InlineData(RentalAdvanceType.PerPiece, 2, 300, 6000, 600)]
    [InlineData(RentalAdvanceType.PerOrder, 5000, 10, 2000, 2000)]
    public void The_advance_is_fixed_or_per_piece_and_never_more_than_the_order(
        RentalAdvanceType type, int? amount, int quantity, int orderAmount, int expected)
    {
        RentalCharge.Advance(type, amount, quantity, orderAmount).Should().Be(expected);
    }

    [Fact]
    public async Task An_item_keeps_its_advance_and_no_advance_clears_the_amount()
    {
        var id = await ChairsAsync("PerPiece", 2);
        (await _rent.Db.RentalItems.SingleAsync(i => i.Id == id)).AdvanceAmount.Should().Be(2);

        _rent.As(TestRent.OwnerA);
        var saved = await _rent.SaveHandlers.Handle(TestRent.Edit(id, c => { c.AdvanceType = "None"; c.AdvanceAmount = 99; }), default);

        saved.AdvanceType.Should().Be("None");
        saved.AdvanceAmount.Should().BeNull();
    }

    [Fact]
    public async Task An_advance_without_an_amount_or_of_an_unknown_kind_is_refused()
    {
        var validator = new CreateRentalItemCommandValidator(_rent.Db, _rent.Settings);

        (await validator.ValidateAsync(TestRent.Machine(c => c.AdvanceType = "PerOrder"))).Errors
            .Should().Contain(e => e.ErrorMessage.Contains("advance amount"));
        (await validator.ValidateAsync(TestRent.Machine(c => c.AdvanceType = "Sometimes"))).IsValid.Should().BeFalse();
        (await validator.ValidateAsync(TestRent.Machine(c => { c.AdvanceType = "PerPiece"; c.AdvanceAmount = 2; }))).IsValid
            .Should().BeTrue();
    }

    [Fact]
    public async Task An_order_is_priced_rate_times_pieces_times_days()
    {
        var order = await OfflineAsync(await ChairsAsync(), 100);

        order.Units.Should().Be(2);
        order.Amount.Should().Be(2000);
        order.Balance.Should().Be(2000);
        order.PaymentStatus.Should().Be("Unpaid");
    }

    [Fact]
    public async Task An_offline_order_takes_the_items_advance_and_says_how_it_was_paid()
    {
        var chairs = await ChairsAsync("PerOrder", 500);

        var noMethod = () => OfflineAsync(chairs, 100, received: true);
        await noMethod.Should().ThrowAsync<DomainException>().WithMessage("*asks an advance of ₹500*");
        (await _rent.Db.RentalOrders.CountAsync()).Should().Be(0);

        var order = await OfflineAsync(chairs, 100, "Cash");

        order.AdvanceDue.Should().Be(500);
        order.Paid.Should().Be(500);
        order.Balance.Should().Be(1500);
        order.PaymentStatus.Should().Be("AdvancePaid");
        order.PaymentStatusName.Should().Be("Advance paid");
        order.Payments.Single().MethodName.Should().Be("Cash");
        var history = await new GetRentalOrderHistoryQueryHandler(_rent.User, _rent.Db)
            .Handle(new GetRentalOrderHistoryQuery { RentalOrderId = order.Id }, default);
        history.Last().Should().Match<RentalOrderEventDto>(h => h.Title == "Advance paid" && h.Amount == 500 && h.PaymentMethodName == "Cash");
    }

    [Fact]
    public async Task An_offline_order_whose_advance_is_not_in_hand_is_still_confirmed()
    {
        var chairs = await ChairsAsync("PerOrder", 300);

        var order = await OfflineAsync(chairs, 100, "UpiQr", received: false);

        order.Status.Should().Be("Booked", "an offline order is the business's own word, confirmed at once");
        order.HoldUntil.Should().BeNull("nothing lapses on an offline order");
        order.AdvanceDue.Should().Be(300);
        order.Paid.Should().Be(0, "nothing is recorded until the money is in hand");
        order.Balance.Should().Be(order.Amount, "the whole amount is still due");
        order.CanCollect.Should().BeTrue("the advance is collected from the order later");
        order.Payments.Should().BeEmpty();
        (await _rent.Db.RentalOrderPayments.CountAsync()).Should().Be(0);
    }

    [Theory]
    [InlineData("Cash", "Booked", 300)]
    [InlineData(null, "Booked", 0)]
    public async Task An_app_from_before_the_received_choice_keeps_its_old_meaning(string? method, string status, decimal paid)
    {
        // An older app sends no "received" answer: a method said means the advance was taken.
        var chairs = await ChairsAsync("PerOrder", 300);

        var order = await OfflineAsync(chairs, 100, method, received: null);

        order.Status.Should().Be(status);
        order.Paid.Should().Be(paid);
    }

    [Fact]
    public async Task An_offline_advance_collected_later_is_recorded_on_the_confirmed_order()
    {
        var chairs = await ChairsAsync("PerOrder", 300);
        var order = await OfflineAsync(chairs, 100, received: false);

        var paid = await Payments.Handle(
            new RecordRentalPaymentCommand { Id = order.Id, Method = "UpiQr", Amount = 300 }, default);

        paid.Status.Should().Be("Booked");
        paid.Paid.Should().Be(300);
        paid.Balance.Should().Be(order.Amount - 300);
    }

    [Fact]
    public async Task An_offline_order_left_unpaid_is_never_let_go_by_the_advance_lapse()
    {
        var chairs = await ChairsAsync("PerOrder", 300);
        var order = await OfflineAsync(chairs, 100, received: false);

        (await Payments.Handle(new LapseRentalAdvancesCommand(), default)).Should().Be(0);
        (await ReadAsync(order.Id)).Status.Should().Be("Booked");
    }

    [Fact]
    public async Task An_offline_advance_can_be_typed_even_when_the_item_asks_none()
    {
        var chairs = await ChairsAsync();

        var noMethod = () => OfflineAsync(chairs, 100, advanceAmount: 300, received: true);
        await noMethod.Should().ThrowAsync<DomainException>().WithMessage("Say how the advance of ₹300 was paid*");

        var order = await OfflineAsync(chairs, 100, "UpiQr", 300);

        order.AdvanceDue.Should().Be(300);
        order.Paid.Should().Be(300);
        order.Balance.Should().Be(1700);
        order.Payments.Single().MethodName.Should().Be("UPI QR");
    }

    [Fact]
    public async Task A_typed_advance_is_never_below_what_the_item_asks_nor_above_the_total()
    {
        var chairs = await ChairsAsync("PerOrder", 500);

        var tooLittle = () => OfflineAsync(chairs, 100, "Cash", 400);
        await tooLittle.Should().ThrowAsync<DomainException>().WithMessage("*at least ₹500*");
        var tooMuch = () => OfflineAsync(chairs, 100, "Cash", 2500);
        await tooMuch.Should().ThrowAsync<DomainException>().WithMessage("*total of ₹2,000*");
        (await _rent.Db.RentalOrders.CountAsync()).Should().Be(0);

        var more = await OfflineAsync(chairs, 100, "Cash", 800);
        more.AdvanceDue.Should().Be(800);
        more.Balance.Should().Be(1200);
    }

    [Fact]
    public async Task A_typed_advance_of_zero_takes_none_and_needs_no_method()
    {
        var order = await OfflineAsync(await ChairsAsync(), 100, advanceAmount: 0);

        order.AdvanceDue.Should().Be(0);
        order.Payments.Should().BeEmpty();
        order.PaymentStatus.Should().Be("Unpaid");
    }

    [Theory]
    [InlineData(-1)]
    [InlineData(10.555)]
    public async Task A_typed_advance_below_zero_or_past_paise_is_refused(double amount)
    {
        var validator = new CreateRentalOrderCommandValidator(_rent.Db, _rent.Settings, TimeProvider.System);
        var (start, end) = TwoDays();

        var result = await validator.ValidateAsync(new CreateRentalOrderCommand
        {
            RentalItemId = Guid.NewGuid(),
            Quantity = 1,
            StartDate = start,
            EndDate = end,
            CustomerName = "Anu",
            DeliveryAddress = "Kakkanad",
            AdvanceAmount = (decimal)amount,
        });

        result.Errors.Should().Contain(e => e.PropertyName == "AdvanceAmount");
    }

    [Fact]
    public async Task Online_is_never_recorded_by_hand()
    {
        var chairs = await ChairsAsync("PerOrder", 500);

        var online = () => OfflineAsync(chairs, 100, "Online");
        await online.Should().ThrowAsync<DomainException>();

        var order = await OfflineAsync(await ChairsAsync(), 10);
        var byHand = () => CollectAsync(order.Id, 50, "Online");
        await byHand.Should().ThrowAsync<DomainException>().WithMessage("*recorded by the app*");
    }

    [Fact]
    public async Task Mark_returned_waits_until_everything_is_paid()
    {
        var order = await OfflineAsync(await ChairsAsync("PerOrder", 500), 100, "UpiQr");
        await MoveAsync(order.Id, "OnRent");

        var onRent = await ReadAsync(order.Id);
        onRent.Actions.Single().DisabledReason.Should().Be("Collect ₹1,500 first");
        var early = () => MoveAsync(order.Id, "Returned");
        await early.Should().ThrowAsync<DomainException>().WithMessage("₹1,500 is still due*");

        var paid = await CollectAsync(order.Id, 1500);
        paid.PaymentStatus.Should().Be("Paid");
        paid.Actions.Single().DisabledReason.Should().BeNull();

        var returned = await MoveAsync(order.Id, "Returned");
        returned.Status.Should().Be("Returned");
        returned.Paid.Should().Be(2000);
    }

    [Fact]
    public async Task Part_payments_add_up_and_more_than_is_due_is_refused()
    {
        var order = await OfflineAsync(await ChairsAsync(), 100);

        (await CollectAsync(order.Id, 500, "Cash")).PaymentStatus.Should().Be("PartPaid");
        (await CollectAsync(order.Id, 1000)).Balance.Should().Be(500);

        var tooMuch = () => CollectAsync(order.Id, 600);
        await tooMuch.Should().ThrowAsync<DomainException>().WithMessage("Only ₹500 is due*");

        var last = await CollectAsync(order.Id, 500);
        last.PaymentStatus.Should().Be("Paid");
        last.Payments.Select(p => p.Amount).Should().Equal(500, 1000, 500);
        last.CanCollect.Should().BeFalse();
    }

    [Fact]
    public async Task An_app_booking_with_an_advance_waits_for_it_then_books()
    {
        var chairs = await ChairsAsync("PerPiece", 2);

        var booked = await BookInAppAsync(chairs, 300);
        booked.Status.Should().Be("AwaitingAdvance");
        booked.PaymentStatus.Should().Be("AdvanceDue");
        booked.HoldUntil.Should().BeAfter(DateTimeOffset.UtcNow);
        booked.PayNowAmount.Should().Be(600);
        booked.Actions.Select(a => a.Label).Should().Equal("Cancel order");

        var checkout = await Payments.Handle(new StartRentalPaymentCommand { Id = booked.Id }, default);
        checkout.Amount.Should().Be(600);
        checkout.KeyId.Should().Be("rzp_test_key");
        _gateway.Orders.Single().Receipt.Should().Be($"{booked.Id:N}-1");

        var forged = () => Payments.Handle(new CompleteRentalPaymentCommand
        {
            Id = booked.Id,
            ProviderOrderId = checkout.ProviderOrderId,
            PaymentId = "pay_1",
            Signature = "made-up",
        }, default);
        await forged.Should().ThrowAsync<DomainException>().WithMessage("*could not confirm*");

        var paid = await Payments.Handle(new CompleteRentalPaymentCommand
        {
            Id = booked.Id,
            ProviderOrderId = checkout.ProviderOrderId,
            PaymentId = "pay_1",
            Signature = "good",
        }, default);
        paid.Status.Should().Be("Booked");
        paid.PaymentStatus.Should().Be("AdvancePaid");
        paid.Balance.Should().Be(5400);
        paid.Payments.Single().MethodName.Should().Be("Online");

        // The window reporting the same payment again counts it once.
        _rent.Db.ChangeTracker.Clear();
        var again = await Payments.Handle(new CompleteRentalPaymentCommand
        {
            Id = booked.Id,
            ProviderOrderId = checkout.ProviderOrderId,
            PaymentId = "pay_1",
            Signature = "good",
        }, default);
        again.Paid.Should().Be(600);
        (await _rent.Db.RentalOrderPayments.CountAsync()).Should().Be(1);
    }

    [Fact]
    public async Task A_payment_for_another_order_is_refused()
    {
        var chairs = await ChairsAsync("PerOrder", 100);
        var first = await BookInAppAsync(chairs, 10);
        var checkout = await Payments.Handle(new StartRentalPaymentCommand { Id = first.Id }, default);
        _rent.As(TestRent.OwnerA);
        var other = await OfflineAsync(await ChairsAsync(), 10);
        _rent.Db.RentalOrders.Single(o => o.Id == other.Id).CustomerUserId = Customer;
        await _rent.Db.SaveChangesAsync();
        _rent.As(Customer);

        var misuse = () => Payments.Handle(new CompleteRentalPaymentCommand
        {
            Id = other.Id,
            ProviderOrderId = checkout.ProviderOrderId,
            PaymentId = "pay_9",
            Signature = "good",
        }, default);

        await misuse.Should().ThrowAsync<DomainException>().WithMessage("*not for this order*");
    }

    [Fact]
    public async Task An_unpaid_hold_frees_the_pieces_when_it_runs_out_and_the_lapse_job_cancels_it()
    {
        var chairs = await ChairsAsync("PerOrder", 100, quantity: 100);
        var booked = await BookInAppAsync(chairs, 100);
        var (start, end) = TwoDays();
        var item = await _rent.Db.RentalItems.AsNoTracking().SingleAsync(i => i.Id == chairs);

        (await _rent.Db.AvailabilityAsync(item, start, end, null, default)).Available.Should().Be(0);

        var order = await _rent.Db.RentalOrders.SingleAsync(o => o.Id == booked.Id);
        order.HoldUntil = DateTimeOffset.UtcNow.AddMinutes(-1);
        await _rent.Db.SaveChangesAsync();
        _rent.Db.ChangeTracker.Clear();

        (await _rent.Db.AvailabilityAsync(item, start, end, null, default)).Available.Should().Be(100);
        var late = () => Payments.Handle(new StartRentalPaymentCommand { Id = booked.Id }, default);
        await late.Should().ThrowAsync<DomainException>().WithMessage("*has passed*");

        (await Payments.Handle(new LapseRentalAdvancesCommand(), default)).Should().Be(1);
        var lapsed = await ReadAsync(booked.Id);
        lapsed.Status.Should().Be("Cancelled");
        lapsed.PaymentStatus.Should().BeNull();
        var history = await new GetRentalOrderHistoryQueryHandler(_rent.User, _rent.Db)
            .Handle(new GetRentalOrderHistoryQuery { RentalOrderId = booked.Id }, default);
        history.Last().Title.Should().Be("Advance not paid in time");
        (await Payments.Handle(new LapseRentalAdvancesCommand(), default)).Should().Be(0);
    }

    [Fact]
    public async Task Money_arriving_after_the_hold_ran_out_and_the_pieces_went_shows_as_a_refund_due()
    {
        var chairs = await ChairsAsync("PerOrder", 100, quantity: 100);
        var booked = await BookInAppAsync(chairs, 100);
        var checkout = await Payments.Handle(new StartRentalPaymentCommand { Id = booked.Id }, default);

        var order = await _rent.Db.RentalOrders.SingleAsync(o => o.Id == booked.Id);
        order.HoldUntil = DateTimeOffset.UtcNow.AddMinutes(-1);
        await _rent.Db.SaveChangesAsync();
        await OfflineAsync(await ChairsUnchangedAsync(chairs), 100, "Cash");

        _rent.As(Customer);
        var paid = await Payments.Handle(new CompleteRentalPaymentCommand
        {
            Id = booked.Id,
            ProviderOrderId = checkout.ProviderOrderId,
            PaymentId = "pay_late",
            Signature = "good",
        }, default);

        paid.Status.Should().Be("Cancelled");
        paid.PaymentStatus.Should().Be("RefundDue");
        paid.Paid.Should().Be(100);
    }

    [Fact]
    public async Task A_cancelled_order_with_its_advance_paid_shows_a_refund_due_until_it_is_given_back()
    {
        var order = await OfflineAsync(await ChairsAsync("PerOrder", 500), 100, "Cash");
        var cancelled = await MoveAsync(order.Id, "Cancelled", "InHand");

        cancelled.PaymentStatus.Should().Be("RefundDue");
        cancelled.Balance.Should().Be(0);
        cancelled.CanRefund.Should().BeTrue();
        cancelled.CanCollect.Should().BeFalse();

        var tooMuch = () => CollectAsync(order.Id, 600, "Cash", refund: true);
        await tooMuch.Should().ThrowAsync<DomainException>().WithMessage("Only ₹500 is owed back on this order.");

        var refunded = await CollectAsync(order.Id, 500, "Cash", refund: true);
        refunded.PaymentStatus.Should().Be("Refunded");
        refunded.Paid.Should().Be(0);
        refunded.CanRefund.Should().BeFalse();
    }

    [Fact]
    public async Task A_refund_is_only_for_a_cancelled_order()
    {
        var order = await OfflineAsync(await ChairsAsync("PerOrder", 500), 100, "Cash");

        var refund = () => CollectAsync(order.Id, 100, "Cash", refund: true);

        await refund.Should().ThrowAsync<DomainException>().WithMessage("*only on a cancelled order*");
    }

    [Fact]
    public async Task Extra_pieces_are_priced_at_the_first_orders_rate_with_no_advance_and_paid_before_their_return()
    {
        var chairs = await ChairsAsync("PerOrder", 500);
        var order = await OfflineAsync(chairs, 100, "Cash");
        _rent.As(TestRent.OwnerA);
        await _rent.SaveHandlers.Handle(TestRent.Edit(chairs, c => { c.Name = "Plastic chair"; c.Price = 50; c.QuantityOwned = 2000; }), default);
        _rent.Db.ChangeTracker.Clear();

        var extra = await Create.Handle(new AddRentalOrderAddOnCommand { ParentOrderId = order.Id, Quantity = 10 }, default);

        extra.UnitPrice.Should().Be(10);
        extra.AdvanceDue.Should().Be(0);
        extra.Balance.Should().Be(extra.Amount);
        await MoveAsync(extra.Id, "OnRent");
        var early = () => MoveAsync(extra.Id, "Returned");
        await early.Should().ThrowAsync<DomainException>();
    }

    [Fact]
    public async Task A_later_change_to_the_items_rate_or_advance_does_not_change_a_booked_order()
    {
        var chairs = await ChairsAsync("PerOrder", 500);
        var order = await OfflineAsync(chairs, 100, "Cash");
        _rent.As(TestRent.OwnerA);
        await _rent.SaveHandlers.Handle(TestRent.Edit(chairs, c =>
        {
            c.Price = 99; c.QuantityOwned = 2000; c.AdvanceType = "PerPiece"; c.AdvanceAmount = 50;
        }), default);
        _rent.Db.ChangeTracker.Clear();

        var read = await ReadAsync(order.Id);

        read.Amount.Should().Be(2000);
        read.AdvanceDue.Should().Be(500);
    }

    [Fact]
    public async Task A_customer_cannot_record_money_and_a_business_cannot_pay_online()
    {
        var chairs = await ChairsAsync("PerOrder", 100);
        var booked = await BookInAppAsync(chairs, 10);

        _rent.As(Customer);
        var asCustomer = () => Payments.Handle(new RecordRentalPaymentCommand { Id = booked.Id, Method = "Cash", Amount = 100 }, default);
        await asCustomer.Should().ThrowAsync<ForbiddenException>();

        _rent.As(TestRent.OwnerA);
        var asBusiness = () => Payments.Handle(new StartRentalPaymentCommand { Id = booked.Id }, default);
        await asBusiness.Should().ThrowAsync<ForbiddenException>();
    }

    [Fact]
    public async Task Cash_at_the_counter_for_an_awaited_advance_books_the_order()
    {
        var booked = await BookInAppAsync(await ChairsAsync("PerOrder", 100), 10);

        var paid = await CollectAsync(booked.Id, 100, "Cash");

        paid.Status.Should().Be("Booked");
        paid.Payments.Single().Kind.Should().Be("Advance");
    }

    [Fact]
    public async Task Online_payment_when_the_gateway_is_not_set_up_says_to_pay_the_business()
    {
        var booked = await BookInAppAsync(await ChairsAsync("PerOrder", 100), 10);
        _gateway.IsReady = false;

        var start = () => Payments.Handle(new StartRentalPaymentCommand { Id = booked.Id }, default);

        await start.Should().ThrowAsync<DomainException>().WithMessage("*Pay the business directly*");
    }

    [Fact]
    public async Task A_payment_line_can_never_be_changed_or_removed()
    {
        var order = await OfflineAsync(await ChairsAsync("PerOrder", 500), 100, "Cash");
        var line = await _rent.Db.RentalOrderPayments.SingleAsync(p => p.RentalOrderId == order.Id);

        line.Amount = 1;
        var edit = () => _rent.Db.SaveChangesAsync();

        await edit.Should().ThrowAsync<InvalidOperationException>().WithMessage("*payments cannot be changed*");
    }

    [Fact]
    public async Task The_upi_id_comes_from_the_business_profile_and_is_shown_to_the_business_only()
    {
        var chairs = await ChairsAsync("PerOrder", 100);
        _rent.As(TestRent.OwnerA);
        _directory.Business = new ServiceBusiness("Joy Rentals", null, IsVerified: true, UpiId: " Joy.Rentals@OkHdfcBank ");

        (await Settings.Handle(new GetRentalPaymentSettingsQuery(), default)).UpiId.Should().Be("joy.rentals@okhdfcbank");

        var booked = await BookInAppAsync(chairs, 10);
        booked.UpiId.Should().BeNull("a customer never sees the business's UPI ID on the order");
        (await ReadAsync(booked.Id)).UpiId.Should().Be("joy.rentals@okhdfcbank");
    }

    [Fact]
    public async Task A_changed_profile_upi_id_moves_the_qr_at_once()
    {
        _rent.As(TestRent.OwnerA);
        _directory.Business = new ServiceBusiness("Joy Rentals", null, IsVerified: true, UpiId: "old@okaxis");
        await Settings.Handle(new GetRentalPaymentSettingsQuery(), default);

        _directory.Business = _directory.Business with { UpiId = "new@ybl" };

        (await Settings.Handle(new GetRentalPaymentSettingsQuery(), default)).UpiId.Should().Be("new@ybl");
    }

    [Fact]
    public async Task A_profile_without_a_upi_id_keeps_the_one_saved_in_rent_before()
    {
        _rent.As(TestRent.OwnerA);
        _rent.Db.RentalBusinesses.Add(new RentalBusiness { OwnerUserId = TestRent.OwnerA, Name = "Joy Rentals", UpiId = "legacy@okhdfcbank" });
        await _rent.Db.SaveChangesAsync();
        _directory.Business = new ServiceBusiness("Joy Rentals", null, IsVerified: true);

        (await Settings.Handle(new GetRentalPaymentSettingsQuery(), default)).UpiId.Should().Be("legacy@okhdfcbank");
    }

    [Fact]
    public async Task Service_down_still_shows_the_upi_id_known_before()
    {
        _rent.As(TestRent.OwnerA);
        _directory.Business = new ServiceBusiness("Joy Rentals", null, IsVerified: true, UpiId: "joy@okaxis");
        await Settings.Handle(new GetRentalPaymentSettingsQuery(), default);

        _directory.Business = null;

        (await Settings.Handle(new GetRentalPaymentSettingsQuery(), default)).UpiId.Should().Be("joy@okaxis");
    }

    [Fact]
    public async Task The_options_come_from_the_tables_with_upi_qr_first_and_no_online_for_the_business()
    {
        var options = await Payments.Handle(new GetRentalPaymentOptionsQuery(), default);

        options.AdvanceTypes.Select(a => a.Code).Should().Equal("None", "PerOrder", "PerPiece");
        options.Methods.Select(m => m.Name).Should().Equal("UPI QR", "Cash");
    }

    /// <summary>The same item, read back after the hold changed — a second order needs no new listing.</summary>
    private Task<Guid> ChairsUnchangedAsync(Guid chairs)
    {
        _rent.Db.ChangeTracker.Clear();
        return Task.FromResult(chairs);
    }

    private sealed class Directory : IServiceDirectory
    {
        public Task<ServicePerson?> GetCurrentPersonAsync(CancellationToken cancellationToken) =>
            Task.FromResult<ServicePerson?>(new ServicePerson("Rahul Nair", "9876543210"));

        public ServiceBusiness? Business { get; set; }

        public Task<ServiceBusiness?> GetCurrentBusinessAsync(CancellationToken cancellationToken) =>
            Task.FromResult(Business);
    }
}
