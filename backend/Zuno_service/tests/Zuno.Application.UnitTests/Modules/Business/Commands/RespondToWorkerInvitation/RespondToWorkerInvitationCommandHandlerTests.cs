using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.Commands.RespondToWorkerInvitation;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.Business.Commands.RespondToWorkerInvitation;

public class RespondToWorkerInvitationCommandHandlerTests
{
    private readonly Mock<ICurrentUserService> _currentUserServiceMock = new();
    private readonly Mock<IDateTimeProvider> _dateTimeProviderMock = new();
    private readonly Mock<IBusinessWorkerRepository> _businessWorkerRepositoryMock = new();
    private readonly Mock<IApplicationDbContext> _dbContextMock = new();
    private readonly DateTimeOffset _now = new(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);

    private readonly RespondToWorkerInvitationCommandHandler _sut;

    public RespondToWorkerInvitationCommandHandlerTests()
    {
        _dateTimeProviderMock.Setup(p => p.UtcNow).Returns(_now);
        _sut = new RespondToWorkerInvitationCommandHandler(
            _currentUserServiceMock.Object,
            _dateTimeProviderMock.Object,
            _businessWorkerRepositoryMock.Object,
            _dbContextMock.Object);
    }

    private static BusinessWorker CreateInvitation(Guid workerUserId, BusinessWorkerStatus status = BusinessWorkerStatus.Invited) => new()
    {
        Id = Guid.NewGuid(),
        WorkerProfile = new WorkerProfile
        {
            UserId = workerUserId,
            User = new User { Id = workerUserId, FirstName = "Ravi", LastName = "Kumar", Email = "ravi@example.com" },
        },
        BusinessOwnerProfile = new BusinessOwnerProfile { BusinessName = "Asha Home Services" },
        AssignmentStatus = status,
    };

    [Fact]
    public async Task Should_Activate_Assignment_When_Accepted()
    {
        var workerUserId = Guid.NewGuid();
        var invitation = CreateInvitation(workerUserId);
        _currentUserServiceMock.Setup(c => c.UserId).Returns(workerUserId);
        _businessWorkerRepositoryMock
            .Setup(r => r.GetByIdAsync(invitation.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(invitation);

        var result = await _sut.Handle(
            new RespondToWorkerInvitationCommand { Id = invitation.Id, Accept = true },
            CancellationToken.None);

        result.Status.Should().Be(nameof(BusinessWorkerStatus.Active));
        invitation.RespondedAt.Should().Be(_now);
        _dbContextMock.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Should_Reject_Assignment_When_Declined()
    {
        var workerUserId = Guid.NewGuid();
        var invitation = CreateInvitation(workerUserId);
        _currentUserServiceMock.Setup(c => c.UserId).Returns(workerUserId);
        _businessWorkerRepositoryMock
            .Setup(r => r.GetByIdAsync(invitation.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(invitation);

        var result = await _sut.Handle(
            new RespondToWorkerInvitationCommand { Id = invitation.Id, Accept = false },
            CancellationToken.None);

        result.Status.Should().Be(nameof(BusinessWorkerStatus.Rejected));
    }

    [Fact]
    public async Task Should_Throw_When_Invitation_Belongs_To_A_Different_Worker()
    {
        var invitation = CreateInvitation(Guid.NewGuid());
        _currentUserServiceMock.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _businessWorkerRepositoryMock
            .Setup(r => r.GetByIdAsync(invitation.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(invitation);

        var act = () => _sut.Handle(
            new RespondToWorkerInvitationCommand { Id = invitation.Id, Accept = true },
            CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Fact]
    public async Task Should_Throw_When_Invitation_Already_Responded_To()
    {
        var workerUserId = Guid.NewGuid();
        var invitation = CreateInvitation(workerUserId, BusinessWorkerStatus.Active);
        _currentUserServiceMock.Setup(c => c.UserId).Returns(workerUserId);
        _businessWorkerRepositoryMock
            .Setup(r => r.GetByIdAsync(invitation.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(invitation);

        var act = () => _sut.Handle(
            new RespondToWorkerInvitationCommand { Id = invitation.Id, Accept = true },
            CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>();
    }
}
