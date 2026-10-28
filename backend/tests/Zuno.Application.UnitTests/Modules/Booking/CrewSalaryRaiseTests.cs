using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.Commands.RaiseCrewMemberSalary;
using Zuno.Application.Modules.Booking.Commands.RaiseOrderCrewSalary;
using Zuno.Application.Modules.HiringPost.Commands.RaisePostCrewSalary;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.Booking;

/// <summary>
/// A raise is extra pay added to the fixed wage. Five workers fixed at ₹1,000 owe ₹5,000; giving
/// one of them ₹200 more makes ₹5,200, split ₹1,200 to that worker and ₹1,000 to each other.
/// "Raise all" adds the same amount to everyone still to be paid.
/// </summary>
public class CrewSalaryRaiseTests
{
    private const decimal Fixed = 1000m;

    private readonly BusinessOwnerProfile _owner = new()
    {
        Id = Guid.NewGuid(),
        UserId = Guid.NewGuid(),
        BusinessName = "Demo Caterers",
        User = new User { FirstName = "Demo", LastName = "Owner" },
    };

    // ---- The worked example, on the domain ---------------------------------------------------

    [Fact]
    public void RaiseSalary_OneOfFiveRaisedBy200_ThatWorkerGets1200AndTotalIs5200()
    {
        var crew = Enumerable.Range(0, 5).Select(_ => Assignment()).ToList();

        var adjustment = crew[0].RaiseSalary(200m, "3 extra hours");

        crew[0].AgreedSalaryAmount.Should().Be(1200m);
        crew.Skip(1).Should().OnlyContain(a => a.AgreedSalaryAmount == Fixed);
        crew.Sum(a => a.AgreedSalaryAmount!.Value).Should().Be(5200m);
        adjustment.PreviousAmount.Should().Be(Fixed);
        adjustment.NewAmount.Should().Be(1200m);
    }

    [Theory]
    [InlineData(PaymentStatus.Processing)]
    [InlineData(PaymentStatus.Paid)]
    [InlineData(PaymentStatus.AwaitingWorkerConfirmation)]
    public void RaiseSalary_WhenPaymentStarted_IsRefused(PaymentStatus payment)
    {
        var worker = Assignment(payment: payment);

        var act = () => worker.RaiseSalary(200m, null);

        act.Should().Throw<DomainException>();
        worker.AgreedSalaryAmount.Should().Be(Fixed);
    }

    [Fact]
    public void RaiseSalary_WorkerWhoTurnedTheJobDown_IsRefused()
    {
        var worker = Assignment(status: BookingWorkerAssignmentStatus.Rejected);

        var act = () => worker.RaiseSalary(200m, null);

        act.Should().Throw<DomainException>();
    }

    [Fact]
    public void RaiseSalary_WorkerPaidOutsideZuno_IsRefused()
    {
        var worker = Assignment(wage: null);

        var act = () => worker.RaiseSalary(200m, null);

        act.Should().Throw<DomainException>();
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-200)]
    public void RaiseSalary_NothingOrLessAdded_IsRefused(decimal increase)
    {
        var worker = Assignment();

        var act = () => worker.RaiseSalary(increase, null);

        act.Should().Throw<DomainException>();
        worker.AgreedSalaryAmount.Should().Be(Fixed);
    }

    // ---- One worker on an order --------------------------------------------------------------

    [Fact]
    public async Task RaiseCrewMember_ByOwner_RaisesOnlyThatWorker()
    {
        var booking = Order(Assignment(), Assignment());
        var target = booking.WorkerAssignments.First();
        var db = Db();

        await MemberHandler(booking, db).Handle(
            new RaiseCrewMemberSalaryCommand { BookingId = booking.Id, WorkerProfileId = target.WorkerProfileId, Increase = 200m },
            CancellationToken.None);

        target.AgreedSalaryAmount.Should().Be(1200m);
        booking.WorkerAssignments.Last().AgreedSalaryAmount.Should().Be(Fixed);
        db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task RaiseCrewMember_OnAnotherBusinessesOrder_IsRefused()
    {
        var booking = Order(Assignment());
        booking.BusinessOwnerProfileId = Guid.NewGuid();
        var db = Db();

        var act = () => MemberHandler(booking, db).Handle(
            new RaiseCrewMemberSalaryCommand
            {
                BookingId = booking.Id,
                WorkerProfileId = booking.WorkerAssignments.First().WorkerProfileId,
                Increase = 200m,
            },
            CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        booking.WorkerAssignments.First().AgreedSalaryAmount.Should().Be(Fixed);
        db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task RaiseCrewMember_WorkerNotOnTheJob_IsRefused()
    {
        var booking = Order(Assignment());

        var act = () => MemberHandler(booking, Db()).Handle(
            new RaiseCrewMemberSalaryCommand { BookingId = booking.Id, WorkerProfileId = Guid.NewGuid(), Increase = 200m },
            CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>();
    }

    // ---- Raise all on an order ---------------------------------------------------------------

    [Fact]
    public async Task RaiseOrderCrew_FiveAt1000PlusOnePaid_RaisesTheFourUnpaidOnly()
    {
        var paid = Assignment(payment: PaymentStatus.Paid);
        var booking = Order(Assignment(), Assignment(), Assignment(), Assignment(), paid);

        await OrderHandler(booking, Db()).Handle(
            new RaiseOrderCrewSalaryCommand { BookingId = booking.Id, Increase = 200m },
            CancellationToken.None);

        booking.WorkerAssignments.Where(a => a != paid).Should().OnlyContain(a => a.AgreedSalaryAmount == 1200m);
        paid.AgreedSalaryAmount.Should().Be(Fixed);
        booking.WorkerAssignments.Sum(a => a.AgreedSalaryAmount!.Value).Should().Be(5800m);
    }

    [Fact]
    public async Task RaiseOrderCrew_MixedCrew_RaisesDirectWorkersAndPostHiresOnce()
    {
        // A post hire also has an assignment on the order, but without a wage: raised on the post only.
        var hire = PostHire();
        var post = new HiringPost { Id = Guid.NewGuid(), Title = "Wedding", SalaryUnit = SalaryUnit.PerEvent };
        post.Applications.Add(hire);
        var booking = Order(Assignment(), Assignment(wage: null, workerProfileId: hire.WorkerProfileId));
        post.BookingId = booking.Id;

        await OrderHandler(booking, Db(post)).Handle(
            new RaiseOrderCrewSalaryCommand { BookingId = booking.Id, Increase = 200m },
            CancellationToken.None);

        booking.WorkerAssignments.First().AgreedSalaryAmount.Should().Be(1200m);
        booking.WorkerAssignments.Last().AgreedSalaryAmount.Should().BeNull();
        hire.AgreedSalaryAmount.Should().Be(1200m);
    }

    [Fact]
    public async Task RaiseOrderCrew_WhenEveryoneIsPaid_IsRefused()
    {
        var booking = Order(Assignment(payment: PaymentStatus.Paid));
        var db = Db();

        var act = () => OrderHandler(booking, db).Handle(
            new RaiseOrderCrewSalaryCommand { BookingId = booking.Id, Increase = 200m },
            CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>();
        db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    // ---- Raise all on an own event -----------------------------------------------------------

    [Fact]
    public async Task RaisePostCrew_SkipsPaidAndBeingPaidWorkers()
    {
        var unpaid = PostHire();
        var paid = PostHire(PaymentStatus.Paid);
        var beingPaid = PostHire();
        var post = new HiringPost
        {
            Id = Guid.NewGuid(),
            BusinessOwnerProfileId = _owner.Id,
            BusinessOwnerProfile = _owner,
            Title = "Own event",
            SalaryUnit = SalaryUnit.PerEvent,
        };
        post.Applications.Add(unpaid);
        post.Applications.Add(paid);
        post.Applications.Add(beingPaid);

        var run = new PayoutBatch { BatchStatus = PayoutBatchStatus.Disbursing };
        run.Items.Add(new PayoutBatchItem { HiringPostApplicationId = beingPaid.Id });

        await PostHandler(Db(post, run)).Handle(
            new RaisePostCrewSalaryCommand { HiringPostId = post.Id, Increase = 500m },
            CancellationToken.None);

        unpaid.AgreedSalaryAmount.Should().Be(1500m);
        paid.AgreedSalaryAmount.Should().Be(Fixed);
        beingPaid.AgreedSalaryAmount.Should().Be(Fixed);
    }

    [Fact]
    public async Task RaisePostCrew_OnAnotherBusinessesPost_IsRefused()
    {
        var hire = PostHire();
        var post = new HiringPost { Id = Guid.NewGuid(), BusinessOwnerProfileId = Guid.NewGuid(), Title = "Not ours" };
        post.Applications.Add(hire);

        var act = () => PostHandler(Db(post)).Handle(
            new RaisePostCrewSalaryCommand { HiringPostId = post.Id, Increase = 200m },
            CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        hire.AgreedSalaryAmount.Should().Be(Fixed);
    }

    // ---- Builders ----------------------------------------------------------------------------

    private static BookingWorkerAssignment Assignment(
        BookingWorkerAssignmentStatus status = BookingWorkerAssignmentStatus.Accepted,
        PaymentStatus payment = PaymentStatus.Unpaid,
        decimal? wage = Fixed,
        Guid? workerProfileId = null) => new()
        {
            Id = Guid.NewGuid(),
            WorkerProfileId = workerProfileId ?? Guid.NewGuid(),
            WorkerProfile = new WorkerProfile { User = new User { FirstName = "Crew", LastName = "Member" } },
            AssignmentStatus = status,
            AgreedSalaryAmount = wage,
            AgreedSalaryUnit = wage is null ? null : SalaryUnit.PerDay,
            PaymentStatus = payment,
        };

    private static HiringPostApplication PostHire(PaymentStatus payment = PaymentStatus.Unpaid) => new()
    {
        Id = Guid.NewGuid(),
        WorkerProfileId = Guid.NewGuid(),
        WorkerProfile = new WorkerProfile { UserId = Guid.NewGuid(), User = new User { FirstName = "Post", LastName = "Hire" } },
        ApplicationStatus = HiringPostApplicationStatus.Accepted,
        AgreedSalaryAmount = Fixed,
        AgreedSalaryUnit = SalaryUnit.PerEvent,
        PaymentStatus = payment,
    };

    private Domain.Entities.Booking Order(params BookingWorkerAssignment[] crew)
    {
        var booking = new Domain.Entities.Booking
        {
            Id = Guid.NewGuid(),
            BusinessOwnerProfileId = _owner.Id,
            BusinessOwnerProfile = _owner,
            CustomerProfile = new CustomerProfile { User = new User { FirstName = "A", LastName = "Customer" } },
            BusinessService = new BusinessService { Name = "Painting", ServiceCategory = new ServiceCategory { Name = "Home" } },
            Address = new Address(),
            BookingStatus = BookingStatus.Completed,
        };

        foreach (var assignment in crew)
        {
            booking.WorkerAssignments.Add(assignment);
        }

        return booking;
    }

    private static Mock<IApplicationDbContext> Db(HiringPost? post = null, PayoutBatch? run = null)
    {
        var db = new Mock<IApplicationDbContext>();
        db.Setup(d => d.HiringPosts).Returns(post is null ? TestDbSet.From<HiringPost>() : TestDbSet.From(post));
        db.Setup(d => d.HiringPostApplications).Returns(TestDbSet.From(post?.Applications.ToArray() ?? []));
        db.Setup(d => d.PayoutBatches).Returns(run is null ? TestDbSet.From<PayoutBatch>() : TestDbSet.From(run));
        db.Setup(d => d.HiringPostSalaryAdjustments).Returns(TestDbSet.From<HiringPostSalaryAdjustment>());
        db.Setup(d => d.BookingAssignmentSalaryAdjustments).Returns(TestDbSet.From<BookingAssignmentSalaryAdjustment>());
        return db;
    }

    private ICurrentUserService CurrentOwner() => Mock.Of<ICurrentUserService>(u => u.UserId == _owner.UserId);

    private IBusinessOwnerProfileRepository Businesses()
    {
        var businesses = new Mock<IBusinessOwnerProfileRepository>();
        businesses.Setup(r => r.GetByUserIdAsync(_owner.UserId, It.IsAny<CancellationToken>())).ReturnsAsync(_owner);
        return businesses.Object;
    }

    private static IBookingRepository Bookings(Domain.Entities.Booking booking)
    {
        var bookings = new Mock<IBookingRepository>();
        bookings.Setup(r => r.GetByIdAsync(booking.Id, It.IsAny<CancellationToken>())).ReturnsAsync(booking);
        return bookings.Object;
    }

    private RaiseCrewMemberSalaryCommandHandler MemberHandler(Domain.Entities.Booking booking, Mock<IApplicationDbContext> db) =>
        new(CurrentOwner(), Businesses(), Bookings(booking), db.Object);

    private RaiseOrderCrewSalaryCommandHandler OrderHandler(Domain.Entities.Booking booking, Mock<IApplicationDbContext> db) =>
        new(CurrentOwner(), Businesses(), Bookings(booking), db.Object, Mock.Of<MediatR.IPublisher>());

    private RaisePostCrewSalaryCommandHandler PostHandler(Mock<IApplicationDbContext> db) =>
        new(CurrentOwner(), Businesses(), db.Object, Mock.Of<MediatR.IPublisher>());
}
