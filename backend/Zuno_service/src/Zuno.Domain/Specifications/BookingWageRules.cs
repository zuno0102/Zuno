using System.Linq.Expressions;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Specifications;

/// <summary>
/// When a finished job may be counted toward a business's record.
/// </summary>
public static class BookingWageRules
{
    /// <summary>
    /// An order counts when it is finished and owes nobody.
    /// </summary>
    /// <remarks>
    /// Half of a pair. A hiring post counts on its own <em>only when it has no order</em>
    /// (<c>BookingId == null</c>); one raised against an order is credited through that order.
    /// The two halves partition the posts between them, so no job can be counted twice — without
    /// that split a wedding would credit the business once as the order and again as the crew
    /// hired for it.
    /// <para>
    /// Written as "no accepted worker is still unpaid" rather than "every linked post is settled".
    /// A post nobody accepted is never settled by its own definition, so the second form would
    /// leave an order carrying one paid post and one empty post uncounted for ever.
    /// </para>
    /// <para>
    /// Being owed nothing at all satisfies this: a worker with no wage recorded is paid outside
    /// the app — a regular on a monthly wage — and a job done well should not go uncredited for
    /// the absence of a transaction that was never going to happen.
    /// </para>
    /// <para>
    /// <b>Both</b> ways onto a job are checked. A crew can arrive through a hiring post or be put
    /// on the order directly, and for a long time only the first carried a wage — so an order
    /// staffed entirely by hand had no posts, owed nobody by this rule, and counted as settled the
    /// moment the work finished while that crew had been paid nothing. An unpaid worker is an
    /// unpaid worker however they got there.
    /// </para>
    /// </remarks>
    public static Expression<Func<Booking, bool>> CountsAsCompleted => booking =>
        booking.BookingStatus == BookingStatus.Completed
        && !booking.HiringPosts.Any(post => post.Applications.Any(application =>
            application.ApplicationStatus == HiringPostApplicationStatus.Accepted
            && application.PaymentStatus != PaymentStatus.Paid))
        && !booking.WorkerAssignments.Any(assignment =>
            assignment.AgreedSalaryAmount != null
            && assignment.AssignmentStatus != BookingWorkerAssignmentStatus.Rejected
            && assignment.PaymentStatus != PaymentStatus.Paid);
}
