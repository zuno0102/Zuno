using FluentAssertions;
using MediatR;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.Commands.CancelBooking;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.Booking.Commands.CancelBooking;

public class CancelBookingCommandHandlerTests
{
    private readonly Mock<ICurrentUserService> _currentUserServiceMock = new();
    private readonly Mock<IDateTimeProvider> _dateTimeProviderMock = new();
    private readonly Mock<IBookingRepository> _bookingRepositoryMock = new();
    private readonly Mock<IApplicationDbContext> _dbContextMock = new();
    private readonly Mock<IPublisher> _publisherMock = new();
    private readonly DateTimeOffset _now = new(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);

    private readonly CancelBookingCommandHandler _sut;

    public CancelBookingCommandHandlerTests()
    {
        _dateTimeProviderMock.Setup(p => p.UtcNow).Returns(_now);

        // Cancelling closes any hiring still advertising the job, so the handler reads this set.
        // Empty is the ordinary case: most orders were never hired for.
        _dbContextMock.Setup(d => d.HiringPosts).Returns(TestDbSet.From<HiringPost>());
        _sut = new CancelBookingCommandHandler(
            _currentUserServiceMock.Object,
            _dateTimeProviderMock.Object,
            _bookingRepositoryMock.Object,
            _dbContextMock.Object,
            _publisherMock.Object);
    }

    private static Domain.Entities.Booking CreateBooking(
        Guid customerUserId, Guid businessUserId, BookingStatus status = BookingStatus.Pending) => new()
    {
        Id = Guid.NewGuid(),
        CustomerProfile = new CustomerProfile { UserId = customerUserId, User = new User { FirstName = "Asha", LastName = "Rao" } },
        BusinessOwnerProfile = new BusinessOwnerProfile
        {
            UserId = businessUserId,
            BusinessName = "Asha Home Services",
            User = new User { FirstName = "Meera", LastName = "Nair" },
        },
        BusinessService = new BusinessService { Name = "Deep Cleaning", ServiceCategory = new ServiceCategory { Name = "Cleaning" } },
        Address = new Address { Line1 = "12 MG Road", City = "Bengaluru", State = "KA", PostalCode = "560001" },
        BookingStatus = status,
    };

    [Fact]
    public async Task Should_Cancel_When_Requested_By_Customer()
    {
        var customerUserId = Guid.NewGuid();
        var booking = CreateBooking(customerUserId, Guid.NewGuid());
        _currentUserServiceMock.Setup(c => c.UserId).Returns(customerUserId);
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        var result = await _sut.Handle(
            new CancelBookingCommand { BookingId = booking.Id, Reason = "Change of plans" },
            CancellationToken.None);

        result.Status.Should().Be(nameof(BookingStatus.Cancelled));
        result.CancellationReason.Should().Be("Change of plans");
        booking.CancelledAt.Should().Be(_now);
    }

    [Fact]
    public async Task Should_Cancel_When_Requested_By_Business()
    {
        var businessUserId = Guid.NewGuid();
        var booking = CreateBooking(Guid.NewGuid(), businessUserId);
        _currentUserServiceMock.Setup(c => c.UserId).Returns(businessUserId);
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        var result = await _sut.Handle(new CancelBookingCommand { BookingId = booking.Id }, CancellationToken.None);

        result.Status.Should().Be(nameof(BookingStatus.Cancelled));
    }

    [Fact]
    public async Task Should_Throw_When_Caller_Is_Neither_Customer_Nor_Business()
    {
        var booking = CreateBooking(Guid.NewGuid(), Guid.NewGuid());
        _currentUserServiceMock.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        var act = () => _sut.Handle(new CancelBookingCommand { BookingId = booking.Id }, CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Theory]
    [InlineData(BookingStatus.Completed)]
    [InlineData(BookingStatus.Cancelled)]
    public async Task Should_Throw_When_Booking_Is_Already_Finalized(BookingStatus status)
    {
        var customerUserId = Guid.NewGuid();
        var booking = CreateBooking(customerUserId, Guid.NewGuid(), status);
        _currentUserServiceMock.Setup(c => c.UserId).Returns(customerUserId);
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        var act = () => _sut.Handle(new CancelBookingCommand { BookingId = booking.Id }, CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>();
    }
}
