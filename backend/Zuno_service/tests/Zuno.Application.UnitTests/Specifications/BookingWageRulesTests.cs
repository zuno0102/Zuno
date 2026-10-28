using FluentAssertions;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Specifications;
using Zuno.Domain.ValueObjects;
using Xunit;

// Deliberately not ...UnitTests.Domain: that segment shadows Zuno.Domain for every other test
// file in the assembly, and "Domain.Entities.Booking" silently stops resolving.
namespace Zuno.Application.UnitTests.Specifications;

/// <summary>
/// When a finished order counts toward a business's record, and the two spellings of that rule.
/// </summary>
/// <remarks>
/// The rule exists twice on purpose: <see cref="BookingWageRules.CountsAsCompleted"/> runs in SQL
/// for the count, and <see cref="BookingWageRollup.IsWageClear"/> runs in memory for the badge.
/// Two spellings of one rule is the standing hazard here, so the last test runs both over the same
/// orders and refuses to let them disagree.
/// </remarks>
public class BookingWageRulesTests
{
    private static readonly Func<Domain.Entities.Booking, bool> Counts =
        BookingWageRules.CountsAsCompleted.Compile();

    private static HiringPostApplication Payee(PaymentStatus payment, decimal amount = 700m) => new()
    {
        ApplicationStatus = HiringPostApplicationStatus.Accepted,
        PaymentStatus = payment,
        AgreedSalaryAmount = amount,
    };

    private static HiringPost Post(params HiringPostApplication[] applications) => new()
    {
        Title = "Crew",
        Applications = applications.ToList(),
    };

    private static Domain.Entities.Booking Order(
        BookingStatus status,
        params HiringPost[] posts) => new()
    {
        BookingStatus = status,
        HiringPosts = posts.ToList(),
    };

    /// <summary>A worker the business put on the job itself, rather than hiring through a post.</summary>
    /// <param name="salary">Null for someone paid outside Zuno — a regular on a monthly wage.</param>
    private static BookingWorkerAssignment Hand(
        PaymentStatus payment = PaymentStatus.Unpaid,
        decimal? salary = 800m,
        BookingWorkerAssignmentStatus status = BookingWorkerAssignmentStatus.Accepted) => new()
    {
        AssignmentStatus = status,
        AgreedSalaryAmount = salary,
        AgreedSalaryUnit = salary.HasValue ? SalaryUnit.PerEvent : null,
        PaymentStatus = payment,
    };

    private static Domain.Entities.Booking OrderWithCrew(
        BookingStatus status,
        BookingWorkerAssignment[] crew,
        params HiringPost[] posts) => new()
    {
        BookingStatus = status,
        HiringPosts = posts.ToList(),
        WorkerAssignments = crew.ToList(),
    };

    private static BookingWageRollup RollupOf(Domain.Entities.Booking order)
    {
        var payees = order.HiringPosts
            .SelectMany(p => p.Applications)
            .Where(a => a.ApplicationStatus == HiringPostApplicationStatus.Accepted)
            .ToList();

        return new BookingWageRollup(
            payees.Count,
            payees.Count(a => a.PaymentStatus == PaymentStatus.Paid),
            payees.Count(a => a.PaymentStatus == PaymentStatus.Disputed),
            payees.Sum(a => a.AgreedSalaryAmount ?? 0m),
            payees.Where(a => a.PaymentStatus != PaymentStatus.Paid).Sum(a => a.AgreedSalaryAmount ?? 0m));
    }

    [Fact]
    public void An_order_staffed_from_the_roster_counts()
    {
        // Nobody was hired through the app, so nobody is owed through it. Paying your own people
        // offline should not cost you the credit for a job you did.
        var order = Order(BookingStatus.Completed);

        Counts(order).Should().BeTrue();
        RollupOf(order).Status.Should().Be(BookingWageStatus.NoWagesThroughZuno);
        RollupOf(order).IsWageClear.Should().BeTrue();
    }

    [Fact]
    public void An_order_whose_crew_is_paid_counts()
    {
        var order = Order(
            BookingStatus.Completed,
            Post(Payee(PaymentStatus.Paid), Payee(PaymentStatus.Paid)));

        Counts(order).Should().BeTrue();
        RollupOf(order).Status.Should().Be(BookingWageStatus.Settled);
    }

    [Fact]
    public void An_order_still_owing_a_wage_does_not_count()
    {
        var order = Order(
            BookingStatus.Completed,
            Post(Payee(PaymentStatus.Paid), Payee(PaymentStatus.Unpaid)));

        Counts(order).Should().BeFalse();
        RollupOf(order).Status.Should().Be(BookingWageStatus.Outstanding);
        RollupOf(order).OutstandingAmount.Should().Be(700m);
    }

    [Fact]
    public void Unfinished_work_does_not_count_however_well_paid()
    {
        var order = Order(BookingStatus.InProgress, Post(Payee(PaymentStatus.Paid)));

        Counts(order).Should().BeFalse();
    }

    [Fact]
    public void A_disputed_wage_reads_as_disputed_rather_than_merely_outstanding()
    {
        var order = Order(
            BookingStatus.Completed,
            Post(Payee(PaymentStatus.Paid), Payee(PaymentStatus.Disputed)));

        RollupOf(order).Status.Should().Be(BookingWageStatus.Disputed);
        Counts(order).Should().BeFalse();
    }

    [Fact]
    public void A_post_nobody_accepted_does_not_hold_an_order_open()
    {
        // The case a per-post implementation gets wrong. HiringPost.IsFullySettled is deliberately
        // false when nobody was hired, so ANDing it across the posts would leave this order
        // uncounted for ever — waiting on a payment to somebody who does not exist.
        var order = Order(
            BookingStatus.Completed,
            Post(Payee(PaymentStatus.Paid), Payee(PaymentStatus.Paid)),
            Post());

        Counts(order).Should().BeTrue();
        RollupOf(order).Status.Should().Be(BookingWageStatus.Settled);
    }

    [Fact]
    public void A_worker_who_turned_the_job_down_is_owed_nothing()
    {
        var declined = new HiringPostApplication
        {
            ApplicationStatus = HiringPostApplicationStatus.Declined,
            PaymentStatus = PaymentStatus.Unpaid,
            AgreedSalaryAmount = 700m,
        };

        var order = Order(BookingStatus.Completed, Post(Payee(PaymentStatus.Paid), declined));

        Counts(order).Should().BeTrue();
        RollupOf(order).PayeeCount.Should().Be(1);
    }

    [Fact]
    public void The_badge_and_the_count_never_disagree()
    {
        // One rule, written twice — in SQL for the count and in memory for the badge. For a
        // finished order the two must give the same answer on every shape above.
        Domain.Entities.Booking[] finished =
        [
            Order(BookingStatus.Completed),
            Order(BookingStatus.Completed, Post(Payee(PaymentStatus.Paid))),
            Order(BookingStatus.Completed, Post(Payee(PaymentStatus.Unpaid))),
            Order(BookingStatus.Completed, Post(Payee(PaymentStatus.Disputed))),
            Order(BookingStatus.Completed, Post(Payee(PaymentStatus.Processing))),
            Order(BookingStatus.Completed, Post(Payee(PaymentStatus.Failed))),
            Order(BookingStatus.Completed, Post(Payee(PaymentStatus.Paid)), Post()),
            Order(BookingStatus.Completed, Post(Payee(PaymentStatus.Paid)), Post(Payee(PaymentStatus.Unpaid))),
        ];

        foreach (var order in finished)
        {
            RollupOf(order).IsWageClear.Should().Be(
                Counts(order),
                "the badge and the completed count read the same order");
        }
    }

    // ---- Crew the business put on the job itself ---------------------------------------------
    //
    // For a long time only hiring posts carried a wage, so an order staffed entirely by hand had
    // no posts, owed nobody by this rule, and counted as settled the moment the work finished —
    // while that crew had been paid nothing. These are the tests that stop that coming back.

    [Fact]
    public void An_unpaid_worker_added_by_hand_stops_the_order_counting()
    {
        var order = OrderWithCrew(BookingStatus.Completed, [Hand(PaymentStatus.Unpaid)]);

        Counts(order).Should().BeFalse(
            "a worker owed ₹800 is owed it however they got onto the job");
    }

    [Fact]
    public void Paying_that_worker_lets_it_count()
    {
        var order = OrderWithCrew(BookingStatus.Completed, [Hand(PaymentStatus.Paid)]);

        Counts(order).Should().BeTrue();
    }

    [Fact]
    public void A_worker_with_no_wage_recorded_never_blocks_it()
    {
        // The whole point of the salary being optional: a regular on a monthly wage is not owed
        // anything per job, and must not hold the order open for a payment nobody will ever make.
        var order = OrderWithCrew(BookingStatus.Completed, [Hand(salary: null)]);

        Counts(order).Should().BeTrue();
    }

    [Fact]
    public void A_worker_who_refused_the_job_does_not_block_it()
    {
        // They were offered a wage and turned the work down. Nothing is owed to someone who did
        // not do it, and leaving them in would hold the order open for ever.
        var order = OrderWithCrew(
            BookingStatus.Completed,
            [Hand(status: BookingWorkerAssignmentStatus.Rejected)]);

        Counts(order).Should().BeTrue();
    }

    [Fact]
    public void Both_ways_onto_a_job_are_checked_together()
    {
        // The case that reads as settled if only one source is looked at: the hired crew is paid
        // in full, and the business's own worker has had nothing.
        var order = OrderWithCrew(
            BookingStatus.Completed,
            [Hand(PaymentStatus.Unpaid)],
            Post(Payee(PaymentStatus.Paid)));

        Counts(order).Should().BeFalse();
    }

    [Fact]
    public void An_order_still_running_never_counts_however_well_paid()
    {
        var order = OrderWithCrew(BookingStatus.Confirmed, [Hand(PaymentStatus.Paid)]);

        Counts(order).Should().BeFalse("nothing counts before the work is finished");
    }
}
