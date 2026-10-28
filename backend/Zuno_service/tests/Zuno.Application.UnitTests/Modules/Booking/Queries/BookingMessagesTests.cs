using FluentAssertions;
using MediatR;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.Commands.SendBookingMessage;
using Zuno.Application.Modules.Booking.Queries.GetBookingMessages;
using Zuno.Application.Modules.Booking.Queries.GetMyBookingThreads;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.Booking.Queries;

/// <summary>
/// Messages on a booking: who may read them, who may write, and what counts as unread.
/// </summary>
/// <remarks>
/// The access rule is the reason most of these exist. A booking's thread carries addresses, times and
/// what was agreed, and it is open to exactly two people — the customer who placed the order and the
/// owner of the business holding it. A guessed id must not reveal so much as whether the booking is
/// real, which is why a stranger is refused rather than handed an empty list.
/// </remarks>
public class BookingMessagesTests
{
    private readonly Mock<ICurrentUserService> _currentUser = new();
    private readonly Mock<IDateTimeProvider> _clock = new();
    private readonly Mock<IApplicationDbContext> _db = new();
    private readonly Mock<IPublisher> _publisher = new();

    private readonly Guid _customerUserId = Guid.NewGuid();
    private readonly Guid _businessUserId = Guid.NewGuid();
    private readonly Guid _bookingId = Guid.NewGuid();
    private readonly DateTimeOffset _now = new(2026, 10, 6, 9, 0, 0, TimeSpan.Zero);

    public BookingMessagesTests()
    {
        _clock.Setup(c => c.UtcNow).Returns(_now);
    }

    private Domain.Entities.Booking Booking(
        BookingStatus status = BookingStatus.Confirmed,
        bool rated = false) => new()
    {
        Rating = rated ? new Rating { Score = 5 } : null,
        Id = _bookingId,
        ScheduledDate = _now.AddDays(3),
        BookingStatus = status,
        CustomerProfile = new CustomerProfile
        {
            UserId = _customerUserId,
            User = new User { FirstName = "Zuno", LastName = "Customer" },
        },
        BusinessOwnerProfile = new BusinessOwnerProfile
        {
            UserId = _businessUserId,
            BusinessName = "Kerala Painters",
            User = new User { FirstName = "Meera", LastName = "Nair" },
        },
        BusinessService = new BusinessService { Name = "Painting" },
    };

    private BookingMessage Message(
        BookingPartyRole from,
        string body,
        int minutesAgo,
        DateTimeOffset? readAt = null) => new()
    {
        Id = Guid.NewGuid(),
        BookingId = _bookingId,
        SenderRole = from,
        SenderUserId = from == BookingPartyRole.Customer ? _customerUserId : _businessUserId,
        Body = body,
        CreatedDate = _now.AddMinutes(-minutesAgo),
        ReadAt = readAt,
    };

    private void Given(Domain.Entities.Booking booking, params BookingMessage[] messages)
    {
        booking.Messages = messages.ToList();
        _db.Setup(d => d.Bookings).Returns(TestDbSet.From(booking));
        _db.Setup(d => d.BookingThreadClears).Returns(TestDbSet.From<BookingThreadClear>());
        _db.Setup(d => d.BookingMessages).Returns(TestDbSet.From(messages));
        _db.Setup(d => d.Users).Returns(
            TestDbSet.From(
                new User { Id = _customerUserId, FirstName = "Zuno", LastName = "Customer" },
                new User { Id = _businessUserId, FirstName = "Meera", LastName = "Nair" }));
    }

    private GetBookingMessagesQueryHandler Reader() =>
        new(_currentUser.Object, _clock.Object, _db.Object);

    // ---- who may read -------------------------------------------------------------------------

    [Fact]
    public async Task A_stranger_is_refused_rather_than_shown_an_empty_thread()
    {
        // An empty thread would confirm the booking exists, which is already more than somebody who
        // guessed an id should learn.
        Given(Booking(), Message(BookingPartyRole.Customer, "What time?", 10));
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());

        var act = () => Reader().Handle(new GetBookingMessagesQuery(_bookingId), default);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Fact]
    public async Task The_customer_on_the_order_may_read_it()
    {
        Given(Booking(), Message(BookingPartyRole.Business, "We arrive at 9.", 10));
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        var result = await Reader().Handle(new GetBookingMessagesQuery(_bookingId), default);

        result.Should().HaveCount(1);
    }

    [Fact]
    public async Task And_so_may_the_business_that_holds_it()
    {
        Given(Booking(), Message(BookingPartyRole.Customer, "Is 9 too early?", 10));
        _currentUser.Setup(c => c.UserId).Returns(_businessUserId);

        var result = await Reader().Handle(new GetBookingMessagesQuery(_bookingId), default);

        result.Should().HaveCount(1);
    }

    [Fact]
    public async Task A_stranger_may_not_write_either()
    {
        Given(Booking());
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());

        var sut = new SendBookingMessageCommandHandler(
            _currentUser.Object, _clock.Object, _db.Object, _publisher.Object);

        var act = () => sut.Handle(
            new SendBookingMessageCommand { BookingId = _bookingId, Body = "Hello" },
            default);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    // ---- when a thread is open at all ---------------------------------------------------------

    private SendBookingMessageCommandHandler Sender() =>
        new(_currentUser.Object, _clock.Object, _db.Object, _publisher.Object);

    [Theory]
    [InlineData(BookingStatus.Confirmed)]
    [InlineData(BookingStatus.Assigned)]
    [InlineData(BookingStatus.InProgress)]
    [InlineData(BookingStatus.Completed)]
    public async Task Messages_can_be_sent_once_the_business_has_taken_the_order_on(
        BookingStatus status)
    {
        Given(Booking(status));
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        var result = await Sender().Handle(
            new SendBookingMessageCommand { BookingId = _bookingId, Body = "On my way" },
            default);

        result.Body.Should().Be("On my way");
    }

    [Fact]
    public async Task But_not_before_it_is_confirmed()
    {
        // Nothing has been agreed yet. The offer on the booking is where a pending order is settled.
        Given(Booking(BookingStatus.Pending));
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        var act = () => Sender().Handle(
            new SendBookingMessageCommand { BookingId = _bookingId, Body = "Hello" },
            default);

        (await act.Should().ThrowAsync<DomainException>())
            .WithMessage("*confirmed*");
    }

    [Fact]
    public async Task And_never_once_it_is_cancelled()
    {
        Given(Booking(BookingStatus.Cancelled));
        _currentUser.Setup(c => c.UserId).Returns(_businessUserId);

        var act = () => Sender().Handle(
            new SendBookingMessageCommand { BookingId = _bookingId, Body = "Still coming?" },
            default);

        (await act.Should().ThrowAsync<DomainException>())
            .WithMessage("*cancelled*");
    }

    [Fact]
    public async Task Rating_a_finished_order_closes_its_conversation()
    {
        // Rating is the customer's last act on an order — offered once, and it cannot be taken back.
        // The window between finishing and rating is where a missing item or an invoice gets sorted
        // out; once they have rated, that is done.
        Given(Booking(BookingStatus.Completed, rated: true));
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        var act = () => Sender().Handle(
            new SendBookingMessageCommand { BookingId = _bookingId, Body = "One more thing" },
            default);

        (await act.Should().ThrowAsync<DomainException>()).WithMessage("*rated*");
    }

    [Fact]
    public async Task A_finished_order_stays_open_until_it_is_rated()
    {
        Given(Booking(BookingStatus.Completed));
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        var result = await Sender().Handle(
            new SendBookingMessageCommand { BookingId = _bookingId, Body = "Invoice please" },
            default);

        result.Body.Should().Be("Invoice please");
    }

    [Fact]
    public async Task The_business_is_shut_out_by_the_rating_too()
    {
        // Closed is closed. A business must not be able to keep writing to somebody who has finished
        // with the order.
        Given(Booking(BookingStatus.Completed, rated: true));
        _currentUser.Setup(c => c.UserId).Returns(_businessUserId);

        var act = () => Sender().Handle(
            new SendBookingMessageCommand { BookingId = _bookingId, Body = "Thanks!" },
            default);

        await act.Should().ThrowAsync<DomainException>();
    }

    [Fact]
    public async Task A_rated_order_drops_off_the_chat_list()
    {
        Given(
            Booking(BookingStatus.Completed, rated: true),
            Message(BookingPartyRole.Business, "Earlier message", 60));
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        var result = await Threads().Handle(new GetMyBookingThreadsQuery(), default);

        result.Should().BeEmpty();
    }

    [Theory]
    [InlineData(BookingStatus.Pending)]
    [InlineData(BookingStatus.Cancelled)]
    public async Task A_thread_nobody_may_answer_is_kept_off_the_chat_list(
        BookingStatus status)
    {
        // Even with messages on it: listing one would offer a conversation that refuses every reply.
        Given(Booking(status), Message(BookingPartyRole.Business, "Earlier message", 60));
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        var result = await Threads().Handle(new GetMyBookingThreadsQuery(), default);

        result.Should().BeEmpty();
    }

    // ---- what the thread reads like -----------------------------------------------------------

    [Fact]
    public async Task Messages_come_back_oldest_first()
    {
        // A conversation reads downwards, and the client scrolls to the bottom.
        Given(
            Booking(),
            Message(BookingPartyRole.Customer, "first", 30),
            Message(BookingPartyRole.Business, "second", 20),
            Message(BookingPartyRole.Customer, "third", 10));
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        var result = await Reader().Handle(new GetBookingMessagesQuery(_bookingId), default);

        result.Select(m => m.Body).Should().Equal("first", "second", "third");
    }

    [Fact]
    public async Task Each_side_is_told_which_messages_are_its_own()
    {
        // Worked out here so the app does not have to know which role it signed in as to decide
        // which side of the screen a bubble belongs on.
        Given(
            Booking(),
            Message(BookingPartyRole.Customer, "mine", 20),
            Message(BookingPartyRole.Business, "theirs", 10));
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        var result = await Reader().Handle(new GetBookingMessagesQuery(_bookingId), default);

        result.Single(m => m.Body == "mine").IsMine.Should().BeTrue();
        result.Single(m => m.Body == "theirs").IsMine.Should().BeFalse();
    }

    [Fact]
    public async Task The_same_thread_read_by_the_other_side_flips_whose_is_whose()
    {
        Given(
            Booking(),
            Message(BookingPartyRole.Customer, "mine", 20),
            Message(BookingPartyRole.Business, "theirs", 10));
        _currentUser.Setup(c => c.UserId).Returns(_businessUserId);

        var result = await Reader().Handle(new GetBookingMessagesQuery(_bookingId), default);

        result.Single(m => m.Body == "theirs").IsMine.Should().BeTrue();
        result.Single(m => m.Body == "mine").IsMine.Should().BeFalse();
    }

    // ---- reading is what marks them read ------------------------------------------------------

    [Fact]
    public async Task Opening_the_thread_marks_the_other_sides_messages_read()
    {
        var fromBusiness = Message(BookingPartyRole.Business, "We arrive at 9.", 10);
        Given(Booking(), fromBusiness);
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        await Reader().Handle(new GetBookingMessagesQuery(_bookingId), default);

        fromBusiness.ReadAt.Should().Be(_now);
        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task But_never_your_own()
    {
        // Your own message is not something you can read; marking it would make the sender's own
        // ticks say the other side had seen it.
        var mine = Message(BookingPartyRole.Customer, "Is 9 too early?", 10);
        Given(Booking(), mine);
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        await Reader().Handle(new GetBookingMessagesQuery(_bookingId), default);

        mine.ReadAt.Should().BeNull();
    }

    [Fact]
    public async Task A_thread_with_nothing_new_is_not_written_to()
    {
        var alreadyRead = Message(BookingPartyRole.Business, "Seen it", 60, readAt: _now.AddMinutes(-30));
        Given(Booking(), alreadyRead);
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        await Reader().Handle(new GetBookingMessagesQuery(_bookingId), default);

        alreadyRead.ReadAt.Should().Be(_now.AddMinutes(-30));
        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    // ---- the chat list ------------------------------------------------------------------------

    private GetMyBookingThreadsQueryHandler Threads() =>
        new(_currentUser.Object, _db.Object);

    [Fact]
    public async Task A_booking_nobody_has_written_on_is_not_a_conversation()
    {
        // Otherwise the chat tab lists every order a customer has ever placed.
        Given(Booking());
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        var result = await Threads().Handle(new GetMyBookingThreadsQuery(), default);

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task A_thread_shows_the_other_side_and_the_last_thing_said()
    {
        Given(
            Booking(),
            Message(BookingPartyRole.Customer, "Is 9 too early?", 30),
            Message(BookingPartyRole.Business, "We arrive at 9.", 5));
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        var thread = (await Threads().Handle(new GetMyBookingThreadsQuery(), default)).Single();

        thread.CounterpartName.Should().Be("Kerala Painters");
        thread.LastMessage.Should().Be("We arrive at 9.");
        thread.LastMessageIsMine.Should().BeFalse();
        thread.Title.Should().Be("Painting");
    }

    [Fact]
    public async Task The_business_sees_the_customer_as_the_other_side()
    {
        Given(Booking(), Message(BookingPartyRole.Customer, "Is 9 too early?", 5));
        _currentUser.Setup(c => c.UserId).Returns(_businessUserId);

        var thread = (await Threads().Handle(new GetMyBookingThreadsQuery(), default)).Single();

        thread.CounterpartName.Should().Be("Zuno Customer");
        thread.LastMessageIsMine.Should().BeFalse();
    }

    [Fact]
    public async Task Unread_counts_only_what_the_other_side_sent()
    {
        Given(
            Booking(),
            Message(BookingPartyRole.Business, "one", 30),
            Message(BookingPartyRole.Business, "two", 20),
            Message(BookingPartyRole.Customer, "my own, never unread for me", 10));
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        var thread = (await Threads().Handle(new GetMyBookingThreadsQuery(), default)).Single();

        thread.UnreadCount.Should().Be(2);
    }

    // ---- clearing a thread --------------------------------------------------------------------

    private void GivenCleared(
        Domain.Entities.Booking booking,
        DateTimeOffset clearedAt,
        Guid userId,
        params BookingMessage[] messages)
    {
        var clear = new BookingThreadClear
        {
            BookingId = _bookingId,
            UserId = userId,
            ClearedAt = clearedAt,
        };

        booking.Messages = messages.ToList();
        booking.ThreadClears = [clear];

        _db.Setup(d => d.Bookings).Returns(TestDbSet.From(booking));
        _db.Setup(d => d.BookingMessages).Returns(TestDbSet.From(messages));
        _db.Setup(d => d.BookingThreadClears).Returns(TestDbSet.From(clear));
        _db.Setup(d => d.Users).Returns(
            TestDbSet.From(
                new User { Id = _customerUserId, FirstName = "Zuno", LastName = "Customer" },
                new User { Id = _businessUserId, FirstName = "Meera", LastName = "Nair" }));
    }

    [Fact]
    public async Task Clearing_hides_what_was_said_before_it()
    {
        GivenCleared(
            Booking(),
            _now.AddMinutes(-15),
            _customerUserId,
            Message(BookingPartyRole.Business, "old", 30),
            Message(BookingPartyRole.Customer, "also old", 20));
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        var result = await Reader().Handle(new GetBookingMessagesQuery(_bookingId), default);

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task But_leaves_the_other_sides_copy_alone()
    {
        // The point of clearing being per person: a thread is where a time or an address was agreed,
        // and one party must not be able to erase the other's record of it.
        GivenCleared(
            Booking(),
            _now.AddMinutes(-15),
            _customerUserId,
            Message(BookingPartyRole.Business, "old", 30));
        _currentUser.Setup(c => c.UserId).Returns(_businessUserId);

        var result = await Reader().Handle(new GetBookingMessagesQuery(_bookingId), default);

        result.Should().HaveCount(1);
    }

    [Fact]
    public async Task And_anything_said_afterwards_comes_back()
    {
        // Clearing says "I am done with this", not "never speak to me about this order".
        GivenCleared(
            Booking(),
            _now.AddMinutes(-15),
            _customerUserId,
            Message(BookingPartyRole.Business, "old", 30),
            Message(BookingPartyRole.Business, "new", 5));
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        var result = await Reader().Handle(new GetBookingMessagesQuery(_bookingId), default);

        result.Single().Body.Should().Be("new");
    }

    [Fact]
    public async Task A_cleared_thread_leaves_the_chat_list_until_somebody_writes()
    {
        GivenCleared(
            Booking(),
            _now.AddMinutes(-15),
            _customerUserId,
            Message(BookingPartyRole.Business, "old", 30));
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        var result = await Threads().Handle(new GetMyBookingThreadsQuery(), default);

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task Unread_after_clearing_counts_only_the_new()
    {
        GivenCleared(
            Booking(),
            _now.AddMinutes(-15),
            _customerUserId,
            Message(BookingPartyRole.Business, "old and unread", 30),
            Message(BookingPartyRole.Business, "new", 5));
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        var thread = (await Threads().Handle(new GetMyBookingThreadsQuery(), default)).Single();

        thread.UnreadCount.Should().Be(1);
        thread.LastMessage.Should().Be("new");
    }

    [Fact]
    public async Task And_stops_counting_the_ones_already_read()
    {
        Given(
            Booking(),
            Message(BookingPartyRole.Business, "seen", 30, readAt: _now.AddMinutes(-25)),
            Message(BookingPartyRole.Business, "new", 10));
        _currentUser.Setup(c => c.UserId).Returns(_customerUserId);

        var thread = (await Threads().Handle(new GetMyBookingThreadsQuery(), default)).Single();

        thread.UnreadCount.Should().Be(1);
    }
}
