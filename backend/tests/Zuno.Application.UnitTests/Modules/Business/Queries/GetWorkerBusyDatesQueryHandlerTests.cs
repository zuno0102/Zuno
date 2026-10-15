using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.Queries.GetWorkerBusyDates;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.Business.Queries;

/// <summary>
/// Whose diary a business may read.
/// </summary>
/// <remarks>
/// This endpoint answered for <b>any</b> worker id, to <b>any</b> signed-in business owner. The
/// role check on the controller did not help: every attacker here already holds a legitimate
/// business account, and worker ids are not secret — they travel in the crew list of every order
/// a worker is on.
///
/// What leaked is when somebody is working, which is when they are working for a competitor. A
/// business can read its own crew's diary because it must, to avoid double-booking them; it has
/// no reason to read anybody else's.
/// </remarks>
public class GetWorkerBusyDatesQueryHandlerTests
{
    private readonly Mock<ICurrentUserService> _currentUser = new();
    private readonly Mock<IBusinessOwnerProfileRepository> _businesses = new();
    private readonly Mock<IBusinessWorkerRepository> _teams = new();
    private readonly Mock<IWorkerScheduleService> _schedule = new();

    private readonly Guid _ownerUserId = Guid.NewGuid();
    private readonly Guid _businessId = Guid.NewGuid();
    private readonly Guid _workerProfileId = Guid.NewGuid();

    private readonly GetWorkerBusyDatesQueryHandler _sut;

    public GetWorkerBusyDatesQueryHandlerTests()
    {
        _currentUser.Setup(c => c.UserId).Returns(_ownerUserId);

        _businesses
            .Setup(b => b.GetByUserIdAsync(_ownerUserId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new BusinessOwnerProfile { Id = _businessId, UserId = _ownerUserId });

        _schedule
            .Setup(s => s.GetCommitmentsAsync(
                It.IsAny<IReadOnlyCollection<Guid>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync([
                new WorkerCommitment(
                    _workerProfileId,
                    new DateTimeOffset(2026, 11, 14, 10, 0, 0, TimeSpan.Zero),
                    new DateTimeOffset(2026, 11, 14, 14, 0, 0, TimeSpan.Zero)),
            ]);

        _sut = new GetWorkerBusyDatesQueryHandler(
            _currentUser.Object,
            _businesses.Object,
            _teams.Object,
            _schedule.Object);
    }

    private void OnMyTeam(bool yes) =>
        _teams
            .Setup(t => t.GetByBusinessAndWorkerAsync(
                _businessId, _workerProfileId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(yes
                ? new BusinessWorker
                {
                    BusinessOwnerProfileId = _businessId,
                    WorkerProfileId = _workerProfileId,
                }
                : null);

    [Fact]
    public async Task A_business_can_read_its_own_crews_diary()
    {
        OnMyTeam(true);

        var result = await _sut.Handle(
            new GetWorkerBusyDatesQuery { WorkerProfileId = _workerProfileId }, default);

        result.Should().HaveCount(1);
    }

    /// <remarks>
    /// The breach. A verified business owner, a real worker id, and no relationship between them.
    /// </remarks>
    [Fact]
    public async Task A_business_cannot_read_somebody_elses_workers_diary()
    {
        OnMyTeam(false);

        var act = () => _sut.Handle(
            new GetWorkerBusyDatesQuery { WorkerProfileId = _workerProfileId }, default);

        await act.Should().ThrowAsync<EntityNotFoundException>();
    }

    /// <remarks>
    /// Not found rather than forbidden: a refusal would confirm that a guessed id belongs to a
    /// real worker, which is already more than a stranger should learn from guessing.
    /// </remarks>
    [Fact]
    public async Task And_is_told_nothing_about_whether_that_worker_exists()
    {
        OnMyTeam(false);

        var act = () => _sut.Handle(
            new GetWorkerBusyDatesQuery { WorkerProfileId = _workerProfileId }, default);

        await act.Should().ThrowAsync<EntityNotFoundException>();

        // Nothing was read, so nothing could leak through timing or a partial answer either.
        _schedule.Verify(
            s => s.GetCommitmentsAsync(
                It.IsAny<IReadOnlyCollection<Guid>>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task Somebody_with_no_business_at_all_is_refused()
    {
        _businesses
            .Setup(b => b.GetByUserIdAsync(_ownerUserId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((BusinessOwnerProfile?)null);

        var act = () => _sut.Handle(
            new GetWorkerBusyDatesQuery { WorkerProfileId = _workerProfileId }, default);

        await act.Should().ThrowAsync<EntityNotFoundException>();
    }

    [Fact]
    public async Task Nobody_signed_in_is_refused()
    {
        _currentUser.Setup(c => c.UserId).Returns((Guid?)null);

        var act = () => _sut.Handle(
            new GetWorkerBusyDatesQuery { WorkerProfileId = _workerProfileId }, default);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }
}
