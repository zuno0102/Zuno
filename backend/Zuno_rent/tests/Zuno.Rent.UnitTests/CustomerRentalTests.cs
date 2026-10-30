using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Customer;
using Zuno.Rent.Application.Orders;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.UnitTests;

/// <summary>
/// The customer side: what they may see, the shuffled home, search, booking (with the same stock
/// rule as the business), their orders, cancelling, and talking to the business.
/// </summary>
public class CustomerRentalTests : IDisposable
{
    private static readonly Guid CustomerC = Guid.NewGuid();
    private static readonly Guid CustomerD = Guid.NewGuid();

    private readonly TestRent _rent = new();
    private readonly FakeDirectory _directory = new();

    public void Dispose() => _rent.Dispose();

    private RentalBrowseHandlers Browse => new(_rent.Db, _rent.Settings, TimeProvider.System);

    private CustomerRentalOrderHandlers Orders => new(_rent.User, _rent.Db, _directory, _rent.Settings, TimeProvider.System);

    private RentalOrderMessageHandlers Messages => new(_rent.User, _rent.Db, TimeProvider.System, _rent.Settings);

    private async Task<Guid> ItemAsync(string name, int quantity = 2000, bool available = true, Action<Application.Items.CreateRentalItemCommand>? change = null)
    {
        _rent.As(TestRent.OwnerA);
        var id = (await _rent.SaveHandlers.Handle(TestRent.Machine(c =>
        {
            c.Name = name;
            c.QuantityOwned = quantity;
            c.IsAvailable = available;
            change?.Invoke(c);
        }), default)).Id;
        _rent.Db.ChangeTracker.Clear();
        return id;
    }

    private async Task VerifyAsync(Guid owner, bool verified = true)
    {
        _rent.Db.RentalBusinesses.Add(new RentalBusiness { OwnerUserId = owner, Name = "Joy Rentals", IsVerified = verified });
        await _rent.Db.SaveChangesAsync();
        _rent.Db.ChangeTracker.Clear();
    }

    private static BookRentalCommand Book(Guid item, int quantity, List<RentalAnswerInput>? answers = null) => new()
    {
        RentalItemId = item,
        Quantity = quantity,
        StartDate = DateTimeOffset.UtcNow.AddDays(10),
        EndDate = DateTimeOffset.UtcNow.AddDays(12),
        DeliveryAddress = "St. Mary's Hall, Kakkanad",
        DistrictId = TestRent.Ernakulam,
        Answers = answers ?? [],
    };

    private TestRent AsCustomer(Guid? customer = null) => _rent.As(customer ?? CustomerC);

    [Fact]
    public async Task Customers_see_only_switched_on_items_of_verified_businesses()
    {
        await VerifyAsync(TestRent.OwnerA);
        var shown = await ItemAsync("Plastic chair");
        await ItemAsync("Broken tent", available: false);
        _rent.As(TestRent.OwnerB);
        await _rent.SaveHandlers.Handle(TestRent.Machine(c => c.Name = "Unverified business item"), default);
        await VerifyAsync(TestRent.OwnerB, verified: false);
        AsCustomer();

        var found = await Browse.Handle(new SearchRentalsQuery(), default);

        found.Select(c => c.Name).Should().Equal("Plastic chair");
        found.Single().BusinessName.Should().Be("Joy Rentals");
        found.Single().UnitSuffix.Should().Be("/day");
        (await Browse.Handle(new GetRentalItemDetailQuery { Id = shown }, default)).Card.Id.Should().Be(shown);
    }

    [Fact]
    public async Task A_hidden_item_does_not_exist_to_customers()
    {
        await VerifyAsync(TestRent.OwnerA);
        var off = await ItemAsync("Broken tent", available: false);
        AsCustomer();

        var open = () => Browse.Handle(new GetRentalItemDetailQuery { Id = off }, default);
        var book = () => Orders.Handle(Book(off, 1), default);

        await open.Should().ThrowAsync<EntityNotFoundException>();
        await book.Should().ThrowAsync<EntityNotFoundException>();
    }

    [Fact]
    public async Task The_home_is_shuffled_by_seed_and_laid_out_by_the_section_table()
    {
        await VerifyAsync(TestRent.OwnerA);
        for (var i = 1; i <= 30; i++)
        {
            await ItemAsync($"Item {i:D2}");
        }

        AsCustomer();

        var first = await Browse.Handle(new GetRentalHomeQuery { Seed = 1 }, default);
        var again = await Browse.Handle(new GetRentalHomeQuery { Seed = 1 }, default);
        var other = await Browse.Handle(new GetRentalHomeQuery { Seed = 2 }, default);

        first.Select(s => (s.Title, s.Layout)).Should().Equal(
            ("Popular near you", "Strip"), ("Explore", "Grid"), ("More to rent", "Strip"), ("All rentals", "Grid"));
        Names(first).Should().Equal(Names(again), "the same seed is the same home");
        Names(other).Should().NotEqual(Names(first), "a refresh brings a different mix");
        first.SelectMany(s => s.Items).Select(c => c.Id).Should().OnlyHaveUniqueItems("no item shows twice on one page");

        static List<string> Names(List<RentalHomeSectionDto> home) => home.SelectMany(s => s.Items).Select(c => c.Name).ToList();
    }

    [Fact]
    public async Task Search_narrows_by_words_category_and_district()
    {
        await VerifyAsync(TestRent.OwnerA);
        await ItemAsync("Plastic chair", change: c => { c.RentalCategoryId = Zuno.Rent.Infrastructure.Persistence.Seed.RentalCategorySeedData.FurnitureSeating; c.RentalSubCategoryId = TestRent.PlasticChairs; });
        await ItemAsync("Cutting machine");
        await ItemAsync("Thrissur ladder", change: c => c.DistrictIds = [TestRent.Thrissur]);
        AsCustomer();

        (await Browse.Handle(new SearchRentalsQuery { Keyword = "CHAIR" }, default)).Select(c => c.Name).Should().Equal("Plastic chair");
        (await Browse.Handle(new SearchRentalsQuery { CategoryId = Zuno.Rent.Infrastructure.Persistence.Seed.RentalCategorySeedData.FurnitureSeating }, default))
            .Select(c => c.Name).Should().Equal("Plastic chair");
        (await Browse.Handle(new SearchRentalsQuery { DistrictIds = [TestRent.Thrissur] }, default))
            .Select(c => c.Name).Should().Equal("Thrissur ladder");
    }

    [Fact]
    public async Task Booking_uses_the_stock_rule_and_the_name_from_the_account()
    {
        await VerifyAsync(TestRent.OwnerA);
        var chairs = await ItemAsync("Plastic chair", 2000);
        AsCustomer();
        await Orders.Handle(Book(chairs, 1700), default);

        var tooMany = () => Orders.Handle(Book(chairs, 500), default);
        await tooMany.Should().ThrowAsync<DomainException>().WithMessage("Only 300 Plastic chair available*");

        var order = await Orders.Handle(Book(chairs, 300), default);
        order.CustomerName.Should().Be("Rahul Nair", "from the customer's own account");
        order.CustomerPhone.Should().Be("9876543210");
        order.Source.Should().Be("App");
        order.BusinessName.Should().Be("Joy Rentals");
        order.Actions.Should().ContainSingle(a => a.ToStatus == "Cancelled", "a customer may only cancel");
    }

    [Fact]
    public async Task Required_questions_must_be_answered_and_answers_reach_the_business()
    {
        await VerifyAsync(TestRent.OwnerA);
        var chairs = await ItemAsync("Plastic chair", change: c => c.Questions =
        [
            new RentalQuestionInput { Prompt = "Event date and venue", IsRequired = true },
            new RentalQuestionInput { Prompt = "Delivery needed?" },
        ]);
        var questions = await _rent.Db.RentalItemQuestions.AsNoTracking().OrderBy(q => q.SortOrder).ToListAsync();
        AsCustomer();

        var unanswered = () => Orders.Handle(Book(chairs, 10), default);
        await unanswered.Should().ThrowAsync<DomainException>().WithMessage("Please answer: Event date and venue");

        var order = await Orders.Handle(Book(chairs, 10, [new() { QuestionId = questions[0].Id, Answer = "Sunday, St. Mary's Hall" }]), default);

        _rent.As(TestRent.OwnerA);
        var seenByBusiness = await new RentalOrderQueryHandlers(_rent.User, _rent.Db, _rent.Settings)
            .Handle(new GetRentalOrderQuery { Id = order.Id }, default);
        seenByBusiness.Answers.Should().ContainSingle(a => a.Prompt == "Event date and venue" && a.Answer == "Sunday, St. Mary's Hall");
        seenByBusiness.Source.Should().Be("App");
    }

    [Fact]
    public async Task A_district_outside_the_items_area_or_own_item_is_refused()
    {
        await VerifyAsync(TestRent.OwnerA);
        var chairs = await ItemAsync("Plastic chair");
        AsCustomer();

        var command = Book(chairs, 1);
        command.DistrictId = TestRent.Thrissur;
        await ((Func<Task>)(() => Orders.Handle(command, default))).Should().ThrowAsync<DomainException>().WithMessage("*not offered in that district*");

        _rent.As(TestRent.OwnerA);
        await ((Func<Task>)(() => Orders.Handle(Book(chairs, 1), default))).Should().ThrowAsync<DomainException>().WithMessage("*own item*");
    }

    [Fact]
    public async Task The_customer_cancels_only_while_booked_and_the_history_says_so()
    {
        await VerifyAsync(TestRent.OwnerA);
        var chairs = await ItemAsync("Plastic chair");
        AsCustomer();
        var booked = await Orders.Handle(Book(chairs, 10), default);
        var sentOut = await Orders.Handle(Book(chairs, 10), default);

        _rent.As(TestRent.OwnerA);
        await new ChangeRentalOrderStatusCommandHandler(_rent.User, _rent.Db)
            .Handle(new ChangeRentalOrderStatusCommand { Id = sentOut.Id, ToStatus = "OnRent" }, default);
        AsCustomer();

        (await Orders.Handle(new CancelMyRentalCommand { Id = booked.Id }, default)).StatusName.Should().Be("Cancelled");
        await ((Func<Task>)(() => Orders.Handle(new CancelMyRentalCommand { Id = sentOut.Id }, default)))
            .Should().ThrowAsync<DomainException>("the pieces are already out");

        var history = await new GetRentalOrderHistoryQueryHandler(_rent.User, _rent.Db)
            .Handle(new GetMyRentalOrderHistoryQuery { RentalOrderId = booked.Id }, default);
        history.Select(h => h.Title).Should().Equal("Booked by customer", "Cancelled");
    }

    [Fact]
    public async Task A_customer_sees_only_their_own_orders()
    {
        await VerifyAsync(TestRent.OwnerA);
        var chairs = await ItemAsync("Plastic chair");
        AsCustomer();
        var mine = await Orders.Handle(Book(chairs, 10), default);

        AsCustomer(CustomerD);
        (await Orders.Handle(new GetMyRentalsQuery(), default)).TotalCount.Should().Be(0);
        await ((Func<Task>)(() => Orders.Handle(new GetMyRentalQuery { Id = mine.Id }, default))).Should().ThrowAsync<ForbiddenException>();
        await ((Func<Task>)(() => Orders.Handle(new CancelMyRentalCommand { Id = mine.Id }, default))).Should().ThrowAsync<ForbiddenException>();
        await ((Func<Task>)(() => Messages.Handle(new GetMyRentalOrderMessagesQuery { RentalOrderId = mine.Id }, default)))
            .Should().ThrowAsync<ForbiddenException>();
    }

    [Fact]
    public async Task Customer_and_business_talk_and_each_sees_the_others_unread()
    {
        await VerifyAsync(TestRent.OwnerA);
        var chairs = await ItemAsync("Plastic chair");
        AsCustomer();
        var order = await Orders.Handle(Book(chairs, 10), default);

        var sent = await Messages.Handle(new SendMyRentalOrderMessageCommand { RentalOrderId = order.Id, Body = "Can you deliver by 9 am?" }, default);
        sent.IsMine.Should().BeTrue();

        _rent.As(TestRent.OwnerA);
        (await Messages.Handle(new GetRentalOrderThreadsQuery(), default)).Single().UnreadCount.Should().Be(1);
        var forBusiness = await Messages.Handle(new GetRentalOrderMessagesQuery { RentalOrderId = order.Id }, default);
        forBusiness.Single().SenderName.Should().Be("Rahul Nair");
        await Messages.Handle(new SendRentalOrderMessageCommand { RentalOrderId = order.Id, Body = "Yes, 8:30." }, default);

        AsCustomer();
        var thread = (await Messages.Handle(new GetMyRentalOrderThreadsQuery(), default)).Single();
        thread.UnreadCount.Should().Be(1);
        thread.BusinessName.Should().Be("Joy Rentals");
        var forCustomer = await Messages.Handle(new GetMyRentalOrderMessagesQuery { RentalOrderId = order.Id }, default);
        forCustomer.Select(m => (m.SenderName, m.IsMine)).Should().Equal(("You", true), ("Joy Rentals", false));
        (await Messages.Handle(new GetMyRentalOrderThreadsQuery(), default)).Single().UnreadCount.Should().Be(0);
    }

    [Fact]
    public async Task Sync_takes_the_business_name_and_verification_from_Service()
    {
        _rent.As(TestRent.OwnerA);
        _directory.Business = new ServiceBusiness("Joy Rentals", "/uploads/logo.png", IsVerified: true);

        var synced = await Orders.Handle(new SyncRentalBusinessCommand(), default);

        synced.IsVerified.Should().BeTrue();
        (await _rent.Db.RentalBusinesses.SingleAsync()).LogoUrl.Should().Be("/uploads/logo.png");

        _directory.Business = null;
        (await Orders.Handle(new SyncRentalBusinessCommand(), default)).Name.Should().Be("Joy Rentals", "Service down keeps what was known");
    }

    [Fact]
    public async Task Booking_waits_for_the_customers_profile()
    {
        await VerifyAsync(TestRent.OwnerA);
        var chairs = await ItemAsync("Plastic chair");
        AsCustomer();
        _directory.Person = null;

        var act = () => Orders.Handle(Book(chairs, 1), default);

        await act.Should().ThrowAsync<DomainException>().WithMessage("*could not read your profile*");
        (await _rent.Db.RentalOrders.CountAsync()).Should().Be(0);
    }

    private sealed class FakeDirectory : IServiceDirectory
    {
        public ServicePerson? Person { get; set; } = new("Rahul Nair", "9876543210");

        public ServiceBusiness? Business { get; set; }

        public Task<ServicePerson?> GetCurrentPersonAsync(CancellationToken cancellationToken) => Task.FromResult(Person);

        public Task<ServiceBusiness?> GetCurrentBusinessAsync(CancellationToken cancellationToken) => Task.FromResult(Business);
    }
}
