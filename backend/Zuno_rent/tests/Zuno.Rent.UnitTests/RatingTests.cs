using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Customer;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Application.Orders;
using Zuno.Rent.Application.Ratings;
using Zuno.Rent.Domain.Common;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.UnitTests;

/// <summary>
/// Ratings: a customer rates a rental once it is returned and fully paid, once; items show a fair
/// star average only from three ratings; and every business's totals are published for the Service API.
/// </summary>
public class RatingTests : IDisposable
{
    private static readonly Guid Customer = Guid.NewGuid();
    private static readonly Guid OtherCustomer = Guid.NewGuid();

    private readonly TestRent _rent = new();

    public void Dispose() => _rent.Dispose();

    private RentalRatingHandlers Ratings => new(_rent.User, _rent.Db);

    private RentalBrowseHandlers Browse => new(_rent.Db, _rent.Settings, TimeProvider.System);

    private GetMyRentalItemsQueryHandler MyItems => new(_rent.User, _rent.Db, _rent.Settings);

    private async Task<Guid> ItemAsync(Guid owner)
    {
        _rent.As(owner);
        var id = (await _rent.SaveHandlers.Handle(TestRent.Machine(), default)).Id;
        _rent.Db.RentalBusinesses.Add(new RentalBusiness { OwnerUserId = owner, Name = "Joy Rentals", IsVerified = true });
        await _rent.Db.SaveChangesAsync();
        _rent.Db.ChangeTracker.Clear();
        return id;
    }

    /// <summary>An order for ₹[amount] with ₹[paid] taken (and ₹[refunded] given back), as it stands now.</summary>
    private async Task<Guid> OrderAsync(
        Guid item,
        RentalOrderStatus status,
        decimal amount = 1000,
        decimal? paid = null,
        decimal refunded = 0,
        Guid? customer = null,
        Guid? parent = null,
        Guid? owner = null)
    {
        var start = new DateTimeOffset(DateTime.UtcNow.Date.AddDays(-3), TimeSpan.Zero);
        var order = new RentalOrder
        {
            RentalItemId = item,
            OwnerUserId = owner ?? TestRent.OwnerA,
            CustomerUserId = customer ?? Customer,
            ParentOrderId = parent,
            CustomerName = "Rahul Nair",
            Quantity = 1,
            StartDate = start,
            EndDate = start.AddDays(1),
            DeliveryAddress = "Kakkanad",
            Status = status,
            Source = RentalOrderSource.App,
            Amount = amount,
        };
        _rent.Db.RentalOrders.Add(order);
        AddPayment(order.Id, RentalPaymentKind.Balance, paid ?? amount);
        AddPayment(order.Id, RentalPaymentKind.Refund, refunded);
        await _rent.Db.SaveChangesAsync();
        _rent.Db.ChangeTracker.Clear();
        return order.Id;
    }

    private void AddPayment(Guid order, RentalPaymentKind kind, decimal amount)
    {
        if (amount <= 0)
        {
            return;
        }

        _rent.Db.RentalOrderPayments.Add(new RentalOrderPayment
        {
            RentalOrderId = order,
            Kind = kind,
            Method = RentalPaymentMethod.Cash,
            Amount = amount,
            RecordedByUserId = TestRent.OwnerA,
            RecordedByRole = RentalMessageSenderRole.Business,
        });
    }

    private async Task AddRatingsAsync(Guid item, Guid owner, params short[] scores)
    {
        foreach (var score in scores)
        {
            var order = await OrderAsync(item, RentalOrderStatus.Returned, owner: owner);
            _rent.Db.RentalOrderRatings.Add(new RentalOrderRating
            {
                RentalOrderId = order,
                RentalItemId = item,
                OwnerUserId = owner,
                CustomerUserId = Customer,
                Score = score,
            });
        }

        await _rent.Db.SaveChangesAsync();
        _rent.Db.ChangeTracker.Clear();
    }

    private Task<RentalOrderDto> RateAsync(Guid order, short score = 5, string? comment = null, Guid? asUser = null)
    {
        _rent.As(asUser ?? Customer);
        return Ratings.Handle(new RateRentalOrderCommand { Id = order, Score = score, Comment = comment }, default);
    }

    private Task<RentalOrderDto> ReadAsync(Guid order, RentalAudience audience)
    {
        var user = audience == RentalAudience.Customer ? Customer : TestRent.OwnerA;
        _rent.As(user);
        return RentalOrderReader.ReadOneAsync(_rent.Db, order, user, default, audience);
    }

    [Fact]
    public async Task Rate_WhenReturnedAndFullyPaid_SavesTheRatingAndShowsItOnTheOrder()
    {
        var item = await ItemAsync(TestRent.OwnerA);
        var order = await OrderAsync(item, RentalOrderStatus.Returned);

        var dto = await RateAsync(order, 4, "  Clean chairs, on time.  ");

        dto.CanRate.Should().BeFalse();
        dto.MyRating.Should().Be(4);
        dto.MyRatingComment.Should().Be("Clean chairs, on time.");
        dto.CustomerRating.Should().Be(4);
        var saved = await _rent.Db.RentalOrderRatings.SingleAsync();
        saved.RentalOrderId.Should().Be(order);
        saved.RentalItemId.Should().Be(item);
        saved.OwnerUserId.Should().Be(TestRent.OwnerA);
        saved.CustomerUserId.Should().Be(Customer);
        saved.Score.Should().Be(4);
    }

    [Fact]
    public async Task Rate_WhenRefundedBackToFullyPaidOverpayment_IsAllowed()
    {
        var item = await ItemAsync(TestRent.OwnerA);
        var order = await OrderAsync(item, RentalOrderStatus.Returned, amount: 1000, paid: 1200, refunded: 200);

        (await RateAsync(order)).MyRating.Should().Be(5);
    }

    [Fact]
    public async Task Rate_WithABlankComment_KeepsNoComment()
    {
        var item = await ItemAsync(TestRent.OwnerA);
        var order = await OrderAsync(item, RentalOrderStatus.Returned);

        (await RateAsync(order, 5, "   ")).MyRatingComment.Should().BeNull();
    }

    [Theory]
    [InlineData(RentalOrderStatus.Returned, 999)]
    [InlineData(RentalOrderStatus.Returned, 0)]
    [InlineData(RentalOrderStatus.OnRent, 1000)]
    [InlineData(RentalOrderStatus.Booked, 1000)]
    [InlineData(RentalOrderStatus.Cancelled, 1000)]
    [InlineData(RentalOrderStatus.AwaitingAdvance, 0)]
    public async Task Rate_WhenNotReturnedOrBalanceDue_IsRefused(RentalOrderStatus status, decimal paid)
    {
        var item = await ItemAsync(TestRent.OwnerA);
        var order = await OrderAsync(item, status, amount: 1000, paid: paid);

        var act = () => RateAsync(order);

        await act.Should().ThrowAsync<DomainException>().WithMessage("You can rate a rental once it is returned and fully paid.");
        (await _rent.Db.RentalOrderRatings.AnyAsync()).Should().BeFalse();
    }

    [Fact]
    public async Task Rate_WhenPaidButPartRefunded_IsRefused()
    {
        var item = await ItemAsync(TestRent.OwnerA);
        var order = await OrderAsync(item, RentalOrderStatus.Returned, amount: 1000, paid: 1000, refunded: 100);

        var act = () => RateAsync(order);

        await act.Should().ThrowAsync<DomainException>();
    }

    [Fact]
    public async Task Rate_Twice_IsRefused()
    {
        var item = await ItemAsync(TestRent.OwnerA);
        var order = await OrderAsync(item, RentalOrderStatus.Returned);
        await RateAsync(order);

        var act = () => RateAsync(order, 1);

        await act.Should().ThrowAsync<DomainException>().WithMessage("You have already rated this rental.");
        (await _rent.Db.RentalOrderRatings.SingleAsync()).Score.Should().Be(5);
    }

    [Fact]
    public async Task Rate_ByAnotherCustomer_IsForbidden()
    {
        var item = await ItemAsync(TestRent.OwnerA);
        var order = await OrderAsync(item, RentalOrderStatus.Returned);

        var act = () => RateAsync(order, asUser: OtherCustomer);

        await act.Should().ThrowAsync<ForbiddenException>();
    }

    [Fact]
    public async Task Rate_ByTheBusiness_IsForbidden()
    {
        var item = await ItemAsync(TestRent.OwnerA);
        var order = await OrderAsync(item, RentalOrderStatus.Returned);

        var act = () => RateAsync(order, asUser: TestRent.OwnerA);

        await act.Should().ThrowAsync<ForbiddenException>();
    }

    [Fact]
    public async Task Rate_AnUnknownOrder_IsNotFound()
    {
        var act = () => RateAsync(Guid.NewGuid());

        await act.Should().ThrowAsync<EntityNotFoundException>();
    }

    [Fact]
    public async Task Rate_AnAddOn_IsRefused()
    {
        var item = await ItemAsync(TestRent.OwnerA);
        var parent = await OrderAsync(item, RentalOrderStatus.Returned);
        var addOn = await OrderAsync(item, RentalOrderStatus.Returned, parent: parent);

        var act = () => RateAsync(addOn);

        await act.Should().ThrowAsync<DomainException>().WithMessage("Extra pieces are rated with the rental they were added to.");
    }

    [Theory]
    [InlineData(0, false)]
    [InlineData(1, true)]
    [InlineData(5, true)]
    [InlineData(6, false)]
    [InlineData(-1, false)]
    public void Validator_ChecksTheScoreIsOneToFive(short score, bool valid)
    {
        var result = new RateRentalOrderCommandValidator().Validate(new RateRentalOrderCommand { Id = Guid.NewGuid(), Score = score });

        result.IsValid.Should().Be(valid);
        if (!valid)
        {
            result.Errors.Should().ContainSingle(e => e.PropertyName == nameof(RateRentalOrderCommand.Score));
        }
    }

    [Theory]
    [InlineData(1000, true)]
    [InlineData(1001, false)]
    public void Validator_LimitsTheComment(int length, bool valid)
    {
        var command = new RateRentalOrderCommand { Id = Guid.NewGuid(), Score = 5, Comment = new string('x', length) };

        new RateRentalOrderCommandValidator().Validate(command).IsValid.Should().Be(valid);
    }

    [Fact]
    public async Task Order_ReturnedAndPaid_CanBeRatedByTheCustomerOnly()
    {
        var item = await ItemAsync(TestRent.OwnerA);
        var order = await OrderAsync(item, RentalOrderStatus.Returned);

        var customer = await ReadAsync(order, RentalAudience.Customer);
        var business = await ReadAsync(order, RentalAudience.Business);

        customer.CanRate.Should().BeTrue();
        customer.MyRating.Should().BeNull();
        business.CanRate.Should().BeFalse();
    }

    [Theory]
    [InlineData(RentalOrderStatus.Returned, 500)]
    [InlineData(RentalOrderStatus.OnRent, 1000)]
    public async Task Order_NotSuccessful_CannotBeRated(RentalOrderStatus status, decimal paid)
    {
        var item = await ItemAsync(TestRent.OwnerA);
        var order = await OrderAsync(item, status, amount: 1000, paid: paid);

        (await ReadAsync(order, RentalAudience.Customer)).CanRate.Should().BeFalse();
    }

    [Fact]
    public async Task Order_AnAddOn_CannotBeRated()
    {
        var item = await ItemAsync(TestRent.OwnerA);
        var parent = await OrderAsync(item, RentalOrderStatus.Returned);
        var addOn = await OrderAsync(item, RentalOrderStatus.Returned, parent: parent);

        (await ReadAsync(addOn, RentalAudience.Customer)).CanRate.Should().BeFalse();
    }

    [Fact]
    public async Task Order_OnceRated_ShowsTheStarsToBothSides()
    {
        var item = await ItemAsync(TestRent.OwnerA);
        var order = await OrderAsync(item, RentalOrderStatus.Returned);
        await RateAsync(order, 3, "Two chairs broken");

        var business = await ReadAsync(order, RentalAudience.Business);

        business.CustomerRating.Should().Be(3);
        business.CustomerRatingComment.Should().Be("Two chairs broken");
        business.MyRating.Should().BeNull();
        business.CanRate.Should().BeFalse();
    }

    [Theory]
    [InlineData(new short[] { }, null, 0)]
    [InlineData(new short[] { 5 }, null, 1)]
    [InlineData(new short[] { 5, 5 }, null, 2)]
    [InlineData(new short[] { 5, 5, 5 }, 4.4, 3)]
    [InlineData(new short[] { 1, 1, 1 }, 2.9, 3)]
    public async Task Item_ShowsAFairAverageFromThreeRatings(short[] scores, double? average, int count)
    {
        var item = await ItemAsync(TestRent.OwnerA);
        await AddRatingsAsync(item, TestRent.OwnerA, scores);

        var detail = await Browse.Handle(new GetRentalItemDetailQuery { Id = item }, default);
        var cards = await Browse.Handle(new SearchRentalsQuery(), default);
        _rent.As(TestRent.OwnerA);
        var mine = await MyItems.Handle(new GetMyRentalItemsQuery(), default);

        var expected = (decimal?)average;
        detail.Card.RatingAverage.Should().Be(expected);
        detail.Card.RatingCount.Should().Be(count);
        cards.Single().RatingAverage.Should().Be(expected);
        cards.Single().RatingCount.Should().Be(count);
        mine.Items.Single().RatingAverage.Should().Be(expected);
        mine.Items.Single().RatingCount.Should().Be(count);
    }

    [Fact]
    public async Task Item_RatingsOfAnotherItem_DoNotCount()
    {
        var chairs = await ItemAsync(TestRent.OwnerA);
        var other = await ItemAsync(TestRent.OwnerB);
        await AddRatingsAsync(other, TestRent.OwnerB, 5, 5, 5);

        var detail = await Browse.Handle(new GetRentalItemDetailQuery { Id = chairs }, default);

        detail.Card.RatingAverage.Should().BeNull();
        detail.Card.RatingCount.Should().Be(0);
    }

    [Theory]
    [InlineData(15, 3, 4.4)]
    [InlineData(10, 2, null)]
    [InlineData(0, 0, null)]
    [InlineData(300, 100, 3.0)]
    [InlineData(500, 100, 5.0)]
    public void FairRating_MixesInFiveOrdinaryRatings(int sum, int count, double? expected) =>
        FairRating.Of(sum, count).Should().Be((decimal?)expected);

    [Fact]
    public async Task Reputation_SumsRatingsAndCountsSuccessfulMainOrdersPerBusiness()
    {
        var itemA = await ItemAsync(TestRent.OwnerA);
        var itemB = await ItemAsync(TestRent.OwnerB);

        // Business A: two rated successful orders, one unrated successful, plus orders that do not count.
        await AddRatingsAsync(itemA, TestRent.OwnerA, 5, 4);
        var mainA = await OrderAsync(itemA, RentalOrderStatus.Returned);
        await OrderAsync(itemA, RentalOrderStatus.Returned, parent: mainA);
        await OrderAsync(itemA, RentalOrderStatus.Returned, amount: 1000, paid: 400);
        await OrderAsync(itemA, RentalOrderStatus.OnRent);
        await OrderAsync(itemA, RentalOrderStatus.Cancelled, paid: 0);

        // Business B: one successful order, no ratings.
        await OrderAsync(itemB, RentalOrderStatus.Returned, owner: TestRent.OwnerB);

        var reputation = await Ratings.Handle(new GetRentalReputationQuery(), default);

        reputation.Items.Should().HaveCount(2);
        var a = reputation.Items.Single(i => i.OwnerUserId == TestRent.OwnerA);
        a.RatingSum.Should().Be(9);
        a.RatingCount.Should().Be(2);
        a.SuccessfulOrders.Should().Be(3);
        var b = reputation.Items.Single(i => i.OwnerUserId == TestRent.OwnerB);
        b.RatingSum.Should().Be(0);
        b.RatingCount.Should().Be(0);
        b.SuccessfulOrders.Should().Be(1);
    }

    [Fact]
    public async Task Reputation_ABusinessWithNoSuccessOrRating_IsLeftOut()
    {
        var item = await ItemAsync(TestRent.OwnerA);
        await OrderAsync(item, RentalOrderStatus.Booked, paid: 0);

        (await Ratings.Handle(new GetRentalReputationQuery(), default)).Items.Should().BeEmpty();
    }

    [Fact]
    public async Task Reputation_ARatingMadeThroughTheApp_IsCounted()
    {
        var item = await ItemAsync(TestRent.OwnerA);
        var order = await OrderAsync(item, RentalOrderStatus.Returned);
        await RateAsync(order, 2);

        var a = (await Ratings.Handle(new GetRentalReputationQuery(), default)).Items.Single();

        a.RatingSum.Should().Be(2);
        a.RatingCount.Should().Be(1);
        a.SuccessfulOrders.Should().Be(1);
    }
}
