using FluentAssertions;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.Commands.RateBooking;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.Booking.Commands.RateBooking;

public class RateBookingCommandHandlerTests
{
    private readonly Mock<ICurrentUserService> _currentUserServiceMock = new();
    private readonly Mock<IBookingRepository> _bookingRepositoryMock = new();
    private readonly Mock<IApplicationDbContext> _dbContextMock = new();
    private readonly Mock<DbSet<Rating>> _ratingsDbSetMock = new();
    private readonly Mock<IPublisher> _publisherMock = new();
    private readonly Mock<IBusinessReputationService> _reputationMock = new();

    private readonly RateBookingCommandHandler _sut;

    public RateBookingCommandHandlerTests()
    {
        _dbContextMock.Setup(d => d.Ratings).Returns(_ratingsDbSetMock.Object);
        _sut = new RateBookingCommandHandler(
            _currentUserServiceMock.Object,
            _bookingRepositoryMock.Object,
            _reputationMock.Object,
            _dbContextMock.Object,
            _publisherMock.Object);
    }

    private static Domain.Entities.Booking CreateBooking(
        Guid customerUserId, BookingStatus status = BookingStatus.Completed, Rating? rating = null) => new()
    {
        Id = Guid.NewGuid(),
        CustomerProfile = new CustomerProfile { UserId = customerUserId, User = new User { FirstName = "Asha", LastName = "Rao" } },
        BusinessOwnerProfile = new BusinessOwnerProfile { BusinessName = "Asha Home Services" },
        BusinessService = new BusinessService { Name = "Deep Cleaning", ServiceCategory = new ServiceCategory { Name = "Cleaning" } },
        Address = new Address { Line1 = "12 MG Road", City = "Bengaluru", State = "KA", PostalCode = "560001" },
        BookingStatus = status,
        Rating = rating,
    };

    /// <remarks>
    /// The bug this guards against: the rating was written to the table and never reached the
    /// business. Every other handler that changes what a business is worth recalculates its
    /// standing — finishing work, settling a payout, answering a payment — but rating did not. A
    /// business with one five-star job therefore read as unrated on its profile and in search
    /// until it happened to finish some *other* job, which swept the review up by accident.
    /// </remarks>
    [Fact]
    public async Task Rating_a_booking_updates_the_business_standing()
    {
        var customerUserId = Guid.NewGuid();
        var booking = CreateBooking(customerUserId);
        _currentUserServiceMock.Setup(c => c.UserId).Returns(customerUserId);
        _bookingRepositoryMock
            .Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(booking);

        await _sut.Handle(new RateBookingCommand { BookingId = booking.Id, Score = 5 }, default);

        _reputationMock.Verify(
            r => r.RecalculateAndSaveAsync(
                booking.BusinessOwnerProfileId, It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task Should_Create_Rating_When_Booking_Is_Completed_And_Unrated()
    {
        var customerUserId = Guid.NewGuid();
        var booking = CreateBooking(customerUserId);
        _currentUserServiceMock.Setup(c => c.UserId).Returns(customerUserId);
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        var result = await _sut.Handle(
            new RateBookingCommand { BookingId = booking.Id, Score = 5, Comment = "Great work!" },
            CancellationToken.None);

        result.Score.Should().Be(5);
        result.Comment.Should().Be("Great work!");
        _dbContextMock.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Should_Throw_When_Caller_Did_Not_Make_The_Booking()
    {
        var booking = CreateBooking(Guid.NewGuid());
        _currentUserServiceMock.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        var act = () => _sut.Handle(new RateBookingCommand { BookingId = booking.Id, Score = 5 }, CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Fact]
    public async Task Should_Throw_When_Booking_Is_Not_Completed()
    {
        var customerUserId = Guid.NewGuid();
        var booking = CreateBooking(customerUserId, BookingStatus.InProgress);
        _currentUserServiceMock.Setup(c => c.UserId).Returns(customerUserId);
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        var act = () => _sut.Handle(new RateBookingCommand { BookingId = booking.Id, Score = 5 }, CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>();
    }

    [Fact]
    public async Task Should_Throw_When_Booking_Already_Rated()
    {
        var customerUserId = Guid.NewGuid();
        var existingRating = new Rating { Score = 4 };
        var booking = CreateBooking(customerUserId, rating: existingRating);
        _currentUserServiceMock.Setup(c => c.UserId).Returns(customerUserId);
        _bookingRepositoryMock.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);

        var act = () => _sut.Handle(new RateBookingCommand { BookingId = booking.Id, Score = 5 }, CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>();
    }
}
