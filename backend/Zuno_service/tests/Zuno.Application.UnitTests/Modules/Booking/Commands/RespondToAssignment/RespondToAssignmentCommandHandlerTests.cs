using FluentAssertions;
using MediatR;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.Commands.RespondToAssignment;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.Booking.Commands.RespondToAssignment;

public class RespondToAssignmentCommandHandlerTests
{
    private readonly Mock<ICurrentUserService> _currentUserServiceMock = new();
    private readonly Mock<IDateTimeProvider> _dateTimeProviderMock = new();
    private readonly Mock<IBookingRepository> _bookingRepositoryMock = new();
    private readonly Mock<IApplicationDbContext> _dbContextMock = new();
    private readonly Mock<IPublisher> _publisherMock = new();
    private readonly DateTimeOffset _now = new(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);

    private readonly RespondToAssignmentCommandHandler _sut;

    public RespondToAssignmentCommandHandlerTests()
    {
        _dateTimeProviderMock.Setup(p => p.UtcNow).Returns(_now);
        _sut = new RespondToAssignmentCommandHandler(
            _currentUserServiceMock.Object,
            _dateTimeProviderMock.Object,
            _bookingRepositoryMock.Object,
            _dbContextMock.Object,
            _publisherMock.Object);
    }

    private static BookingWorkerAssignment CreateAssignment(
        Guid workerUserId,
        BookingWorkerAssignmentStatus status = BookingWorkerAssignmentStatus.Assigned) => new()
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
        CustomerProfile = new CustomerProfile { User = new User { FirstName = "Asha", LastName = "Rao" } },
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

    // A worker answering an offer moves their own row and nothing else. These three used to
    // assert the opposite — that accepting flipped the order to InProgress and rejecting reverted
    // it to Confirmed — which is exactly the conflation the crew and order tracks were split to
    // end. The handler stopped doing it; the tests were never updated.

    [Fact]
    public async Task Should_Accept_The_Assignment_Without_Touching_The_Order()
    {
        var workerUserId = Guid.NewGuid();
        var assignment = CreateAssignment(workerUserId);
        var booking = CreateBooking(BookingStatus.Confirmed, assignment);
        _currentUserServiceMock.Setup(c => c.UserId).Returns(workerUserId);
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        var result = await _sut.Handle(
            new RespondToAssignmentCommand { BookingId = booking.Id, Accept = true },
            CancellationToken.None);

        result.MyAssignmentStatus.Should().Be(nameof(BookingWorkerAssignmentStatus.Accepted));
        assignment.RespondedAt.Should().Be(_now);

        // Somebody saying yes is not the business saying the work has begun. Only Start work does
        // that, and only on the day.
        result.Status.Should().Be(nameof(BookingStatus.Confirmed));
        booking.WorkStartedAt.Should().BeNull();
        _dbContextMock.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Should_Reject_The_Assignment_Without_Touching_The_Order()
    {
        var workerUserId = Guid.NewGuid();
        var assignment = CreateAssignment(workerUserId);
        var booking = CreateBooking(BookingStatus.Confirmed, assignment);
        _currentUserServiceMock.Setup(c => c.UserId).Returns(workerUserId);
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        var result = await _sut.Handle(
            new RespondToAssignmentCommand { BookingId = booking.Id, Accept = false },
            CancellationToken.None);

        result.MyAssignmentStatus.Should().Be(nameof(BookingWorkerAssignmentStatus.Rejected));

        // The business confirmed this order; one worker turning it down does not un-confirm it.
        result.Status.Should().Be(nameof(BookingStatus.Confirmed));
    }

    [Fact]
    public async Task Should_Leave_A_Teammates_Row_Alone()
    {
        var workerUserId = Guid.NewGuid();
        var mine = CreateAssignment(workerUserId);
        var teammate = CreateAssignment(Guid.NewGuid(), BookingWorkerAssignmentStatus.Accepted);
        var booking = CreateBooking(BookingStatus.Confirmed, mine, teammate);
        _currentUserServiceMock.Setup(c => c.UserId).Returns(workerUserId);
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        var result = await _sut.Handle(
            new RespondToAssignmentCommand { BookingId = booking.Id, Accept = false },
            CancellationToken.None);

        result.Status.Should().Be(nameof(BookingStatus.Confirmed));
        mine.AssignmentStatus.Should().Be(BookingWorkerAssignmentStatus.Rejected);
        teammate.AssignmentStatus.Should().Be(BookingWorkerAssignmentStatus.Accepted);
    }

    [Fact]
    public async Task Should_Throw_When_Assignment_Belongs_To_A_Different_Worker()
    {
        var booking = CreateBooking(BookingStatus.Assigned, CreateAssignment(Guid.NewGuid()));
        _currentUserServiceMock.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        var act = () => _sut.Handle(
            new RespondToAssignmentCommand { BookingId = booking.Id, Accept = true },
            CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Fact]
    public async Task Should_Throw_When_Assignment_Was_Already_Responded_To()
    {
        var workerUserId = Guid.NewGuid();
        var assignment = CreateAssignment(workerUserId, BookingWorkerAssignmentStatus.Accepted);
        var booking = CreateBooking(BookingStatus.InProgress, assignment);
        _currentUserServiceMock.Setup(c => c.UserId).Returns(workerUserId);
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        var act = () => _sut.Handle(
            new RespondToAssignmentCommand { BookingId = booking.Id, Accept = true },
            CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>();
    }
}
