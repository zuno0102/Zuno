using FluentAssertions;
using MediatR;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.WorkChat.Commands.SendWorkMessage;
using Zuno.Application.Modules.WorkChat.Events;
using Zuno.Application.Modules.WorkChat.Queries.GetMyWorkThreads;
using Zuno.Application.Modules.WorkChat.Queries.GetWorkMessages;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.UnitTests.Modules.WorkChat;

/// <summary>
/// Messages between a business and a worker on its team: who may read and write, what is unread,
/// and what the conversation list shows.
/// </summary>
/// <remarks>
/// The business is the middle man: customers talk to the business, workers talk to the business,
/// and customers and workers never reach each other. This conversation opens when a worker is on
/// the business's team — which accepting a job makes them — and is refused to everyone else.
/// </remarks>
public class WorkMessagesTests
{
    private readonly Mock<ICurrentUserService> _currentUser = new();
    private readonly Mock<IDateTimeProvider> _clock = new();
    private readonly Mock<IApplicationDbContext> _db = new();
    private readonly Mock<IPublisher> _publisher = new();

    private readonly Guid _businessUserId = Guid.NewGuid();
    private readonly Guid _workerUserId = Guid.NewGuid();
    private readonly Guid _businessId = Guid.NewGuid();
    private readonly Guid _workerId = Guid.NewGuid();
    private readonly DateTimeOffset _now = new(2026, 10, 21, 9, 0, 0, TimeSpan.Zero);

    private readonly List<WorkMessage> _messages = [];

    public WorkMessagesTests()
    {
        _clock.Setup(c => c.UtcNow).Returns(_now);
    }

    private BusinessWorker Team(BusinessWorkerStatus status = BusinessWorkerStatus.Active) => new()
    {
        BusinessOwnerProfileId = _businessId,
        BusinessOwnerProfile = new BusinessOwnerProfile
        {
            Id = _businessId,
            UserId = _businessUserId,
            BusinessName = "Demo Painters",
            LogoUrl = "/logo.png",
        },
        WorkerProfileId = _workerId,
        WorkerProfile = new WorkerProfile
        {
            Id = _workerId,
            UserId = _workerUserId,
            User = new User { Id = _workerUserId, FirstName = "Ravi", LastName = "Kumar" },
        },
        AssignmentStatus = status,
    };

    private WorkMessage Message(WorkThreadRole from, string body, int minutesAgo, DateTimeOffset? readAt = null) => new()
    {
        Id = Guid.NewGuid(),
        BusinessOwnerProfileId = _businessId,
        WorkerProfileId = _workerId,
        SenderRole = from,
        SenderUserId = from == WorkThreadRole.Business ? _businessUserId : _workerUserId,
        Body = body,
        CreatedDate = _now.AddMinutes(-minutesAgo),
        ReadAt = readAt,
    };

    private void Given(BusinessWorker team, params WorkMessage[] messages)
    {
        _messages.Clear();
        _messages.AddRange(messages);
        _db.Setup(d => d.BusinessWorkers).Returns(TestDbSet.From(team));
        _db.Setup(d => d.WorkMessages).Returns(TestDbSet.From(_messages.ToArray()));
        _db.Setup(d => d.Users).Returns(
            TestDbSet.From(
                new User { Id = _businessUserId, FirstName = "Meera", LastName = "Nair" },
                new User { Id = _workerUserId, FirstName = "Ravi", LastName = "Kumar" }));
    }

    private void SignedInAs(Guid userId) => _currentUser.Setup(c => c.UserId).Returns(userId);

    private GetWorkMessagesQueryHandler Reader() => new(_currentUser.Object, _clock.Object, _db.Object);

    private SendWorkMessageCommandHandler Sender() =>
        new(_currentUser.Object, _clock.Object, _db.Object, _publisher.Object);

    private GetMyWorkThreadsQueryHandler Threads() => new(_currentUser.Object, _db.Object);

    // ---- who may read and write ---------------------------------------------------------------

    [Fact]
    public async Task Read_BusinessWithWorkerOnItsTeam_IsAllowed()
    {
        Given(Team(), Message(WorkThreadRole.Worker, "On my way", 5));
        SignedInAs(_businessUserId);

        var result = await Reader().Handle(new GetWorkMessagesQuery(_workerId), default);

        result.Should().ContainSingle().Which.Body.Should().Be("On my way");
    }

    [Fact]
    public async Task Read_WorkerOnTheTeam_IsAllowed()
    {
        Given(Team(), Message(WorkThreadRole.Business, "Bring the ladder", 5));
        SignedInAs(_workerUserId);

        var result = await Reader().Handle(new GetWorkMessagesQuery(_businessId), default);

        result.Should().ContainSingle().Which.Body.Should().Be("Bring the ladder");
    }

    [Fact]
    public async Task Read_Stranger_IsRefused()
    {
        Given(Team());
        SignedInAs(Guid.NewGuid());

        var act = () => Reader().Handle(new GetWorkMessagesQuery(_workerId), default);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Theory]
    [InlineData(BusinessWorkerStatus.Invited)]
    [InlineData(BusinessWorkerStatus.Rejected)]
    [InlineData(BusinessWorkerStatus.Removed)]
    public async Task Send_WorkerNotActiveOnTheTeam_IsRefused(BusinessWorkerStatus status)
    {
        Given(Team(status));
        SignedInAs(_businessUserId);

        var act = () => Sender().Handle(
            new SendWorkMessageCommand { CounterpartId = _workerId, Body = "Hello" },
            default);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Send_BusinessNamingAnotherBusinessesWorker_IsRefused()
    {
        Given(Team());
        SignedInAs(_businessUserId);

        var act = () => Sender().Handle(
            new SendWorkMessageCommand { CounterpartId = Guid.NewGuid(), Body = "Hello" },
            default);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    // ---- sending --------------------------------------------------------------------------------

    [Fact]
    public async Task Send_FromWorker_StoredAsWorkerAndTellsTheBusiness()
    {
        Given(Team());
        SignedInAs(_workerUserId);
        WorkMessage? saved = null;
        var set = TestDbSet.From<WorkMessage>();
        Mock.Get(set).Setup(s => s.Add(It.IsAny<WorkMessage>())).Callback<WorkMessage>(m => saved = m);
        _db.Setup(d => d.WorkMessages).Returns(set);

        var result = await Sender().Handle(
            new SendWorkMessageCommand { CounterpartId = _businessId, Body = "  Reached the gate  " },
            default);

        saved.Should().NotBeNull();
        saved!.SenderRole.Should().Be(WorkThreadRole.Worker);
        saved.BusinessOwnerProfileId.Should().Be(_businessId);
        saved.WorkerProfileId.Should().Be(_workerId);
        saved.Body.Should().Be("Reached the gate");
        result.IsMine.Should().BeTrue();

        // The business is told, and the notification opens the conversation with this worker.
        _publisher.Verify(p => p.Publish(
            It.Is<WorkMessageSentEvent>(e =>
                e.RecipientUserId == _businessUserId
                && e.SenderProfileId == _workerId
                && e.SenderName == "Ravi Kumar"),
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Send_FromBusiness_TellsTheWorkerWithTheBusinessAsTheConversation()
    {
        Given(Team());
        SignedInAs(_businessUserId);
        _db.Setup(d => d.WorkMessages).Returns(TestDbSet.From<WorkMessage>());

        await Sender().Handle(
            new SendWorkMessageCommand { CounterpartId = _workerId, Body = "See you at 10" },
            default);

        _publisher.Verify(p => p.Publish(
            It.Is<WorkMessageSentEvent>(e =>
                e.RecipientUserId == _workerUserId
                && e.SenderProfileId == _businessId
                && e.SenderName == "Demo Painters"),
            It.IsAny<CancellationToken>()), Times.Once);
    }

    // ---- reading --------------------------------------------------------------------------------

    [Fact]
    public async Task Read_MarksTheOtherSidesMessagesRead_ButNeverYourOwn()
    {
        var fromWorker = Message(WorkThreadRole.Worker, "Done for today", 10);
        var fromBusiness = Message(WorkThreadRole.Business, "Thanks", 5);
        Given(Team(), fromWorker, fromBusiness);
        SignedInAs(_businessUserId);

        await Reader().Handle(new GetWorkMessagesQuery(_workerId), default);

        fromWorker.ReadAt.Should().Be(_now);
        fromBusiness.ReadAt.Should().BeNull();
    }

    [Fact]
    public async Task Read_ComesBackOldestFirst_WithEachSideToldWhichAreItsOwn()
    {
        Given(
            Team(),
            Message(WorkThreadRole.Business, "second", 5),
            Message(WorkThreadRole.Worker, "first", 10));
        SignedInAs(_workerUserId);

        var result = await Reader().Handle(new GetWorkMessagesQuery(_businessId), default);

        result.Select(m => m.Body).Should().Equal("first", "second");
        result.Select(m => m.IsMine).Should().Equal(true, false);
    }

    [Fact]
    public async Task Read_NothingNew_DoesNotWrite()
    {
        Given(Team(), Message(WorkThreadRole.Worker, "Hi", 10, readAt: _now.AddMinutes(-1)));
        SignedInAs(_businessUserId);

        await Reader().Handle(new GetWorkMessagesQuery(_workerId), default);

        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    // ---- the conversation list --------------------------------------------------------------------

    [Fact]
    public async Task Threads_Business_SeesTheWorkerAndTheirUnreadMessagesOnly()
    {
        Given(
            Team(),
            Message(WorkThreadRole.Worker, "Is it 2 coats?", 20),
            Message(WorkThreadRole.Worker, "Reached", 10),
            Message(WorkThreadRole.Business, "Yes, 2 coats", 5));
        SignedInAs(_businessUserId);

        var result = await Threads().Handle(new GetMyWorkThreadsQuery(), default);

        var thread = result.Should().ContainSingle().Subject;
        thread.CounterpartId.Should().Be(_workerId);
        thread.CounterpartName.Should().Be("Ravi Kumar");
        thread.LastMessage.Should().Be("Yes, 2 coats");
        thread.LastMessageIsMine.Should().BeTrue();
        thread.UnreadCount.Should().Be(2);
    }

    [Fact]
    public async Task Threads_Worker_SeesTheBusinessByName()
    {
        Given(Team(), Message(WorkThreadRole.Business, "Bring the ladder", 5));
        SignedInAs(_workerUserId);

        var result = await Threads().Handle(new GetMyWorkThreadsQuery(), default);

        var thread = result.Should().ContainSingle().Subject;
        thread.CounterpartId.Should().Be(_businessId);
        thread.CounterpartName.Should().Be("Demo Painters");
        thread.CounterpartImageUrl.Should().Be("/logo.png");
        thread.UnreadCount.Should().Be(1);
    }

    [Fact]
    public async Task Threads_PairWithNoMessages_IsNotAConversation()
    {
        Given(Team());
        SignedInAs(_businessUserId);

        var result = await Threads().Handle(new GetMyWorkThreadsQuery(), default);

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task Threads_WorkerRemovedFromTheTeam_DropsOffTheList()
    {
        Given(Team(BusinessWorkerStatus.Removed), Message(WorkThreadRole.Worker, "Hi", 5));
        SignedInAs(_businessUserId);

        var result = await Threads().Handle(new GetMyWorkThreadsQuery(), default);

        result.Should().BeEmpty();
    }

    // ---- validation -------------------------------------------------------------------------------

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Validator_EmptyBody_IsRefused(string body)
    {
        var result = new SendWorkMessageCommandValidator().Validate(
            new SendWorkMessageCommand { CounterpartId = _workerId, Body = body });

        result.IsValid.Should().BeFalse();
    }

    [Fact]
    public void Validator_BodyOver2000Characters_IsRefused()
    {
        var result = new SendWorkMessageCommandValidator().Validate(
            new SendWorkMessageCommand { CounterpartId = _workerId, Body = new string('a', 2001) });

        result.IsValid.Should().BeFalse();
    }

    [Fact]
    public void Validator_MissingCounterpart_IsRefused()
    {
        var result = new SendWorkMessageCommandValidator().Validate(
            new SendWorkMessageCommand { CounterpartId = Guid.Empty, Body = "Hi" });

        result.IsValid.Should().BeFalse();
    }
}
