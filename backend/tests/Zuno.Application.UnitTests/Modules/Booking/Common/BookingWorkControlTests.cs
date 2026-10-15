using FluentAssertions;
using Zuno.Application.Modules.Booking.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.UnitTests.Modules.Booking.Common;

/// <summary>
/// Who may say an order's work has started and finished.
/// </summary>
/// <remarks>
/// This is an access rule, and the only one in the app that lets somebody who is not the owner move
/// an order along — so it is worth pinning down from both directions: that a lead can, and that
/// every other kind of person on the same booking cannot.
///
/// The rule is per job on purpose. A title held across the whole business would make the same
/// worker the lead on every job at once, including ones they have never been near.
/// </remarks>
public class BookingWorkControlTests
{
    private readonly Guid _ownerProfileId = Guid.NewGuid();
    private readonly Guid _ownerUserId = Guid.NewGuid();
    private readonly Guid _leadUserId = Guid.NewGuid();
    private readonly Guid _plainWorkerUserId = Guid.NewGuid();

    private BookingWorkerAssignment Crew(
        Guid userId,
        string? role,
        BookingWorkerAssignmentStatus status = BookingWorkerAssignmentStatus.Accepted,
        string firstName = "Ravi",
        string lastName = "Kumar") => new()
        {
            Id = Guid.NewGuid(),
            WorkerProfileId = Guid.NewGuid(),
            Role = role,
            AssignmentStatus = status,
            WorkerProfile = new WorkerProfile
            {
                UserId = userId,
                User = new User { FirstName = firstName, LastName = lastName },
            },
        };

    private Domain.Entities.Booking Booking(params BookingWorkerAssignment[] crew)
    {
        var booking = new Domain.Entities.Booking
        {
            Id = Guid.NewGuid(),
            BusinessOwnerProfileId = _ownerProfileId,
            BusinessOwnerProfile = new BusinessOwnerProfile
            {
                Id = _ownerProfileId,
                UserId = _ownerUserId,
                BusinessName = "Boss T",
            },
        };

        foreach (var member in crew)
        {
            booking.WorkerAssignments.Add(member);
        }

        return booking;
    }

    // ---- the owner ---------------------------------------------------------------------------

    [Fact]
    public void The_owner_may_always_move_their_own_order()
    {
        var booking = Booking(Crew(_plainWorkerUserId, role: null));

        BookingWorkControl.MayMoveWork(booking, _ownerUserId, _ownerProfileId).Should().BeTrue();
    }

    /// <remarks>
    /// A business owner is not thereby an owner of everybody's orders. Checked because the actor
    /// now arrives carrying their own business id, which is exactly the shape that invites a
    /// comparison against the wrong thing.
    /// </remarks>
    [Fact]
    public void Another_business_owner_may_not_move_somebody_elses_order()
    {
        var booking = Booking(Crew(_plainWorkerUserId, role: null));

        BookingWorkControl
            .MayMoveWork(booking, Guid.NewGuid(), businessOwnerProfileId: Guid.NewGuid())
            .Should().BeFalse();
    }

    // ---- the lead ----------------------------------------------------------------------------

    [Fact]
    public void A_worker_given_a_role_on_this_job_may_move_it()
    {
        var booking = Booking(
            Crew(_leadUserId, role: JobRole.Lead),
            Crew(_plainWorkerUserId, role: null));

        BookingWorkControl
            .MayMoveWork(booking, _leadUserId, businessOwnerProfileId: null)
            .Should().BeTrue();
    }

    [Fact]
    public void A_worker_on_the_job_without_a_role_may_not()
    {
        var booking = Booking(
            Crew(_leadUserId, role: JobRole.Lead),
            Crew(_plainWorkerUserId, role: null));

        BookingWorkControl
            .MayMoveWork(booking, _plainWorkerUserId, businessOwnerProfileId: null)
            .Should().BeFalse();
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void A_blank_role_is_no_role(string role)
    {
        var booking = Booking(Crew(_leadUserId, role));

        BookingWorkControl
            .MayMoveWork(booking, _leadUserId, businessOwnerProfileId: null)
            .Should().BeFalse();
    }

    /// <remarks>
    /// The rule that distinguishes the three. A job has one person answerable for whether the work
    /// has begun; if Supervisor and Support could declare it too, nobody in particular could.
    /// </remarks>
    [Theory]
    [InlineData(JobRole.Supervisor)]
    [InlineData(JobRole.Support)]
    public void Only_the_lead_moves_the_work_not_the_other_two(string role)
    {
        var booking = Booking(Crew(_leadUserId, role));

        BookingWorkControl
            .MayMoveWork(booking, _leadUserId, businessOwnerProfileId: null)
            .Should().BeFalse(because: $"{role} watches or helps; it does not close the job");
    }

    /// <remarks>
    /// Free text predates the three fixed roles and is still on old assignments. None of it is
    /// Lead, so none of it grants anything — which is right: nobody who typed "Painter" meant
    /// "may close this job".
    /// </remarks>
    [Theory]
    [InlineData("Painter")]
    [InlineData("Chef")]
    [InlineData("Driver")]
    public void A_legacy_free_text_role_grants_nothing(string role)
    {
        var booking = Booking(Crew(_leadUserId, role));

        BookingWorkControl
            .MayMoveWork(booking, _leadUserId, businessOwnerProfileId: null)
            .Should().BeFalse();
    }

    [Theory]
    [InlineData("lead")]
    [InlineData("LEAD")]
    [InlineData("  Lead  ")]
    public void The_lead_role_is_recognised_however_it_was_written(string role)
    {
        var booking = Booking(Crew(_leadUserId, role));

        BookingWorkControl
            .MayMoveWork(booking, _leadUserId, businessOwnerProfileId: null)
            .Should().BeTrue();
    }

    /// <remarks>
    /// A role exists so somebody can run the job. Before the business confirms the order there is
    /// no job — the customer may never get one. Once the work is finished or the order is called
    /// off there is nothing left to run, because the work cannot be started or completed twice, so
    /// a role given then would be a title attached to history.
    /// </remarks>
    [Theory]
    [InlineData(BookingStatus.Confirmed)]
    [InlineData(BookingStatus.Assigned)]
    [InlineData(BookingStatus.InProgress)]
    public void A_live_order_can_hold_roles(BookingStatus status) =>
        BookingWorkControl.CanHoldRoles(status).Should().BeTrue();

    [Theory]
    [InlineData(BookingStatus.Pending)]
    [InlineData(BookingStatus.Completed)]
    [InlineData(BookingStatus.Cancelled)]
    public void An_order_outside_that_window_cannot(BookingStatus status) =>
        BookingWorkControl.CanHoldRoles(status).Should().BeFalse();

    [Fact]
    public void The_three_roles_are_the_only_ones_offered()
    {
        JobRole.All.Should().Equal([JobRole.Supervisor, JobRole.Lead, JobRole.Support]);

        JobRole.IsKnown("Painter").Should().BeFalse();
        JobRole.IsKnown("supervisor").Should().BeTrue();
        JobRole.Canonical("  lEaD ").Should().Be(JobRole.Lead);
        JobRole.Canonical("").Should().BeNull();
    }

    /// <remarks>
    /// The reason accepting matters: somebody who has been offered the job and not answered might
    /// still decline it, and a lead who is not coming must not be able to declare the work started.
    /// </remarks>
    [Theory]
    [InlineData(BookingWorkerAssignmentStatus.Assigned)]
    [InlineData(BookingWorkerAssignmentStatus.Rejected)]
    public void A_lead_who_has_not_accepted_the_job_may_not_move_it(
        BookingWorkerAssignmentStatus status)
    {
        var booking = Booking(Crew(_leadUserId, JobRole.Lead, status));

        BookingWorkControl
            .MayMoveWork(booking, _leadUserId, businessOwnerProfileId: null)
            .Should().BeFalse();
    }

    [Fact]
    public void A_lead_who_has_finished_their_own_part_can_still_close_the_job()
    {
        // Otherwise a lead who ticked off their own work could no longer say the job was done,
        // which is the moment they are most likely to be doing it.
        var booking = Booking(
            Crew(_leadUserId, JobRole.Lead, BookingWorkerAssignmentStatus.Completed));

        BookingWorkControl
            .MayMoveWork(booking, _leadUserId, businessOwnerProfileId: null)
            .Should().BeTrue();
    }

    [Fact]
    public void A_stranger_may_not_move_an_order_they_are_not_on()
    {
        var booking = Booking(Crew(_leadUserId, JobRole.Lead));

        BookingWorkControl
            .MayMoveWork(booking, Guid.NewGuid(), businessOwnerProfileId: null)
            .Should().BeFalse();
    }

    /// <remarks>
    /// Being the lead on Saturday's job says nothing about Sunday's. This is the whole reason the
    /// role lives on the assignment rather than on the person.
    /// </remarks>
    [Fact]
    public void A_lead_on_one_job_is_not_a_lead_on_another()
    {
        var saturday = Booking(Crew(_leadUserId, JobRole.Lead));
        var sunday = Booking(Crew(_leadUserId, role: null));

        BookingWorkControl.MayMoveWork(saturday, _leadUserId, null).Should().BeTrue();
        BookingWorkControl.MayMoveWork(sunday, _leadUserId, null).Should().BeFalse();
    }

    /// <remarks>
    /// The pairing that matters: a role may only be SET on an accepted assignment (enforced by
    /// SetAssignmentRoleCommandHandler), and only an accepted assignment GRANTS anything. If those
    /// two ever drift apart, a role sits on the owner's screen doing nothing — which looks like the
    /// feature is broken rather than like a rule being applied.
    /// </remarks>
    [Fact]
    public void The_statuses_that_can_hold_a_role_are_the_statuses_that_grant_one()
    {
        // Accepted and Completed grant it.
        foreach (var status in new[]
        {
            BookingWorkerAssignmentStatus.Accepted,
            BookingWorkerAssignmentStatus.Completed,
        })
        {
            BookingWorkControl
                .MayMoveWork(Booking(Crew(_leadUserId, JobRole.Lead, status)), _leadUserId, null)
                .Should().BeTrue(because: $"{status} should grant it");
        }

        // Nothing else does.
        foreach (var status in new[]
        {
            BookingWorkerAssignmentStatus.Assigned,
            BookingWorkerAssignmentStatus.Rejected,
        })
        {
            BookingWorkControl
                .MayMoveWork(Booking(Crew(_leadUserId, JobRole.Lead, status)), _leadUserId, null)
                .Should().BeFalse(because: $"{status} should not grant it");
        }
    }

    // ---- who gets named ----------------------------------------------------------------------

    [Fact]
    public void The_lead_is_named_as_themselves_when_they_move_the_work()
    {
        var booking = Booking(Crew(_leadUserId, JobRole.Lead, firstName: "Ravi", lastName: "Kumar"));

        BookingWorkControl.ActorName(booking, _leadUserId).Should().Be("Ravi Kumar");
    }

    [Fact]
    public void The_owner_is_named_as_the_business()
    {
        var booking = Booking(Crew(_leadUserId, JobRole.Lead));

        BookingWorkControl.ActorName(booking, _ownerUserId).Should().Be("Boss T");
    }

    [Fact]
    public void A_lead_with_no_name_on_file_falls_back_to_the_business()
    {
        var booking = Booking(Crew(_leadUserId, JobRole.Lead, firstName: "", lastName: ""));

        BookingWorkControl.ActorName(booking, _leadUserId).Should().Be("Boss T");
    }
}
