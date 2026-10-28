using Zuno.Domain.Enums;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Modules.Booking.Common;

/// <summary>
/// Who may say that an order's work has started, and that it has finished.
/// </summary>
/// <remarks>
/// <para>
/// Two people: the business owner, and whoever the owner put in charge of that one job. The second
/// is the point. An owner running three jobs on a Saturday cannot be at all of them, and the person
/// who actually knows the work began is the one standing on the site — so the owner names a lead
/// when assigning the crew, and that lead can move the work on that job and no other.
/// </para>
/// <para>
/// <b>Deliberately per job, not per person.</b> A title held across the whole business would make
/// the same worker the lead on every job at once, including ones they have never been near. Being
/// the lead is a fact about an assignment, which is where <see cref="Zuno.Domain.Entities.BookingWorkerAssignment.Role"/>
/// lives.
/// </para>
/// <para>
/// This covers only starting and finishing work. Prices, wages, payouts, confirming an order and
/// choosing the crew stay with the owner — a lead runs the day, not the business.
/// </para>
/// </remarks>
public static class BookingWorkControl
{
    /// <summary>
    /// Whether an order is at a point where its crew can be given roles.
    /// </summary>
    /// <remarks>
    /// <para>
    /// From the moment the business confirms the order until the work is finished — and no wider.
    /// A role exists so somebody can run the job: before it is confirmed there is no job, and once
    /// it is done there is nothing left to run, since the work cannot be started or completed a
    /// second time. A role given outside that window would be a title attached to history.
    /// </para>
    /// <para>
    /// An inclusion list rather than "not completed and not cancelled": a status added later is
    /// left out until somebody decides it belongs, which is the safe direction for a rule that
    /// hands out the power to close a job.
    /// </para>
    /// </remarks>
    public static bool CanHoldRoles(BookingStatus status) =>
        status is BookingStatus.Confirmed
            or BookingStatus.Assigned
            or BookingStatus.InProgress;

    /// <summary>
    /// Whether this user is the Lead on this booking.
    /// </summary>
    /// <remarks>
    /// Two conditions, and both matter.
    ///
    /// The role must be <see cref="JobRole.Lead"/> — not merely "some role". Supervisor watches the
    /// work and Support fixes what the work needs; neither declares that it started. A job has one
    /// person answerable for that, and three roles that could all do it would mean nobody in
    /// particular did.
    ///
    /// And the assignment must be accepted, not merely offered. Somebody who has not answered might
    /// still decline, and a lead who is not coming must not be able to say the work has begun.
    /// </remarks>
    public static bool IsLead(Domain.Entities.Booking booking, Guid userId) =>
        booking.WorkerAssignments.Any(a =>
            a.WorkerProfile.UserId == userId
            && JobRole.GrantsWorkControl(a.Role)
            && a.AssignmentStatus is BookingWorkerAssignmentStatus.Accepted
                or BookingWorkerAssignmentStatus.Completed);

    /// <summary>
    /// Whether this user may start or finish the work on this booking.
    /// </summary>
    /// <param name="businessOwnerProfileId">
    /// The signed-in user's own business, or null when they have none — most leads are workers and
    /// nothing else.
    /// </param>
    public static bool MayMoveWork(
        Domain.Entities.Booking booking,
        Guid userId,
        Guid? businessOwnerProfileId) =>
        (businessOwnerProfileId is { } ownerId && booking.BusinessOwnerProfileId == ownerId)
        || IsLead(booking, userId);

    /// <summary>
    /// How this person is named to the customer and in the record — "Boss T" or "Ravi Kumar".
    /// </summary>
    /// <remarks>
    /// A notification saying the business started the job when a lead did it would be a small lie
    /// in the one message the customer reads about it.
    /// </remarks>
    public static string ActorName(Domain.Entities.Booking booking, Guid userId)
    {
        var lead = booking.WorkerAssignments
            .FirstOrDefault(a => a.WorkerProfile.UserId == userId
                && JobRole.GrantsWorkControl(a.Role));

        if (lead is null)
        {
            return booking.BusinessOwnerProfile.BusinessName;
        }

        var user = lead.WorkerProfile.User;
        var name = $"{user.FirstName} {user.LastName}".Trim();

        return string.IsNullOrEmpty(name) ? booking.BusinessOwnerProfile.BusinessName : name;
    }
}
