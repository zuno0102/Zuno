using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Categories;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Customer;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Application.Orders;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;
using Zuno.Rent.Domain.Exceptions;
using Zuno.Rent.Infrastructure.Persistence.Seed;

namespace Zuno.Rent.UnitTests;

/// <summary>
/// Cancelling a paid rent order, like a bus ticket: the business sets a charge by time left (days, or
/// hours for an hourly item), never above what the super admin allows for the kind of item; the
/// customer cancelling pays it, the business cancelling pays nothing; the business then chooses
/// whether the rest goes back online or in hand, and each side is told what to expect.
/// </summary>
public class CancellationTests : IDisposable
{
    private static readonly Guid Customer = Guid.NewGuid();

    /// <summary>When the customer books and pays; the rent starts ten days later.</summary>
    private static readonly DateTimeOffset BookedAt = new(2026, 11, 1, 10, 0, 0, TimeSpan.Zero);

    private static readonly DateTimeOffset Start = new(2026, 11, 11, 0, 0, 0, TimeSpan.Zero);

    private readonly TestRent _rent = new();
    private readonly FakePaymentGateway _gateway = new();
    private readonly SettableClock _clock = new(BookedAt);

    public void Dispose() => _rent.Dispose();

    private RentalPaymentHandlers Payments => new(_rent.User, _rent.Db, _gateway, _clock);

    private CustomerRentalOrderHandlers CustomerOrders => new(_rent.User, _rent.Db, new Directory(), _rent.Settings, _clock);

    private ChangeRentalOrderStatusCommandHandler Change => new(_rent.User, _rent.Db, _clock);

    private RentalCancellationHandlers Cancellations => new(_rent.User, _rent.Db, _clock);

    private RentalOrderQueryHandlers Queries => new(_rent.User, _rent.Db, _rent.Settings);

    /// <summary>5+ days → 0.5%, 2+ days → 1%, same day → 2%.</summary>
    private static List<RentalCancelStepInput> BusSteps() =>
    [
        new() { UnitsBefore = 5, Percent = 0.5m },
        new() { UnitsBefore = 2, Percent = 1m },
        new() { UnitsBefore = 0, Percent = 2m },
    ];

    /// <summary>Plastic chairs at ₹10 a day, ₹20 a piece paid ahead — 250 chairs for two days is ₹5,000, all paid ahead.</summary>
    private async Task<Guid> ChairsAsync(
        List<RentalCancelStepInput>? steps = null, string advanceType = "PerPiece", decimal? advance = 20, string priceType = "Daily")
    {
        _rent.As(TestRent.OwnerA);
        var id = (await _rent.SaveHandlers.Handle(TestRent.Machine(c =>
        {
            c.RentalCategoryId = RentalCategorySeedData.FurnitureSeating;
            c.RentalSubCategoryId = TestRent.PlasticChairs;
            c.Name = "Plastic chair";
            c.PriceType = priceType;
            c.Price = 10;
            c.QuantityOwned = 2000;
            c.AdvanceType = advanceType;
            c.AdvanceAmount = advance;
            c.CancelSteps = steps ?? BusSteps();
        }), default)).Id;
        _rent.Db.ChangeTracker.Clear();
        return id;
    }

    private async Task<RentalOrderDto> BookAsync(Guid item, int quantity = 250, DateTimeOffset? start = null, int days = 2)
    {
        if (!await _rent.Db.RentalBusinesses.AnyAsync(b => b.OwnerUserId == TestRent.OwnerA))
        {
            _rent.Db.RentalBusinesses.Add(new RentalBusiness { OwnerUserId = TestRent.OwnerA, Name = "Joy Rentals", IsVerified = true });
            await _rent.Db.SaveChangesAsync();
        }

        _rent.As(Customer);
        var from = start ?? Start;
        return await CustomerOrders.Handle(new BookRentalCommand
        {
            RentalItemId = item,
            Quantity = quantity,
            StartDate = from,
            EndDate = from.AddDays(days).AddMinutes(-1),
            DeliveryAddress = "St. Mary's Hall",
            DistrictId = TestRent.Ernakulam,
        }, default);
    }

    /// <summary>The customer pays what the app asks, through the gateway.</summary>
    private async Task<RentalOrderDto> PayOnlineAsync(Guid order)
    {
        _rent.As(Customer);
        var checkout = await Payments.Handle(new StartRentalPaymentCommand { Id = order }, default);
        return await Payments.Handle(new CompleteRentalPaymentCommand
        {
            Id = order, ProviderOrderId = checkout.ProviderOrderId, PaymentId = $"pay_{Guid.NewGuid():N}", Signature = "good",
        }, default);
    }

    private async Task<RentalOrderDto> BookedAndPaidAsync(Guid item)
    {
        var booked = await BookAsync(item);
        var paid = await PayOnlineAsync(booked.Id);
        paid.Paid.Should().Be(5000);
        return paid;
    }

    private Task<RentalOrderDto> CustomerCancelsAsync(Guid order)
    {
        _rent.As(Customer);
        _rent.Db.ChangeTracker.Clear();
        return CustomerOrders.Handle(new CancelMyRentalCommand { Id = order }, default);
    }

    private Task<RentalOrderDto> BusinessCancelsAsync(Guid order, string? refundMode = "InHand")
    {
        _rent.As(TestRent.OwnerA);
        _rent.Db.ChangeTracker.Clear();
        return Change.Handle(new ChangeRentalOrderStatusCommand { Id = order, ToStatus = "Cancelled", RefundMode = refundMode }, default);
    }

    private Task<RentalOrderDto> RefundModeAsync(Guid order, string mode)
    {
        _rent.As(TestRent.OwnerA);
        _rent.Db.ChangeTracker.Clear();
        return Cancellations.Handle(new SetRentalRefundModeCommand { Id = order, Mode = mode }, default);
    }

    private Task<RentalOrderDto> RefundInHandAsync(Guid order, decimal amount)
    {
        _rent.As(TestRent.OwnerA);
        _rent.Db.ChangeTracker.Clear();
        return Payments.Handle(new RecordRentalPaymentCommand { Id = order, Method = "Cash", Amount = amount, IsRefund = true }, default);
    }

    private Task<RentalOrderDto> AsCustomerAsync(Guid order)
    {
        _rent.As(Customer);
        return CustomerOrders.Handle(new GetMyRentalQuery { Id = order }, default);
    }

    // ── The charge itself ──────────────────────────────────────────────

    [Theory]
    [InlineData(0, 2)]
    [InlineData(1, 2)]
    [InlineData(2, 1)]
    [InlineData(4, 1)]
    [InlineData(5, 0.5)]
    [InlineData(60, 0.5)]
    public void The_step_for_the_time_left_applies(int unitsBefore, decimal percent)
    {
        var steps = RentalCancellation.Validated(
            BusSteps().Select(s => new RentalCancelStep { UnitsBefore = s.UnitsBefore, Percent = s.Percent }), 2);

        RentalCancellation.PercentFor(steps, unitsBefore).Should().Be(percent);
    }

    [Fact]
    public void No_steps_is_free_cancellation() =>
        RentalCancellation.PercentFor([], 0).Should().Be(0);

    [Theory]
    [InlineData(RentalPriceType.Daily, 4 * 24 + 23, 4)]
    [InlineData(RentalPriceType.Daily, 23, 0)]
    [InlineData(RentalPriceType.Fixed, 49, 2)]
    [InlineData(RentalPriceType.Hourly, 5, 5)]
    [InlineData(RentalPriceType.Hourly, -3, 0)]
    public void Time_left_counts_whole_days_or_hours_for_an_hourly_item(RentalPriceType type, int hoursLeft, int units)
    {
        var now = new DateTimeOffset(2026, 11, 1, 9, 30, 0, TimeSpan.Zero);

        RentalCancellation.UnitsBefore(type, now.AddHours(hoursLeft), now).Should().Be(units);
    }

    [Theory]
    [InlineData(5000, 2, 5000, 100)]
    [InlineData(5000, 1, 5000, 50)]
    [InlineData(5000, 0.5, 5000, 25)]
    [InlineData(5000, 2, 60, 60)]
    [InlineData(333, 1.5, 333, 5)]
    [InlineData(5000, 0, 5000, 0)]
    public void The_charge_is_a_percent_of_the_order_and_never_more_than_was_paid(
        decimal amount, decimal percent, decimal paid, decimal charge) =>
        RentalCancellation.Charge(amount, percent, paid).Should().Be(charge);

    [Theory]
    [InlineData("3", "1", "A cancellation step starts at 0 (same day) or later.", -1, 1)]
    [InlineData("3", "1", "Add a step for cancelling on the start day itself (0).", 5, 1)]
    [InlineData("0", "1", "Each cancellation step needs its own number of days or hours.", 0, 1)]
    [InlineData("0", "3", "This kind of item allows a cancellation charge of at most 2%.", 1, 1)]
    [InlineData("0", "1", "Cancelling earlier cannot cost more than cancelling later.", 4, 1.5)]
    public void The_item_refuses_steps_that_break_the_rules(
        string firstUnits, string firstPercent, string message, int secondUnits, decimal secondPercent)
    {
        var item = new RentalItem();
        var steps = new[]
        {
            new RentalCancelStep { UnitsBefore = int.Parse(firstUnits), Percent = decimal.Parse(firstPercent) },
            new RentalCancelStep { UnitsBefore = secondUnits, Percent = secondPercent },
        };

        var act = () => item.SetCancelSteps(steps, 2);

        act.Should().Throw<DomainException>().WithMessage(message);
    }

    // ── The super admin's limit per kind of item ───────────────────────

    [Fact]
    public async Task Plastic_chairs_allow_2_percent_so_5_percent_is_refused()
    {
        var result = await ValidateAsync(c =>
        {
            c.RentalCategoryId = RentalCategorySeedData.FurnitureSeating;
            c.RentalSubCategoryId = TestRent.PlasticChairs;
            c.CancelSteps = [new() { UnitsBefore = 0, Percent = 5 }];
        });

        result.Errors.Select(e => e.ErrorMessage).Should()
            .ContainSingle("For Plastic chairs, the cancellation charge can be at most 2%.");
    }

    [Theory]
    [InlineData(1, 1, 2)]
    [InlineData(1, 3, 5)]
    [InlineData(1, 4, 10)]
    [InlineData(6, 1, 5)]
    public async Task Up_to_the_limit_is_allowed(int category, int sub, decimal percent)
    {
        var result = await ValidateAsync(c =>
        {
            c.RentalCategoryId = RentalCategorySeedData.Categories[category - 1].Id;
            c.RentalSubCategoryId = RentalCategorySeedData.SubCategoryId(category, sub);
            c.CancelSteps = [new() { UnitsBefore = 0, Percent = percent }];
        });

        result.IsValid.Should().BeTrue(string.Join("; ", result.Errors));
    }

    [Fact]
    public async Task A_category_without_its_own_sub_limit_uses_the_category_limit()
    {
        var result = await ValidateAsync(c =>
        {
            c.RentalCategoryId = RentalCategorySeedData.TentsShamiana;
            c.RentalSubCategoryId = null;
            c.CancelSteps = [new() { UnitsBefore = 0, Percent = 10.5m }];
        });

        result.Errors.Select(e => e.ErrorMessage).Should()
            .ContainSingle("For Tents & shamiana, the cancellation charge can be at most 10%.");
    }

    [Fact]
    public async Task The_platform_ceiling_wins_over_a_generous_category()
    {
        var result = await ValidateAsync(
            c =>
            {
                c.RentalCategoryId = RentalCategorySeedData.TentsShamiana;
                c.RentalSubCategoryId = null;
                c.CancelSteps = [new() { UnitsBefore = 0, Percent = 8 }];
            },
            new RentSettings { CancelPercentCeiling = 5 });

        result.Errors.Select(e => e.ErrorMessage).Should()
            .ContainSingle("For Tents & shamiana, the cancellation charge can be at most 5%.");
    }

    public static TheoryData<string, Action<CreateRentalItemCommand>> BadSteps => new()
    {
        { "Add a step for cancelling on the start day itself (0).", c => c.CancelSteps = [new() { UnitsBefore = 2, Percent = 1 }] },
        {
            "Each cancellation step needs its own number of days or hours.",
            c => c.CancelSteps = [new() { UnitsBefore = 0, Percent = 1 }, new() { UnitsBefore = 0, Percent = 2 }]
        },
        {
            "Cancelling earlier cannot cost more than cancelling later.",
            c => c.CancelSteps = [new() { UnitsBefore = 0, Percent = 1 }, new() { UnitsBefore = 3, Percent = 2 }]
        },
        { "A cancellation step starts at 0 (same day) or later.", c => c.CancelSteps = [new() { UnitsBefore = 0, Percent = 1 }, new() { UnitsBefore = -2, Percent = 1 }] },
        { "A cancellation charge cannot be below 0%.", c => c.CancelSteps = [new() { UnitsBefore = 0, Percent = -1 }] },
        { "Use at most 2 decimals for a cancellation charge, e.g. 1.5%.", c => c.CancelSteps = [new() { UnitsBefore = 0, Percent = 1.555m }] },
        { "A cancellation step can start at most 366 days before.", c => c.CancelSteps = [new() { UnitsBefore = 0, Percent = 1 }, new() { UnitsBefore = 367, Percent = 1 }] },
        {
            "An item can have at most 5 cancellation steps.",
            c => c.CancelSteps = Enumerable.Range(0, 6).Select(i => new RentalCancelStepInput { UnitsBefore = i, Percent = 1 }).ToList()
        },
    };

    [Theory]
    [MemberData(nameof(BadSteps))]
    public async Task Bad_steps_are_refused(string message, Action<CreateRentalItemCommand> breakIt)
    {
        var result = await ValidateAsync(breakIt);

        result.Errors.Select(e => e.ErrorMessage).Should().Contain(message);
    }

    [Fact]
    public async Task An_hourly_item_counts_its_steps_in_hours()
    {
        var ok = await ValidateAsync(c =>
        {
            c.PriceType = "Hourly";
            c.CancelSteps = [new() { UnitsBefore = 0, Percent = 2 }, new() { UnitsBefore = 400, Percent = 1 }];
        });
        ok.IsValid.Should().BeTrue(string.Join("; ", ok.Errors));

        var tooFar = await ValidateAsync(c =>
        {
            c.PriceType = "Hourly";
            c.CancelSteps = [new() { UnitsBefore = 0, Percent = 2 }, new() { UnitsBefore = 366 * 24 + 1, Percent = 1 }];
        });
        tooFar.Errors.Select(e => e.ErrorMessage).Should().Contain("A cancellation step can start at most 8784 hours before.");
    }

    [Fact]
    public async Task No_steps_is_allowed_and_means_free_cancellation()
    {
        var result = await ValidateAsync(c => c.CancelSteps = []);

        result.IsValid.Should().BeTrue(string.Join("; ", result.Errors));
    }

    [Fact]
    public async Task The_server_refuses_a_charge_above_the_limit_even_without_the_validator()
    {
        _rent.As(TestRent.OwnerA);
        var act = () => _rent.SaveHandlers.Handle(TestRent.Machine(c =>
        {
            c.RentalCategoryId = RentalCategorySeedData.FurnitureSeating;
            c.RentalSubCategoryId = TestRent.PlasticChairs;
            c.CancelSteps = [new() { UnitsBefore = 0, Percent = 5 }];
        }), default);

        await act.Should().ThrowAsync<DomainException>().WithMessage("*at most 2%*");
    }

    [Fact]
    public async Task The_item_and_the_category_list_show_the_steps_and_the_limits()
    {
        var item = await ChairsAsync();
        _rent.As(TestRent.OwnerA);
        var saved = (await new GetMyRentalItemsQueryHandler(_rent.User, _rent.Db, _rent.Settings)
            .Handle(new GetMyRentalItemsQuery(), default)).Items.Single(i => i.Id == item);
        saved.CancelUnit.Should().Be("Day");
        saved.CancelSteps.Select(s => (s.UnitsBefore, s.Percent)).Should().Equal((0, 2m), (2, 1m), (5, 0.5m));

        var categories = await new GetRentalCategoriesQueryHandler(
                _rent.Db, new Microsoft.Extensions.Caching.Memory.MemoryCache(new Microsoft.Extensions.Caching.Memory.MemoryCacheOptions()), _rent.Settings)
            .Handle(new GetRentalCategoriesQuery(), default);
        var furniture = categories.Single(c => c.Id == RentalCategorySeedData.FurnitureSeating);
        furniture.MaxCancelPercent.Should().Be(5);
        furniture.SubCategories.Single(s => s.Id == TestRent.PlasticChairs).MaxCancelPercent.Should().Be(2);
        furniture.SubCategories.Single(s => s.Name == "Stage").MaxCancelPercent.Should().Be(10);
    }

    // ── Cancelling a paid order ────────────────────────────────────────

    [Theory]
    [InlineData(1, 2, 100, 4900)]
    [InlineData(0, 2, 100, 4900)]
    [InlineData(3, 1, 50, 4950)]
    [InlineData(6, 0.5, 25, 4975)]
    public async Task The_customer_cancelling_pays_the_step_for_the_days_left(
        int daysLeft, decimal percent, decimal charge, decimal refund)
    {
        var order = await BookedAndPaidAsync(await ChairsAsync());
        _clock.Now = Start.AddDays(-daysLeft).AddHours(-1);

        _rent.As(Customer);
        var quote = await Cancellations.Handle(new GetMyRentalCancelQuoteQuery { Id = order.Id }, default);
        quote.Should().BeEquivalentTo(new RentalCancelQuoteDto
        {
            UnitsBefore = daysLeft, Unit = "Day", Basis = "ByTimeLeft", RentalUnits = 2,
            Percent = percent, Charge = charge, Paid = 5000, Refund = refund,
        });

        var cancelled = await CustomerCancelsAsync(order.Id);

        cancelled.Status.Should().Be("Cancelled");
        cancelled.CancelledBy.Should().Be("Customer");
        cancelled.CancellationCharge.Should().Be(charge);
        cancelled.RefundOwed.Should().Be(refund);
        cancelled.PaymentStatus.Should().Be("RefundDue");
        (await _rent.Db.RentalOrderEvents.SingleAsync(e => e.Kind == RentalOrderEventKind.CancellationCharged)).Amount.Should().Be(charge);
    }

    [Fact]
    public async Task The_business_cancelling_gives_everything_back()
    {
        var order = await BookedAndPaidAsync(await ChairsAsync());
        _clock.Now = Start.AddHours(-2);

        _rent.As(TestRent.OwnerA);
        var quote = await Cancellations.Handle(new GetRentalCancelQuoteQuery { Id = order.Id }, default);
        quote.Charge.Should().Be(0);
        quote.Refund.Should().Be(5000);

        var cancelled = await BusinessCancelsAsync(order.Id);

        cancelled.CancelledBy.Should().Be("Business");
        cancelled.CancellationCharge.Should().Be(0);
        cancelled.RefundOwed.Should().Be(5000);
        (await _rent.Db.RentalOrderEvents.AnyAsync(e => e.Kind == RentalOrderEventKind.CancellationCharged)).Should().BeFalse();
    }

    [Fact]
    public async Task An_item_with_no_steps_cancels_free()
    {
        var order = await BookedAndPaidAsync(await ChairsAsync(steps: []));
        _clock.Now = Start.AddHours(-1);

        var cancelled = await CustomerCancelsAsync(order.Id);

        cancelled.CancellationCharge.Should().Be(0);
        cancelled.RefundOwed.Should().Be(5000);
    }

    [Fact]
    public async Task The_charge_never_takes_more_than_the_advance_paid()
    {
        // ₹60 ahead on a ₹5,000 order; 2% would be ₹100.
        var order = await BookAsync(await ChairsAsync(advanceType: "PerOrder", advance: 60));
        await PayOnlineAsync(order.Id);
        _clock.Now = Start.AddHours(-1);

        var cancelled = await CustomerCancelsAsync(order.Id);

        cancelled.CancellationCharge.Should().Be(60);
        cancelled.RefundOwed.Should().Be(0);
        cancelled.PaymentStatus.Should().Be("ChargeKept");
        cancelled.PaymentStatusName.Should().Be("Cancellation charge kept");
        cancelled.CanRefund.Should().BeFalse();
        cancelled.CanChooseRefundMode.Should().BeFalse();
    }

    [Fact]
    public async Task An_order_keeps_the_steps_it_was_booked_with()
    {
        var item = await ChairsAsync();
        var order = await BookedAndPaidAsync(item);

        // The business raises its charge afterwards; this order is not touched.
        _rent.As(TestRent.OwnerA);
        var edit = await _rent.Db.RentalItems.Include(i => i.Districts).Include(i => i.Questions).SingleAsync(i => i.Id == item);
        edit.SetCancelSteps([new RentalCancelStep { UnitsBefore = 0, Percent = 2 }, new RentalCancelStep { UnitsBefore = 30, Percent = 2 }], 2);
        await _rent.Db.SaveChangesAsync();
        _clock.Now = Start.AddDays(-6);

        var cancelled = await CustomerCancelsAsync(order.Id);

        cancelled.CancellationCharge.Should().Be(25);
        cancelled.CancelSteps.Select(s => s.Percent).Should().Equal(2m, 1m, 0.5m);
    }

    [Fact]
    public async Task An_hourly_order_counts_the_hours_left()
    {
        // 5+ hours → 1%, same hour → 2%. 250 chairs for 2 days is 48 hours at ₹10.
        var item = await ChairsAsync(
            steps: [new() { UnitsBefore = 0, Percent = 2 }, new() { UnitsBefore = 5, Percent = 1 }],
            advanceType: "None",
            advance: null,
            priceType: "Hourly");
        var order = await BookAsync(item);
        order.Amount.Should().Be(120_000);
        _clock.Now = Start.AddHours(-6);

        _rent.As(Customer);
        var quote = await Cancellations.Handle(new GetMyRentalCancelQuoteQuery { Id = order.Id }, default);

        quote.Unit.Should().Be("Hour");
        quote.UnitsBefore.Should().Be(6);
        quote.Percent.Should().Be(1);
        quote.Charge.Should().Be(0, "nothing was paid, so nothing can be kept");
    }

    // ── How the refund goes back ───────────────────────────────────────

    [Fact]
    public async Task Online_refund_the_customer_is_told_1_to_5_working_days()
    {
        var order = await BookedAndPaidAsync(await ChairsAsync());
        _clock.Now = Start.AddDays(-1).AddHours(-1);
        var cancelled = await CustomerCancelsAsync(order.Id);
        _rent.As(TestRent.OwnerA);
        var forBusiness = await Queries.Handle(new GetRentalOrderQuery { Id = order.Id }, default);
        forBusiness.CanChooseRefundMode.Should().BeTrue();
        forBusiness.RefundModes.Select(m => (m.Code, m.DisabledReason)).Should().Equal(("Online", null), ("InHand", null));
        cancelled.CanChooseRefundMode.Should().BeFalse("the customer does not choose");

        var online = await RefundModeAsync(order.Id, "Online");

        online.RefundMode.Should().Be("Online");
        online.CanRefund.Should().BeFalse("Zuno sends an online refund; the business records nothing");
        online.RefundModeText.Should().Contain("Nothing for you to hand over");
        var customer = await AsCustomerAsync(order.Id);
        customer.RefundModeName.Should().Be("Online");
        customer.RefundModeText.Should().Be("Your refund goes back to the card or UPI you paid with, in 1 to 5 working days.");
        customer.RefundOwed.Should().Be(4900);
        (await _rent.Db.RentalOrderEvents.SingleAsync(e => e.Kind == RentalOrderEventKind.RefundModeChosen)).Amount.Should().Be(4900);

        var byHand = () => RefundInHandAsync(order.Id, 4900);
        await byHand.Should().ThrowAsync<DomainException>().WithMessage("This refund goes back online*");
    }

    [Fact]
    public async Task In_hand_refund_the_customer_collects_it_from_the_business()
    {
        var order = await BookedAndPaidAsync(await ChairsAsync());
        _clock.Now = Start.AddDays(-1).AddHours(-1);
        await CustomerCancelsAsync(order.Id);

        var inHand = await RefundModeAsync(order.Id, "InHand");
        inHand.CanRefund.Should().BeTrue();
        (await AsCustomerAsync(order.Id)).RefundModeText.Should().Be("Collect your refund directly from the business.");

        var tooMuch = () => RefundInHandAsync(order.Id, 4901);
        await tooMuch.Should().ThrowAsync<DomainException>().WithMessage("Only ₹4,900 is owed back on this order.");

        var refunded = await RefundInHandAsync(order.Id, 4900);

        refunded.Paid.Should().Be(100, "the business keeps the cancellation charge");
        refunded.RefundOwed.Should().Be(0);
        refunded.PaymentStatus.Should().Be("Refunded");
        refunded.CanRefund.Should().BeFalse();
        refunded.CanChooseRefundMode.Should().BeFalse();
        var change = () => RefundModeAsync(order.Id, "Online");
        await change.Should().ThrowAsync<DomainException>().WithMessage("Nothing is owed back on this order.");
    }

    [Fact]
    public async Task Recording_a_refund_by_hand_without_choosing_first_means_in_hand()
    {
        var order = await BookedAndPaidAsync(await ChairsAsync());
        _clock.Now = Start.AddDays(-3).AddHours(-1);
        await CustomerCancelsAsync(order.Id);

        var part = await RefundInHandAsync(order.Id, 1000);

        part.RefundMode.Should().Be("InHand");
        part.RefundOwed.Should().Be(3950);
        part.CanChooseRefundMode.Should().BeFalse("part has already gone back by hand");
        var change = () => RefundModeAsync(order.Id, "Online");
        await change.Should().ThrowAsync<DomainException>().WithMessage("Part of the refund has already gone back*");
    }

    [Fact]
    public async Task Money_paid_in_cash_cannot_go_back_online()
    {
        var order = await BookAsync(await ChairsAsync());
        _rent.As(TestRent.OwnerA);
        await Payments.Handle(new RecordRentalPaymentCommand { Id = order.Id, Method = "Cash", Amount = 5000 }, default);
        await BusinessCancelsAsync(order.Id);

        _rent.As(TestRent.OwnerA);
        var read = await Queries.Handle(new GetRentalOrderQuery { Id = order.Id }, default);
        read.RefundModes.Single(m => m.Code == "Online").DisabledReason
            .Should().Be("The customer paid in cash or by UPI, so give the refund in hand.");

        var online = () => RefundModeAsync(order.Id, "Online");
        await online.Should().ThrowAsync<DomainException>().WithMessage("The customer paid in cash or by UPI*");
    }

    [Fact]
    public async Task Only_the_business_chooses_the_refund_method()
    {
        var order = await BookedAndPaidAsync(await ChairsAsync());
        await CustomerCancelsAsync(order.Id);

        _rent.As(Customer);
        var act = () => Cancellations.Handle(new SetRentalRefundModeCommand { Id = order.Id, Mode = "Online" }, default);

        await act.Should().ThrowAsync<Exception>();
        (await _rent.Db.RentalOrders.SingleAsync(o => o.Id == order.Id)).RefundMode.Should().BeNull();
    }

    [Fact]
    public async Task No_refund_method_on_an_order_that_is_not_cancelled()
    {
        var order = await BookedAndPaidAsync(await ChairsAsync());

        var act = () => RefundModeAsync(order.Id, "Online");

        await act.Should().ThrowAsync<DomainException>().WithMessage("Nothing is owed back on this order.");
    }

    // ── The business says how the money goes back as it cancels ────────

    [Fact]
    public async Task The_business_cannot_cancel_a_paid_order_without_saying_how_the_money_goes_back()
    {
        var order = await BookedAndPaidAsync(await ChairsAsync());

        var act = () => BusinessCancelsAsync(order.Id, refundMode: null);

        await act.Should().ThrowAsync<DomainException>()
            .WithMessage("₹5,000 was paid. Choose how it goes back: online or in hand.");
        _rent.Db.ChangeTracker.Clear();
        (await _rent.Db.RentalOrders.SingleAsync(o => o.Id == order.Id)).Status.Should().Be(RentalOrderStatus.Booked);
    }

    [Fact]
    public async Task Cancelling_with_online_sets_it_in_the_same_step()
    {
        var order = await BookedAndPaidAsync(await ChairsAsync());

        var cancelled = await BusinessCancelsAsync(order.Id, "Online");

        cancelled.Status.Should().Be("Cancelled");
        cancelled.RefundMode.Should().Be("Online");
        cancelled.NeedsRefund.Should().BeFalse("Zuno sends an online refund");
        cancelled.CanRefund.Should().BeFalse();
        (await _rent.Db.RentalOrderEvents.SingleAsync(e => e.Kind == RentalOrderEventKind.RefundModeChosen))
            .Amount.Should().Be(5000);
        (await AsCustomerAsync(order.Id)).RefundModeText.Should().Contain("1 to 5 working days");
    }

    [Fact]
    public async Task Cancelling_with_in_hand_leaves_it_for_the_business_to_give_back()
    {
        var order = await BookedAndPaidAsync(await ChairsAsync());

        var cancelled = await BusinessCancelsAsync(order.Id, "InHand");

        cancelled.RefundMode.Should().Be("InHand");
        cancelled.NeedsRefund.Should().BeTrue();
        cancelled.CanRefund.Should().BeTrue();
    }

    [Fact]
    public async Task Cash_paid_cannot_be_cancelled_with_an_online_refund()
    {
        var order = await BookAsync(await ChairsAsync());
        _rent.As(TestRent.OwnerA);
        await Payments.Handle(new RecordRentalPaymentCommand { Id = order.Id, Method = "Cash", Amount = 5000 }, default);

        _rent.As(TestRent.OwnerA);
        var quote = await Cancellations.Handle(new GetRentalCancelQuoteQuery { Id = order.Id }, default);
        quote.RefundModes.Select(m => (m.Code, m.DisabledReason)).Should().Equal(
            ("Online", "The customer paid in cash or by UPI, so give the refund in hand."),
            ("InHand", null));

        var act = () => BusinessCancelsAsync(order.Id, "Online");
        await act.Should().ThrowAsync<DomainException>().WithMessage("The customer paid in cash or by UPI*");
    }

    [Fact]
    public async Task An_unpaid_order_cancels_with_no_refund_question()
    {
        var order = await BookAsync(await ChairsAsync(advanceType: "None", advance: null));

        _rent.As(TestRent.OwnerA);
        (await Cancellations.Handle(new GetRentalCancelQuoteQuery { Id = order.Id }, default)).RefundModes.Should().BeEmpty();
        var cancelled = await BusinessCancelsAsync(order.Id, refundMode: null);

        cancelled.Status.Should().Be("Cancelled");
        cancelled.RefundMode.Should().BeNull();
    }

    [Fact]
    public async Task The_customer_is_never_asked_for_a_refund_method()
    {
        var order = await BookedAndPaidAsync(await ChairsAsync());
        _clock.Now = Start.AddDays(-3).AddHours(-1);

        _rent.As(Customer);
        (await Cancellations.Handle(new GetMyRentalCancelQuoteQuery { Id = order.Id }, default)).RefundModes.Should().BeEmpty();
        var cancelled = await CustomerCancelsAsync(order.Id);

        cancelled.RefundMode.Should().BeNull("the business chooses it afterwards");
        cancelled.RefundOwed.Should().Be(4950);
    }

    [Theory]
    [InlineData("Cheque")]
    [InlineData("1")]
    public void An_unknown_refund_method_on_cancel_is_refused(string mode) =>
        new ChangeRentalOrderStatusCommandValidator()
            .Validate(new ChangeRentalOrderStatusCommand { Id = Guid.NewGuid(), ToStatus = "Cancelled", RefundMode = mode })
            .Errors.Select(e => e.ErrorMessage).Should().Contain("Choose how the money goes back: online or in hand.");

    // ── A percent per rental day ───────────────────────────────────────

    /// <summary>Plastic chairs at ₹10 a day, ₹20 a piece ahead, charged [perDay]% for each day rented.</summary>
    private async Task<Guid> PerDayChairsAsync(decimal perDay = 1, string priceType = "Daily")
    {
        _rent.As(TestRent.OwnerA);
        var id = (await _rent.SaveHandlers.Handle(TestRent.Machine(c =>
        {
            c.RentalCategoryId = RentalCategorySeedData.FurnitureSeating;
            c.RentalSubCategoryId = TestRent.PlasticChairs;
            c.Name = "Plastic chair";
            c.PriceType = priceType;
            c.Price = 10;
            c.QuantityOwned = 2000;
            c.AdvanceType = "PerPiece";
            c.AdvanceAmount = 20;
            c.CancelChargeType = "PerRentalDay";
            c.CancelPercentPerDay = perDay;
            c.CancelSteps = [];
        }), default)).Id;
        _rent.Db.ChangeTracker.Clear();
        return id;
    }

    [Theory]
    [InlineData(1, 1, 1)]
    [InlineData(2, 1, 2)]
    [InlineData(5, 1, 2)]
    [InlineData(2, 0.5, 1)]
    public void A_per_day_charge_grows_with_the_days_up_to_the_limit(int days, decimal perDay, decimal percent) =>
        RentalCancellation.PerRentalDay(perDay, days, cap: 2).Should().Be(percent);

    [Theory]
    [InlineData(1, 2500, 25)]
    [InlineData(2, 5000, 100)]
    [InlineData(4, 10000, 200)]
    public async Task The_customer_cancelling_pays_one_percent_for_each_day_rented(int days, decimal amount, decimal charge)
    {
        // 250 chairs × ₹10 × days; 1% a day, Plastic chairs allow at most 2%.
        var item = await PerDayChairsAsync();
        var booked = await BookAsync(item, days: days);
        booked.Amount.Should().Be(amount);
        booked.CancelChargeType.Should().Be("PerRentalDay");
        booked.CancelPercentPerDay.Should().Be(1);
        booked.CancelPercentCap.Should().Be(2);
        // Paid in full, so the charge is never cut short by what was paid.
        if ((await PayOnlineAsync(booked.Id)).Balance > 0)
        {
            await PayOnlineAsync(booked.Id);
        }

        _clock.Now = Start.AddDays(-9);

        _rent.As(Customer);
        var quote = await Cancellations.Handle(new GetMyRentalCancelQuoteQuery { Id = booked.Id }, default);
        quote.Basis.Should().Be("PerRentalDay");
        quote.RentalUnits.Should().Be(days);
        quote.Percent.Should().Be(Math.Min(days, 2));
        quote.Charge.Should().Be(charge);

        var cancelled = await CustomerCancelsAsync(booked.Id);
        cancelled.CancellationCharge.Should().Be(charge, "it does not matter how early: it counts rental days");
    }

    [Fact]
    public async Task A_per_day_charge_is_kept_on_the_item_and_shown_to_customers()
    {
        var item = await PerDayChairsAsync(perDay: 1.5m);

        _rent.As(TestRent.OwnerA);
        var saved = (await new GetMyRentalItemsQueryHandler(_rent.User, _rent.Db, _rent.Settings)
            .Handle(new GetMyRentalItemsQuery(), default)).Items.Single(i => i.Id == item);
        saved.CancelChargeType.Should().Be("PerRentalDay");
        saved.CancelPercentPerDay.Should().Be(1.5m);
        saved.CancelSteps.Should().BeEmpty();

        var options = await Payments.Handle(new GetRentalPaymentOptionsQuery(), default);
        options.CancelChargeTypes.Select(c => (c.Code, c.Name)).Should().Equal(
            ("ByTimeLeft", "By time left"), ("PerRentalDay", "Per rental day"));
    }

    public static TheoryData<string, Action<CreateRentalItemCommand>> BadPerDay => new()
    {
        { "Enter the charge for each rental day, e.g. 1%.", c => c.CancelPercentPerDay = null },
        { "The charge for each rental day must be more than 0%.", c => c.CancelPercentPerDay = 0 },
        { "For Plastic chairs, the cancellation charge can be at most 2%.", c => c.CancelPercentPerDay = 3 },
        { "Use at most 2 decimals for a cancellation charge, e.g. 1.5%.", c => c.CancelPercentPerDay = 1.555m },
        {
            "Use either steps by time left or a charge per rental day, not both.",
            c => c.CancelSteps = [new() { UnitsBefore = 0, Percent = 1 }]
        },
        {
            "Choose how the cancellation charge is worked out: by time left or per rental day.",
            c => c.CancelChargeType = "Weekly"
        },
    };

    [Theory]
    [MemberData(nameof(BadPerDay))]
    public async Task A_bad_per_day_charge_is_refused(string message, Action<CreateRentalItemCommand> breakIt)
    {
        var result = await ValidateAsync(c =>
        {
            c.RentalCategoryId = RentalCategorySeedData.FurnitureSeating;
            c.RentalSubCategoryId = TestRent.PlasticChairs;
            c.CancelChargeType = "PerRentalDay";
            c.CancelPercentPerDay = 1;
            c.CancelSteps = [];
            breakIt(c);
        });

        result.Errors.Select(e => e.ErrorMessage).Should().Contain(message);
    }

    [Fact]
    public async Task The_server_refuses_a_per_day_charge_above_the_limit_even_without_the_validator()
    {
        var act = () => PerDayChairsAsync(perDay: 5);

        await act.Should().ThrowAsync<DomainException>().WithMessage("*at most 2%*");
    }

    [Fact]
    public async Task Switching_back_to_steps_clears_the_per_day_charge()
    {
        var item = await PerDayChairsAsync();
        _rent.As(TestRent.OwnerA);
        var edit = await _rent.Db.RentalItems.SingleAsync(i => i.Id == item);

        edit.SetCancelCharge(
            RentalCancelChargeType.ByTimeLeft, [new RentalCancelStep { UnitsBefore = 0, Percent = 2 }], 1, 2);

        edit.CancelChargeType.Should().Be(RentalCancelChargeType.ByTimeLeft);
        edit.CancelPercentPerDay.Should().BeNull();
        edit.CancelSteps.Should().ContainSingle();
    }

    // ── Giving it back by UPI ──────────────────────────────────────────

    [Fact]
    public async Task A_refund_paid_by_upi_keeps_the_reference_and_the_customers_upi_id()
    {
        var order = await BookedAndPaidAsync(await ChairsAsync());
        await BusinessCancelsAsync(order.Id, "InHand");

        _rent.As(TestRent.OwnerA);
        _rent.Db.ChangeTracker.Clear();
        var refunded = await Payments.Handle(new RecordRentalPaymentCommand
        {
            Id = order.Id, Method = "UpiQr", Amount = 5000, IsRefund = true,
            Reference = "431256789012", PayeeUpiId = "rahul@okaxis",
        }, default);

        refunded.PaymentStatus.Should().Be("Refunded");
        var line = refunded.Payments.Single(p => p.Kind == "Refund");
        line.Reference.Should().Be("431256789012");
        line.MethodName.Should().Be("UPI QR");
        (await _rent.Db.RentalOrderPayments.SingleAsync(p => p.Kind == RentalPaymentKind.Refund))
            .PayeeUpiId.Should().Be("rahul@okaxis");
        (await AsCustomerAsync(order.Id)).Payments.Single(p => p.Kind == "Refund").Reference
            .Should().Be("431256789012", "the customer can match it against their bank");
    }

    public static TheoryData<string, Action<RecordRentalPaymentCommand>> BadUpiRefunds => new()
    {
        { "Enter the UPI reference as the UPI app shows it: letters and digits.", c => c.Reference = "ref #1" },
        { "Enter a UPI ID like name@bank.", c => c.PayeeUpiId = "rahul" },
        { "A UPI reference goes with a UPI payment, not cash.", c => { c.Method = "Cash"; c.Reference = "431256789012"; } },
    };

    [Theory]
    [MemberData(nameof(BadUpiRefunds))]
    public void A_bad_upi_refund_is_refused(string message, Action<RecordRentalPaymentCommand> breakIt)
    {
        var command = new RecordRentalPaymentCommand { Id = Guid.NewGuid(), Method = "UpiQr", Amount = 100, IsRefund = true };
        breakIt(command);

        new RecordRentalPaymentCommandValidator().Validate(command)
            .Errors.Select(e => e.ErrorMessage).Should().Contain(message);
    }

    // ── Finding the money to give back ─────────────────────────────────

    private async Task<(List<RentalOrderDto> RefundDue, List<RentalOrderStatusCountDto> Counts)> RefundListAsync()
    {
        _rent.As(TestRent.OwnerA);
        _rent.Db.ChangeTracker.Clear();
        var list = await Queries.Handle(new GetMyRentalOrdersQuery { Status = "RefundDue" }, default);
        var counts = await Queries.Handle(new GetRentalOrderCountsQuery(), default);
        return (list.Items, counts);
    }

    [Fact]
    public async Task A_paid_order_the_business_cancels_waits_under_refund_due_until_given_back()
    {
        var item = await ChairsAsync();
        var cancelled = await BookedAndPaidAsync(item);
        var stillBooked = await BookedAndPaidAsync(item);
        await BusinessCancelsAsync(cancelled.Id);

        var (due, counts) = await RefundListAsync();
        due.Select(o => o.Id).Should().Equal(cancelled.Id);
        due.Single().NeedsRefund.Should().BeTrue("the business has to give it back");
        due.Single().CancelledBy.Should().Be("Business");
        var chip = counts.First();
        chip.Status.Should().Be("RefundDue");
        chip.Name.Should().Be("Refund due");
        chip.Tone.Should().Be("danger");
        chip.Count.Should().Be(1);
        chip.CountsInAll.Should().BeFalse("it cuts across statuses, so All does not add it twice");
        counts.Where(c => c.CountsInAll).Sum(c => c.Count).Should().Be(2);
        (await Queries.Handle(new GetRentalOrderQuery { Id = stillBooked.Id }, default)).NeedsRefund.Should().BeFalse();

        await RefundInHandAsync(cancelled.Id, 5000);

        (due, counts) = await RefundListAsync();
        due.Should().BeEmpty();
        counts.First().Count.Should().Be(0);
    }

    [Fact]
    public async Task An_online_refund_stays_due_but_is_no_longer_the_business_job()
    {
        var order = await BookedAndPaidAsync(await ChairsAsync());
        _clock.Now = Start.AddDays(-1).AddHours(-1);
        await CustomerCancelsAsync(order.Id);

        var online = await RefundModeAsync(order.Id, "Online");

        online.NeedsRefund.Should().BeFalse("Zuno sends it back");
        (await RefundListAsync()).RefundDue.Single().RefundOwed.Should().Be(4900);
    }

    [Fact]
    public async Task A_cancelled_order_with_the_charge_keeping_everything_is_not_refund_due()
    {
        var order = await BookAsync(await ChairsAsync(advanceType: "PerOrder", advance: 60));
        await PayOnlineAsync(order.Id);
        _clock.Now = Start.AddHours(-1);
        await CustomerCancelsAsync(order.Id);

        (await RefundListAsync()).RefundDue.Should().BeEmpty();
    }

    [Theory]
    [InlineData("")]
    [InlineData("1")]
    [InlineData("Cheque")]
    public void An_unknown_refund_method_is_refused(string mode) =>
        new SetRentalRefundModeCommandValidator()
            .Validate(new SetRentalRefundModeCommand { Id = Guid.NewGuid(), Mode = mode })
            .Errors.Select(e => e.ErrorMessage).Should().Contain("Choose how the refund goes back: online or in hand.");

    private Task<FluentValidation.Results.ValidationResult> ValidateAsync(
        Action<CreateRentalItemCommand> change, RentSettings? settings = null) =>
        new CreateRentalItemCommandValidator(_rent.Db, settings is null ? _rent.Settings : Options.Create(settings))
            .ValidateAsync(TestRent.Machine(change));

    private sealed class SettableClock(DateTimeOffset now) : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = now;

        public override DateTimeOffset GetUtcNow() => Now;
    }

    private sealed class Directory : IServiceDirectory
    {
        public Task<ServicePerson?> GetCurrentPersonAsync(CancellationToken cancellationToken) =>
            Task.FromResult<ServicePerson?>(new ServicePerson("Rahul Nair", "9876543210"));

        public Task<ServiceBusiness?> GetCurrentBusinessAsync(CancellationToken cancellationToken) =>
            Task.FromResult<ServiceBusiness?>(null);
    }
}
