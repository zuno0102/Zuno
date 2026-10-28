using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.Commands.CompleteBooking;
using Zuno.Application.Modules.Booking.Events;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.Booking.Commands.CompleteBooking;

public class CompleteBookingCommandHandlerTests
{
    private readonly Mock<ICurrentUserService> _currentUserServiceMock = new();
    private readonly Mock<IDateTimeProvider> _dateTimeProviderMock = new();
    private readonly Mock<IBookingRepository> _bookingRepositoryMock = new();
    private readonly Mock<IApplicationDbContext> _dbContextMock = new();
    private readonly Mock<IBusinessReputationService> _reputationServiceMock = new();
    private readonly Mock<MediatR.IPublisher> _publisherMock = new();
    private readonly DateTimeOffset _now = new(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);

    /// <summary>Hiring posts in the database, for orders that raised one for their crew.</summary>
    private readonly List<HiringPost> _posts = [];

    private readonly CompleteBookingCommandHandler _sut;

    public CompleteBookingCommandHandlerTests()
    {
        _dateTimeProviderMock.Setup(p => p.UtcNow).Returns(_now);
        _dbContextMock.Setup(d => d.HiringPosts).Returns(() => TestDbSet.From(_posts.ToArray()));
        _sut = new CompleteBookingCommandHandler(
            _currentUserServiceMock.Object,
            _dateTimeProviderMock.Object,
            _bookingRepositoryMock.Object,
            _reputationServiceMock.Object,
            _dbContextMock.Object,
            _publisherMock.Object);
    }

    private static BookingWorkerAssignment CreateAssignment(
        Guid workerUserId,
        BookingWorkerAssignmentStatus status = BookingWorkerAssignmentStatus.Accepted) => new()
    {
        Id = Guid.NewGuid(),
        WorkerProfileId = Guid.NewGuid(),
        WorkerProfile = new WorkerProfile
        {
            UserId = workerUserId,
            User = new User { FirstName = "Ravi", LastName = "Kumar" },
        },
        AssignmentStatus = status,
    };

    private static Domain.Entities.Booking CreateBooking(
        BookingStatus status,
        params BookingWorkerAssignment[] assignments) => new()
    {
        Id = Guid.NewGuid(),
        CustomerProfile = new CustomerProfile
        {
            User = new User { FirstName = "Asha", LastName = "Rao", Email = "asha@example.com" },
        },
        BusinessOwnerProfile = new BusinessOwnerProfile
        {
            BusinessName = "Asha Home Services",
            User = new User { FirstName = "Meera", LastName = "Nair" },
        },
        BusinessService = new BusinessService { Name = "Deep Cleaning", ServiceCategory = new ServiceCategory { Name = "Cleaning" } },
        Address = new Address { Line1 = "12 MG Road", City = "Bengaluru", State = "KA", PostalCode = "560001" },
        BookingStatus = status,
        WorkerAssignments = assignments.ToList(),
    };

    [Fact]
    public async Task Should_Complete_Booking_When_The_Last_Active_Worker_Finishes()
    {
        var workerUserId = Guid.NewGuid();
        var assignment = CreateAssignment(workerUserId);
        var booking = CreateBooking(BookingStatus.InProgress, assignment);
        _currentUserServiceMock.Setup(c => c.UserId).Returns(workerUserId);
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        var result = await _sut.Handle(new CompleteBookingCommand { BookingId = booking.Id }, CancellationToken.None);

        result.Status.Should().Be(nameof(BookingStatus.Completed));
        booking.CompletedAt.Should().Be(_now);
        assignment.CompletedAt.Should().Be(_now);
        _publisherMock.Verify(p => p.Publish(It.IsAny<BookingCompletedEvent>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Should_Mark_The_Orders_Hiring_Post_Done_When_The_Order_Closes_So_Its_Crew_Can_Be_Paid()
    {
        var workerUserId = Guid.NewGuid();
        var booking = CreateBooking(BookingStatus.InProgress, CreateAssignment(workerUserId));
        var started = _now.AddHours(-5);
        booking.WorkStartedAt = started;
        var crewPost = new HiringPost { BookingId = booking.Id, Title = "Crew" };
        var otherOrdersPost = new HiringPost { BookingId = Guid.NewGuid(), Title = "Elsewhere" };
        _posts.AddRange([crewPost, otherOrdersPost]);
        _currentUserServiceMock.Setup(c => c.UserId).Returns(workerUserId);
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        await _sut.Handle(new CompleteBookingCommand { BookingId = booking.Id }, CancellationToken.None);

        // Paying the crew refuses a post whose work is not marked done.
        crewPost.WorkCompletedAt.Should().Be(_now);
        crewPost.WorkStartedAt.Should().Be(started);
        otherOrdersPost.WorkCompletedAt.Should().BeNull();
    }

    [Fact]
    public async Task Should_Leave_The_Hiring_Post_Open_While_The_Order_Is_Still_In_Progress()
    {
        var workerUserId = Guid.NewGuid();
        var booking = CreateBooking(BookingStatus.InProgress, CreateAssignment(workerUserId), CreateAssignment(Guid.NewGuid()));
        var crewPost = new HiringPost { BookingId = booking.Id, Title = "Crew" };
        _posts.Add(crewPost);
        _currentUserServiceMock.Setup(c => c.UserId).Returns(workerUserId);
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        await _sut.Handle(new CompleteBookingCommand { BookingId = booking.Id }, CancellationToken.None);

        crewPost.WorkCompletedAt.Should().BeNull();
    }

    [Fact]
    public async Task Should_Keep_Booking_InProgress_While_Other_Crew_Members_Are_Still_Working()
    {
        var workerUserId = Guid.NewGuid();
        var mine = CreateAssignment(workerUserId);
        var teammate = CreateAssignment(Guid.NewGuid());
        var booking = CreateBooking(BookingStatus.InProgress, mine, teammate);
        _currentUserServiceMock.Setup(c => c.UserId).Returns(workerUserId);
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        var result = await _sut.Handle(new CompleteBookingCommand { BookingId = booking.Id }, CancellationToken.None);

        result.Status.Should().Be(nameof(BookingStatus.InProgress));
        mine.AssignmentStatus.Should().Be(BookingWorkerAssignmentStatus.Completed);
        booking.CompletedAt.Should().BeNull();
        _publisherMock.Verify(p => p.Publish(It.IsAny<BookingCompletedEvent>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Should_Throw_When_Caller_Is_Not_The_Assigned_Worker()
    {
        var booking = CreateBooking(BookingStatus.InProgress, CreateAssignment(Guid.NewGuid()));
        _currentUserServiceMock.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        var act = () => _sut.Handle(new CompleteBookingCommand { BookingId = booking.Id }, CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Fact]
    public async Task Should_Throw_When_Booking_Is_Not_InProgress()
    {
        var workerUserId = Guid.NewGuid();
        var booking = CreateBooking(BookingStatus.Assigned, CreateAssignment(workerUserId));
        _currentUserServiceMock.Setup(c => c.UserId).Returns(workerUserId);
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        var act = () => _sut.Handle(new CompleteBookingCommand { BookingId = booking.Id }, CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>();
    }

    [Fact]
    public async Task Should_Throw_When_Assignment_Has_Not_Been_Accepted()
    {
        var workerUserId = Guid.NewGuid();
        var booking = CreateBooking(
            BookingStatus.InProgress,
            CreateAssignment(workerUserId, BookingWorkerAssignmentStatus.Assigned));
        _currentUserServiceMock.Setup(c => c.UserId).Returns(workerUserId);
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        var act = () => _sut.Handle(new CompleteBookingCommand { BookingId = booking.Id }, CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>();
    }
}
