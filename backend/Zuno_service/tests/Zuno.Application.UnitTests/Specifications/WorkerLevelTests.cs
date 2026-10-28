using FluentAssertions;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.UnitTests.Specifications;

/// <summary>
/// A worker's standing, now earned from their whole record rather than a job count alone.
/// </summary>
/// <remarks>
/// It used to be jobs and nothing else, so five jobs for one business — with half the offers ignored
/// — read exactly like five jobs for five businesses with every offer answered.
///
/// The two rules that must never regress are at the bottom: a dispute cannot cost a worker standing,
/// and an unpaid wage cannot either. Both would punish the worker for the business's behaviour.
/// </remarks>
public class WorkerLevelTests
{
    private static readonly LevelLadder Ladder = LevelLadder.WorkerDefaults;

    [Fact]
    public void A_worker_with_no_record_is_new()
    {
        WorkerLevel.Calculate(Ladder, 0).Should().Be(1);
        Ladder.Name(1).Should().Be("New");
    }

    [Fact]
    public void Jobs_alone_no_longer_earn_a_level()
    {
        // The whole point of the change. Five finished jobs used to be level 2 outright; without a
        // business having hired them it says nothing about whether somebody else should.
        WorkerLevel.Calculate(Ladder, completedJobCount: 5, businessesWorkedFor: 0).Should().Be(1);
    }

    [Fact]
    public void Jobs_and_a_business_together_do()
    {
        WorkerLevel.Calculate(Ladder, completedJobCount: 5, businessesWorkedFor: 1).Should().Be(2);
    }

    [Fact]
    public void Breadth_is_what_separates_the_upper_levels()
    {
        // Twenty jobs for two businesses is two businesses' opinion, however much work it is.
        WorkerLevel.Calculate(Ladder, completedJobCount: 20, businessesWorkedFor: 2).Should().Be(2);
        WorkerLevel.Calculate(Ladder, completedJobCount: 20, businessesWorkedFor: 3).Should().Be(3);
    }

    [Fact]
    public void The_top_level_asks_for_everything()
    {
        WorkerLevel.Calculate(Ladder, completedJobCount: 100, businessesWorkedFor: 8).Should().Be(5);
        Ladder.Name(5).Should().Be("Highly experienced");
    }

    public class AnsweredOffers
    {
        [Fact]
        public void One_decline_early_on_holds_nobody_back()
        {
            // Four offers is not a pattern, so the rate is not judged at all.
            WorkerLevel
                .Calculate(Ladder, completedJobCount: 5, businessesWorkedFor: 1, offersDeclined: 2)
                .Should().Be(2);
        }

        [Fact]
        public void Turning_down_most_of_them_does()
        {
            // 20 finished, 15 declined — 57% answered, under the 70% level 2 asks for.
            WorkerLevel
                .Calculate(Ladder, completedJobCount: 20, businessesWorkedFor: 3, offersDeclined: 15)
                .Should().Be(1);
        }

        [Fact]
        public void Answering_most_of_them_does_not()
        {
            // 20 finished, 4 declined — 83%, clear of the 80% level 3 asks for.
            WorkerLevel
                .Calculate(Ladder, completedJobCount: 20, businessesWorkedFor: 3, offersDeclined: 4)
                .Should().Be(3);
        }
    }

    public class Ratings
    {
        [Fact]
        public void Pass_while_nobody_can_rate_a_worker()
        {
            // No business can rate a worker yet, so every worker arrives here with no ratings and
            // must not be held at level 1 by a bar that cannot be cleared.
            WorkerLevel
                .Calculate(Ladder, completedJobCount: 100, businessesWorkedFor: 8, ratingAverage: null)
                .Should().Be(5);
        }

        [Fact]
        public void Pass_on_too_few_to_judge()
        {
            WorkerLevel
                .Calculate(Ladder,
                    completedJobCount: 100,
                    businessesWorkedFor: 8,
                    ratingAverage: 1.0m,
                    ratingCount: 2)
                .Should().Be(5);
        }

        [Fact]
        public void Hold_a_level_back_once_there_are_enough()
        {
            WorkerLevel
                .Calculate(Ladder,
                    completedJobCount: 100,
                    businessesWorkedFor: 8,
                    ratingAverage: 4.4m,
                    ratingCount: 10)
                .Should().Be(4);
        }
    }

    public class WhatIsInTheWay
    {
        [Fact]
        public void Names_the_jobs_when_jobs_are_short()
        {
            WorkerLevel.NextLevelRequirement(Ladder, completedJobCount: 3, businessesWorkedFor: 1)
                .Should().Be("2 more jobs");
        }

        [Fact]
        public void Says_one_job_in_the_singular()
        {
            WorkerLevel.NextLevelRequirement(Ladder, completedJobCount: 4, businessesWorkedFor: 1)
                .Should().Be("1 more job");
        }

        [Fact]
        public void Names_the_businesses_when_the_jobs_are_already_there()
        {
            // The case a bare job count could not describe: thirty jobs, one business. The old
            // field would have said "0 jobs to level 3" and left them to guess.
            WorkerLevel.NextLevelRequirement(Ladder, completedJobCount: 30, businessesWorkedFor: 1)
                .Should().Be("work for 2 more businesses");
        }

        [Fact]
        public void Names_the_offers_when_both_counts_are_met()
        {
            WorkerLevel
                .NextLevelRequirement(
                    Ladder, completedJobCount: 20, businessesWorkedFor: 3, offersDeclined: 15)
                .Should().Be("take more of the offers you are sent");
        }

        [Fact]
        public void Says_nothing_at_the_top()
        {
            WorkerLevel.NextLevelRequirement(Ladder, completedJobCount: 100, businessesWorkedFor: 8)
                .Should().BeNull();
        }
    }

    public class WhatMustNeverCountAgainstAWorker
    {
        [Fact]
        public void An_open_dispute_does_not_cap_the_level()
        {
            // The opposite of the business rule, deliberately. A dispute is a worker reporting that
            // money never arrived; marking them down for raising it would teach them to stay quiet.
            // There is no parameter for it at all, which is the strongest form this guarantee takes.
            WorkerLevel.Calculate(Ladder, completedJobCount: 100, businessesWorkedFor: 8).Should().Be(5);
        }

        [Fact]
        public void Nor_does_a_wage_that_never_arrived()
        {
            // Whether a wage is paid is the business's doing. The rule takes no payment figure, so a
            // worker owed money by a late employer keeps every level they have earned.
            WorkerLevel.Calculate(Ladder, completedJobCount: 20, businessesWorkedFor: 3).Should().Be(3);
        }
    }
}
