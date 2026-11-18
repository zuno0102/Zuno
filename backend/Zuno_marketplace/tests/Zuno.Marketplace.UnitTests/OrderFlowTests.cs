using FluentAssertions;
using FluentValidation.TestHelper;
using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Application.Orders;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.UnitTests;

/// <summary>
/// Product orders end to end against the rules: who may take which step, stock held and given back,
/// online pay confirmed only when proven, refunds, the timed job, reviews.
/// </summary>
public class OrderFlowTests
{
    private static readonly Guid Customer = Guid.NewGuid();
    private static readonly Guid OtherCustomer = Guid.NewGuid();

    private sealed class Scene : IDisposable
    {
        public Scene()
        {
            Test = new TestMarketplace(TestMarketplace.OwnerA);
            Test.Db.Businesses.Add(new MarketplaceBusiness
            {
                OwnerUserId = TestMarketplace.OwnerA,
                Name = "Joy Silks",
                IsVerified = true,
                RefreshedAt = Test.Now,
            });
            Test.Db.SaveChanges();
            Saree = Test.Seed(p =>
            {
                p.Title = "Silk saree";
                p.Price = 2400m;
                p.Condition = MarketplaceItemCondition.New;
                p.Quantity = 8;
                p.Variants =
                [
                    new MarketplacePostVariant { Colour = "Red", Stock = 5, SortOrder = 0 },
                    new MarketplacePostVariant { Colour = "Blue", Price = 2600m, Stock = 3, SortOrder = 1 },
                ];
            });
            Red = Saree.Variants.Single(v => v.Colour == "Red").Id;
            Blue = Saree.Variants.Single(v => v.Colour == "Blue").Id;
        }

        public TestMarketplace Test { get; }

        public MarketplacePost Saree { get; }

        public Guid Red { get; }

        public Guid Blue { get; }

        public FakePaymentGateway Gateway { get; } = new();

        public FakeServiceDirectory Directory { get; } = new();

        public BusinessMarketplaceOrderHandlers Business =>
            new(Test.User, Test.Db, Test.Storage, Gateway, Directory, Test.Reference, Test.Clock, Test.Settings);

        public CustomerMarketplaceOrderHandlers Customers =>
            new(Test.User, Test.Db, Gateway, Directory, Test.Reference, Test.Clock, Test.Settings);

        public RunMarketplaceOrderJobsHandler Jobs => new(Test.Db, Gateway, Test.Clock);

        public Task<MarketplaceOrderDto> PlaceAsync(string method = "CashOnDelivery", int quantity = 2, Guid? variant = null, Guid? customer = null)
        {
            Test.As(customer ?? OrderFlowTests.Customer);
            return Customers.Handle(
                new PlaceMarketplaceOrderCommand
                {
                    PostId = Saree.Id,
                    VariantId = variant ?? Red,
                    Quantity = quantity,
                    PaymentMethod = method,
                    DeliveryAddress = "12, North Street, Nagercoil",
                    Pincode = "629001",
                },
                CancellationToken.None);
        }

        public Task<MarketplaceOrderDto> StepAsync(Guid orderId, string status)
        {
            Test.As(TestMarketplace.OwnerA);
            return Business.Handle(new ChangeMarketplaceOrderStatusCommand { Id = orderId, Status = status }, CancellationToken.None);
        }

        public Task<MarketplaceOrderDto> ShipAsync(Guid orderId, string courier = "dtdc", string number = "D45120098871", string? name = null)
        {
            Test.As(TestMarketplace.OwnerA);
            return Business.Handle(
                new ShipMarketplaceOrderCommand { Id = orderId, CourierCode = courier, CourierName = name, TrackingNumber = number },
                CancellationToken.None);
        }

        public Task<MarketplaceOrderDto> CancelAsync(Guid orderId)
        {
            Test.As(OrderFlowTests.Customer);
            return Customers.Handle(new CancelMarketplaceOrderCommand { Id = orderId }, CancellationToken.None);
        }

        public async Task<MarketplaceOrderDto> PayAsync(Guid orderId, string signature = "good")
        {
            Test.As(OrderFlowTests.Customer);
            var checkout = await Customers.Handle(new StartMarketplaceOrderPaymentCommand { Id = orderId }, CancellationToken.None);
            return await Customers.Handle(
                new CompleteMarketplaceOrderPaymentCommand
                {
                    Id = orderId, ProviderOrderId = checkout.ProviderOrderId, PaymentId = $"pay_{orderId:N}", Signature = signature,
                },
                CancellationToken.None);
        }

        public int StockOf(Guid variantId) => Test.Db.PostVariants.AsNoTracking().Single(v => v.Id == variantId).Stock;

        public int? PostQuantity() => Test.Db.Posts.AsNoTracking().Single(p => p.Id == Saree.Id).Quantity;

        public void Dispose() => Test.Dispose();
    }

    [Fact]
    public async Task Cash_On_Delivery_Order_Holds_Stock_And_Goes_All_The_Way_To_Delivered()
    {
        using var scene = new Scene();

        var order = await scene.PlaceAsync();
        order.Status.Should().Be("Placed");
        order.StatusName.Should().Be("New");
        order.Amount.Should().Be(4800m);
        order.VariantName.Should().Be("Red");
        order.CustomerName.Should().Be("Priya S");
        order.CustomerPhone.Should().Be("9876543210", "the account's mobile is used when none is typed");
        order.Actions.Should().ContainSingle(a => a.ToStatus == "Cancelled", "the customer can cancel before it ships");
        scene.StockOf(scene.Red).Should().Be(3);
        scene.PostQuantity().Should().Be(6, "the product's stock is its colours' stock added up");

        (await scene.StepAsync(order.Id, "Confirmed")).Actions.Should().ContainSingle(a => a.NeedsTracking && a.Name == "Mark shipped");
        var shipped = await scene.ShipAsync(order.Id);
        shipped.Status.Should().Be("Shipped");
        shipped.CourierName.Should().Be("DTDC");
        shipped.TrackingNumber.Should().Be("D45120098871");
        shipped.TrackingUrl.Should().BeNull("DTDC has no tracking link in the table");

        await scene.StepAsync(order.Id, "OutForDelivery");
        var delivered = await scene.StepAsync(order.Id, "Delivered");
        delivered.Status.Should().Be("Delivered");
        delivered.IsPaid.Should().BeTrue("cash is taken on delivery");
        delivered.DueToBusiness.Should().Be(0m, "Zuno owes nothing on a cash order");
        delivered.ClosesAt.Should().Be(scene.Test.Now.AddDays(10));
        delivered.Actions.Should().BeEmpty();
        delivered.Events.Select(e => e.Status).Should().Equal("Placed", "Confirmed", "Shipped", "OutForDelivery", "Delivered");
        delivered.Events.Single(e => e.Status == "Shipped").Note.Should().Be("DTDC · D45120098871");
    }

    [Fact]
    public async Task Online_Order_Is_Confirmed_Only_After_A_Proven_Payment()
    {
        using var scene = new Scene();

        var order = await scene.PlaceAsync("Online", 1, scene.Blue);
        order.Status.Should().Be("AwaitingPayment");
        order.Amount.Should().Be(2600m, "the colour's own price wins over the product's");
        order.PayBy.Should().Be(scene.Test.Now.AddMinutes(15));
        scene.StockOf(scene.Blue).Should().Be(2, "the stock is held while the customer pays");

        var forged = () => scene.PayAsync(order.Id, signature: "forged");
        await forged.Should().ThrowAsync<DomainException>();
        scene.Test.Db.Orders.AsNoTracking().Single().Status.Should().Be(MarketplaceOrderStatus.AwaitingPayment);

        var paid = await scene.PayAsync(order.Id);
        paid.Status.Should().Be("Confirmed");
        paid.IsPaid.Should().BeTrue();
        paid.DueToBusiness.Should().Be(2600m);
        paid.PaymentMethodName.Should().Be("Online pay");

        // Reported again (the window reporting twice): counted once.
        var again = await scene.Customers.Handle(
            new CompleteMarketplaceOrderPaymentCommand
            {
                Id = order.Id, ProviderOrderId = $"order_{order.Id:N}", PaymentId = $"pay_{order.Id:N}", Signature = "good",
            },
            CancellationToken.None);
        again.Events.Count(e => e.Status == "Confirmed").Should().Be(1);

        // Paying again once confirmed: nothing is waiting.
        var payAgain = () => scene.PayAsync(order.Id);
        await payAgain.Should().ThrowAsync<DomainException>();
    }

    [Fact]
    public async Task Business_Cannot_Confirm_An_Unpaid_Online_Order_Or_Skip_Steps()
    {
        using var scene = new Scene();
        var online = await scene.PlaceAsync("Online", 1);
        var cash = await scene.PlaceAsync("CashOnDelivery", 1);

        var confirmUnpaid = () => scene.StepAsync(online.Id, "Confirmed");
        await confirmUnpaid.Should().ThrowAsync<DomainException>();

        var skipToDelivered = () => scene.StepAsync(cash.Id, "Delivered");
        await skipToDelivered.Should().ThrowAsync<DomainException>();

        var shipWithoutConfirm = () => scene.ShipAsync(cash.Id);
        await shipWithoutConfirm.Should().ThrowAsync<DomainException>();

        await scene.StepAsync(cash.Id, "Confirmed");
        var shipByStatusAlone = () => scene.StepAsync(cash.Id, "Shipped");
        (await shipByStatusAlone.Should().ThrowAsync<DomainException>()).WithMessage("*courier*tracking number*");

        var businessCancels = () => scene.StepAsync(cash.Id, "Cancelled");
        await businessCancels.Should().ThrowAsync<DomainException>("only the customer cancels");
    }

    [Fact]
    public async Task Ship_Sheet_Needs_A_Listed_Courier_And_Other_Needs_Its_Name()
    {
        using var scene = new Scene();
        var order = await scene.PlaceAsync();
        await scene.StepAsync(order.Id, "Confirmed");

        var unknown = () => scene.ShipAsync(order.Id, courier: "pigeon");
        await unknown.Should().ThrowAsync<DomainException>();

        var otherWithoutName = () => scene.ShipAsync(order.Id, courier: "other");
        await otherWithoutName.Should().ThrowAsync<DomainException>();

        var shipped = await scene.ShipAsync(order.Id, courier: "other", name: "  Anbu Parcel Service ", number: " AP-7781 ");
        shipped.CourierName.Should().Be("Anbu Parcel Service");
        shipped.TrackingNumber.Should().Be("AP-7781");
        shipped.TrackingUrl.Should().BeNull();
    }

    [Fact]
    public async Task Tracking_Link_Comes_From_The_Couriers_Table()
    {
        using var scene = new Scene();
        var order = await scene.PlaceAsync();
        await scene.StepAsync(order.Id, "Confirmed");

        var shipped = await scene.ShipAsync(order.Id, courier: "delhivery", number: "1490-21");
        shipped.TrackingUrl.Should().Be("https://www.delhivery.com/track/package/1490-21");
    }

    [Theory]
    [InlineData("", "Enter the tracking number")]
    [InlineData("AB 12", "letters, digits and dashes")]
    [InlineData("-123", "letters, digits and dashes")]
    public void Ship_Validator_Checks_The_Tracking_Number(string number, string message)
    {
        var result = new ShipMarketplaceOrderCommandValidator().TestValidate(
            new ShipMarketplaceOrderCommand { Id = Guid.NewGuid(), CourierCode = "dtdc", TrackingNumber = number });
        result.Errors.Should().ContainSingle(e => e.PropertyName == nameof(ShipMarketplaceOrderCommand.TrackingNumber))
            .Which.ErrorMessage.Should().Contain(message);
    }

    [Fact]
    public async Task Customer_Cancels_Before_Shipping_And_The_Stock_Goes_Back()
    {
        using var scene = new Scene();
        var order = await scene.PlaceAsync(quantity: 3);
        await scene.StepAsync(order.Id, "Confirmed");
        scene.StockOf(scene.Red).Should().Be(2);

        var cancelled = await scene.CancelAsync(order.Id);
        cancelled.Status.Should().Be("Cancelled");
        cancelled.CancelledBy.Should().Be("Customer");
        cancelled.RefundDue.Should().BeFalse("nothing was paid");
        scene.StockOf(scene.Red).Should().Be(5);
        scene.PostQuantity().Should().Be(8);

        // Sent twice: already cancelled, nothing given back twice.
        await scene.CancelAsync(order.Id);
        scene.StockOf(scene.Red).Should().Be(5);
    }

    [Fact]
    public async Task Customer_Cannot_Cancel_Once_Shipped()
    {
        using var scene = new Scene();
        var order = await scene.PlaceAsync();
        await scene.StepAsync(order.Id, "Confirmed");
        await scene.ShipAsync(order.Id);

        var cancel = () => scene.CancelAsync(order.Id);
        (await cancel.Should().ThrowAsync<DomainException>()).WithMessage("*shipped*no longer be cancelled*");

        scene.Test.As(Customer);
        var mine = await scene.Customers.Handle(new GetMyMarketplaceOrdersQuery(), CancellationToken.None);
        mine.Items.Single().Actions.Should().BeEmpty("no cancel button after shipping");
    }

    [Fact]
    public async Task Cancelling_A_Paid_Online_Order_Refunds_It_Now_Or_Through_The_Job()
    {
        using var scene = new Scene();
        var order = await scene.PlaceAsync("Online", 1);
        await scene.PayAsync(order.Id);

        scene.Gateway.RefundFails = true;
        var cancelled = await scene.CancelAsync(order.Id);
        cancelled.RefundDue.Should().BeTrue("the gateway did not take the refund this time");
        cancelled.Refunded.Should().BeFalse();
        cancelled.DueToBusiness.Should().Be(0m);

        scene.Gateway.RefundFails = false;
        var run = await scene.Jobs.Handle(new RunMarketplaceOrderJobsCommand(), CancellationToken.None);
        run.Refunded.Should().Be(1);
        scene.Gateway.Refunded.Should().ContainSingle();
        var row = scene.Test.Db.Orders.AsNoTracking().Single();
        row.RefundDue.Should().BeFalse();
        row.RefundId.Should().NotBeNull();
    }

    [Fact]
    public async Task Unpaid_Online_Order_Is_Let_Go_After_The_Hold_Unless_The_Gateway_Says_Paid()
    {
        using var scene = new Scene();
        var unpaid = await scene.PlaceAsync("Online", 2);
        var paidInUpiApp = await scene.PlaceAsync("Online", 1, scene.Blue);

        // The second customer's UPI app took the money, but their app closed before reporting it.
        scene.Test.As(Customer);
        var checkout = await scene.Customers.Handle(new StartMarketplaceOrderPaymentCommand { Id = paidInUpiApp.Id }, CancellationToken.None);
        scene.Gateway.Captured[checkout.ProviderOrderId] = "pay_upi";

        var early = await scene.Jobs.Handle(new RunMarketplaceOrderJobsCommand(), CancellationToken.None);
        early.Total.Should().Be(0, "nothing is let go before the hold ends");

        scene.Test.Clock.Current = scene.Test.Now.AddMinutes(16);
        scene.Test.Db.ChangeTracker.Clear();
        var run = await scene.Jobs.Handle(new RunMarketplaceOrderJobsCommand(), CancellationToken.None);
        run.Lapsed.Should().Be(1);

        var rows = scene.Test.Db.Orders.AsNoTracking().ToList();
        var lapsed = rows.Single(o => o.Id == unpaid.Id);
        lapsed.Status.Should().Be(MarketplaceOrderStatus.Cancelled);
        lapsed.CancelledBy.Should().Be(MarketplaceOrderActor.System);
        scene.StockOf(scene.Red).Should().Be(5, "the held stock went back");

        var confirmed = rows.Single(o => o.Id == paidInUpiApp.Id);
        confirmed.Status.Should().Be(MarketplaceOrderStatus.Confirmed);
        confirmed.ProviderPaymentId.Should().Be("pay_upi");
        scene.StockOf(scene.Blue).Should().Be(2);
    }

    [Fact]
    public async Task Paying_After_The_Order_Was_Let_Go_Gives_The_Money_Back()
    {
        using var scene = new Scene();
        var order = await scene.PlaceAsync("Online", 1);
        scene.Test.As(Customer);
        var checkout = await scene.Customers.Handle(new StartMarketplaceOrderPaymentCommand { Id = order.Id }, CancellationToken.None);

        scene.Test.Clock.Current = scene.Test.Now.AddMinutes(20);
        scene.Test.Db.ChangeTracker.Clear();
        await scene.Jobs.Handle(new RunMarketplaceOrderJobsCommand(), CancellationToken.None);

        var late = await scene.Customers.Handle(
            new CompleteMarketplaceOrderPaymentCommand
            {
                Id = order.Id, ProviderOrderId = checkout.ProviderOrderId, PaymentId = "pay_late", Signature = "good",
            },
            CancellationToken.None);
        late.Status.Should().Be("Cancelled");
        late.Refunded.Should().BeTrue();
        scene.Gateway.Refunded.Should().Equal("pay_late");
    }

    [Fact]
    public async Task Delivered_Order_Closes_With_A_Review_Or_By_Itself_After_Ten_Days()
    {
        using var scene = new Scene();
        var reviewed = await scene.PlaceAsync(quantity: 1);
        var silent = await scene.PlaceAsync(quantity: 1, customer: OtherCustomer);
        foreach (var id in new[] { reviewed.Id, silent.Id })
        {
            await scene.StepAsync(id, "Confirmed");
            await scene.ShipAsync(id);
            await scene.StepAsync(id, "Delivered");
        }

        scene.Test.As(Customer);
        var early = () => scene.Customers.Handle(new ReviewMarketplaceOrderCommand { Id = silent.Id, Score = 5 }, CancellationToken.None);
        await early.Should().ThrowAsync<ForbiddenException>("it is another customer's order");

        var closed = await scene.Customers.Handle(
            new ReviewMarketplaceOrderCommand { Id = reviewed.Id, Score = 4, Comment = " Good quality, came in 3 days. " },
            CancellationToken.None);
        closed.Status.Should().Be("Closed");
        closed.RatingScore.Should().Be(4);
        closed.RatingComment.Should().Be("Good quality, came in 3 days.");

        var twice = () => scene.Customers.Handle(new ReviewMarketplaceOrderCommand { Id = reviewed.Id, Score = 1 }, CancellationToken.None);
        await twice.Should().ThrowAsync<DomainException>();

        scene.Test.Clock.Current = scene.Test.Now.AddDays(9);
        (await scene.Jobs.Handle(new RunMarketplaceOrderJobsCommand(), CancellationToken.None)).Closed.Should().Be(0);

        scene.Test.Clock.Current = scene.Test.Now.AddDays(10);
        scene.Test.Db.ChangeTracker.Clear();
        (await scene.Jobs.Handle(new RunMarketplaceOrderJobsCommand(), CancellationToken.None)).Closed.Should().Be(1);
        var autoClosed = scene.Test.Db.Orders.AsNoTracking().Single(o => o.Id == silent.Id);
        autoClosed.Status.Should().Be(MarketplaceOrderStatus.Closed);
        autoClosed.RatingScore.Should().BeNull();
    }

    [Fact]
    public async Task Review_Waits_For_Delivery()
    {
        using var scene = new Scene();
        var order = await scene.PlaceAsync();
        scene.Test.As(Customer);
        var review = () => scene.Customers.Handle(new ReviewMarketplaceOrderCommand { Id = order.Id, Score = 5 }, CancellationToken.None);
        await review.Should().ThrowAsync<DomainException>();
    }

    [Fact]
    public async Task Orders_Are_Refused_Beyond_Stock_On_Own_Products_And_For_Ways_The_Seller_Does_Not_Take()
    {
        using var scene = new Scene();

        var tooMany = () => scene.PlaceAsync(quantity: 6);
        (await tooMany.Should().ThrowAsync<DomainException>()).WithMessage("Only 5 left*");

        var own = () => scene.PlaceAsync(customer: TestMarketplace.OwnerA);
        await own.Should().ThrowAsync<DomainException>();

        scene.Test.As(TestMarketplace.OwnerA);
        await scene.Business.Handle(
            new UpdateMarketplacePaymentSettingsCommand { AcceptsCashOnDelivery = false, AcceptsOnlinePay = true }, CancellationToken.None);
        var cash = () => scene.PlaceAsync("CashOnDelivery");
        (await cash.Should().ThrowAsync<DomainException>()).WithMessage("*online payment only*");

        scene.Gateway.IsReady = false;
        var online = () => scene.PlaceAsync("Online");
        await online.Should().ThrowAsync<DomainException>("online pay cannot be taken without a gateway");
        scene.StockOf(scene.Red).Should().Be(5, "nothing refused holds stock");
    }

    [Fact]
    public async Task A_Product_With_Colours_Needs_One_That_Is_On_Sale()
    {
        using var scene = new Scene();
        var noColour = () => scene.Customers.Handle(
            new PlaceMarketplaceOrderCommand
            {
                PostId = scene.Saree.Id, Quantity = 1, PaymentMethod = "CashOnDelivery", DeliveryAddress = "x", Pincode = "629001",
            },
            CancellationToken.None);
        scene.Test.As(Customer);
        await noColour.Should().ThrowAsync<DomainException>();

        var blue = scene.Test.Db.PostVariants.Single(v => v.Id == scene.Blue);
        blue.IsActive = false;
        scene.Test.Db.SaveChanges();
        var switchedOff = () => scene.PlaceAsync(variant: scene.Blue);
        await switchedOff.Should().ThrowAsync<DomainException>();
    }

    [Fact]
    public async Task Another_Business_Cannot_Open_Or_Move_The_Order()
    {
        using var scene = new Scene();
        var order = await scene.PlaceAsync();

        scene.Test.As(TestMarketplace.OwnerB);
        var open = () => scene.Business.Handle(new GetBusinessMarketplaceOrderQuery { Id = order.Id }, CancellationToken.None);
        await open.Should().ThrowAsync<ForbiddenException>();
        var move = () => scene.Business.Handle(new ChangeMarketplaceOrderStatusCommand { Id = order.Id, Status = "Confirmed" }, CancellationToken.None);
        await move.Should().ThrowAsync<ForbiddenException>();

        var theirs = await scene.Business.Handle(new GetBusinessMarketplaceOrdersQuery(), CancellationToken.None);
        theirs.Items.Should().BeEmpty();
    }

    [Fact]
    public async Task Business_List_Counts_Every_Status_And_Filters_By_One()
    {
        using var scene = new Scene();
        var a = await scene.PlaceAsync(quantity: 1);
        await scene.PlaceAsync(quantity: 1);
        await scene.PlaceAsync("Online", 1, scene.Blue);
        await scene.StepAsync(a.Id, "Confirmed");

        scene.Test.As(TestMarketplace.OwnerA);
        var all = await scene.Business.Handle(new GetBusinessMarketplaceOrdersQuery(), CancellationToken.None);
        all.TotalCount.Should().Be(3);
        all.Counts.Select(c => c.Status).Should().Equal(
            "Placed", "AwaitingPayment", "Confirmed", "Shipped", "OutForDelivery", "Delivered", "Closed", "Cancelled");
        all.Counts.Single(c => c.Status == "Placed").Count.Should().Be(1);
        all.Counts.Single(c => c.Status == "Confirmed").Count.Should().Be(1);
        all.Counts.Single(c => c.Status == "AwaitingPayment").Count.Should().Be(1);
        all.Items.Should().OnlyContain(o => o.Events.Count == 0, "the list leaves the history to the detail");

        var confirmed = await scene.Business.Handle(new GetBusinessMarketplaceOrdersQuery { Status = "Confirmed" }, CancellationToken.None);
        confirmed.Items.Should().ContainSingle(o => o.Id == a.Id);
    }

    [Fact]
    public async Task Receipt_Photo_Only_After_Shipping_And_Replaces_The_Earlier_One()
    {
        using var scene = new Scene();
        var order = await scene.PlaceAsync();
        scene.Test.As(TestMarketplace.OwnerA);
        var early = () => scene.Business.Handle(new SetMarketplaceOrderReceiptCommand { OrderId = order.Id }, CancellationToken.None);
        await early.Should().ThrowAsync<DomainException>();

        await scene.StepAsync(order.Id, "Confirmed");
        await scene.ShipAsync(order.Id);
        var first = await scene.Business.Handle(new SetMarketplaceOrderReceiptCommand { OrderId = order.Id }, CancellationToken.None);
        var second = await scene.Business.Handle(new SetMarketplaceOrderReceiptCommand { OrderId = order.Id }, CancellationToken.None);
        second.ReceiptUrl.Should().NotBe(first.ReceiptUrl);
        scene.Test.Storage.Deleted.Should().Equal(first.ReceiptUrl);
    }

    [Fact]
    public async Task Payment_Settings_Keep_One_Way_To_Pay_And_Start_With_Both()
    {
        using var scene = new Scene();
        scene.Test.As(TestMarketplace.OwnerB);
        var unknown = await scene.Business.Handle(new GetMarketplacePaymentSettingsQuery(), CancellationToken.None);
        unknown.AcceptsCashOnDelivery.Should().BeTrue();
        unknown.AcceptsOnlinePay.Should().BeTrue();
        unknown.OnlinePayAvailable.Should().BeTrue();

        new UpdateMarketplacePaymentSettingsCommandValidator()
            .TestValidate(new UpdateMarketplacePaymentSettingsCommand())
            .IsValid.Should().BeFalse("at least one way to pay stays on");

        // A business Marketplace has not met yet is set up from its Service profile.
        var saved = await scene.Business.Handle(
            new UpdateMarketplacePaymentSettingsCommand { AcceptsCashOnDelivery = true }, CancellationToken.None);
        saved.AcceptsOnlinePay.Should().BeFalse();
        scene.Test.Db.Businesses.AsNoTracking().Single(b => b.OwnerUserId == TestMarketplace.OwnerB).Name.Should().Be("shajil shajil");
    }

    [Fact]
    public void Order_Steps_Are_Rows_And_Cancel_Stops_At_Shipped()
    {
        var steps = MarketplaceOrderSeedData.Transitions;
        steps.Where(t => t.CustomerMay).Select(t => t.FromStatus).Should().BeEquivalentTo(
            [MarketplaceOrderStatus.AwaitingPayment, MarketplaceOrderStatus.Placed, MarketplaceOrderStatus.Confirmed]);
        steps.Should().OnlyContain(t => t.BusinessMay != t.CustomerMay, "each step belongs to one side");
        steps.Should().NotContain(t => t.ToStatus == MarketplaceOrderStatus.Confirmed && t.FromStatus == MarketplaceOrderStatus.AwaitingPayment,
            "only a proven payment confirms an online order");
        MarketplaceOrderSeedData.Statuses.Select(s => s.Code).Should().BeEquivalentTo(Enum.GetValues<MarketplaceOrderStatus>());
        MarketplaceOrderSeedData.Couriers.Should().ContainSingle(c => c.TakesCustomName);
    }
}
