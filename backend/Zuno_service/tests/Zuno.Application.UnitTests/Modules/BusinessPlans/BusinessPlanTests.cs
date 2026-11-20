using FluentAssertions;
using FluentValidation.TestHelper;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.BusinessPlans;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.BusinessPlans;

/// <summary>
/// The plan over all three areas: Basic allows 1 live listing in total; a paid plan opens its areas;
/// buying, renewing and switching; a plan's end pausing what it alone allowed and a renewal bringing
/// it back; and the Super Admin's prices.
/// </summary>
public class BusinessPlanTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 21, 9, 0, 0, TimeSpan.Zero);
    private static readonly Guid Owner = Guid.NewGuid();

    private readonly List<SubscriptionPlan> _plans =
    [
        new() { Code = "basic", Name = "Basic", IncludesService = true, IncludesRent = true, IncludesMarketplace = true, MaxLiveListings = 1, Price = 0m, Period = PlanPeriod.Free, IsDefault = true, SortOrder = 1 },
        new() { Code = "service-monthly", Name = "Service", IncludesService = true, Price = 199m, DurationDays = 30, Period = PlanPeriod.Monthly, SortOrder = 2 },
        new() { Code = "all3-monthly", Name = "All 3", IncludesService = true, IncludesRent = true, IncludesMarketplace = true, Price = 699m, DurationDays = 30, Period = PlanPeriod.Monthly, SortOrder = 3 },
        new() { Code = "retired", Name = "Retired", IncludesRent = true, Price = 99m, DurationDays = 30, Period = PlanPeriod.Monthly, IsActive = false, SortOrder = 4 },
    ];

    private readonly List<BusinessSubscription> _subscriptions = [];
    private readonly List<PlanPausedListing> _paused = [];
    private readonly List<BusinessService> _services = [];
    private readonly List<VacancyFeePlan> _hiringPlans = [new() { Name = "1 month", Amount = 99m, ListingDays = 30, SortOrder = 1 }];
    private readonly FakeAreas _areas = new();
    private readonly Mock<IApplicationDbContext> _db = new();
    private readonly Mock<IPayoutProvider> _payments = new();
    private readonly RazorpaySettings _razorpay = new() { KeyId = "rzp_test_key" };
    private DateTimeOffset _now = Now;

    public BusinessPlanTests()
    {
        _db.Setup(d => d.SubscriptionPlans).Returns(() => TestDbSet.Over(_plans));
        _db.Setup(d => d.BusinessSubscriptions).Returns(() => TestDbSet.Over(_subscriptions));
        _db.Setup(d => d.PlanPausedListings).Returns(() => TestDbSet.Over(_paused));
        _db.Setup(d => d.BusinessServices).Returns(() => TestDbSet.Over(_services));
        _db.Setup(d => d.VacancyFeePlans).Returns(() => TestDbSet.Over(_hiringPlans));
        _db.Setup(d => d.SaveChangesAsync(It.IsAny<CancellationToken>())).ReturnsAsync(1);
        _payments.Setup(p => p.CreateCollectionOrderAsync(It.IsAny<decimal>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new PayoutCollectionOrder("order_1", 69900));
        _payments.Setup(p => p.VerifyPaymentSignature("order_1", "pay_1", "good")).Returns(true);
    }

    private SubscriptionPlan Plan(string code) => _plans.Single(p => p.Code == code);

    private BusinessPlanRules Rules => new(_db.Object, _areas);

    private PlanReconciler Reconciler => new(_db.Object, Rules, _areas, NullLogger<PlanReconciler>.Instance);

    private BusinessPlanHandlers Handlers()
    {
        var user = new Mock<ICurrentUserService>();
        user.Setup(u => u.UserId).Returns(Owner);
        var clock = new Mock<IDateTimeProvider>();
        clock.Setup(c => c.UtcNow).Returns(() => _now);
        return new BusinessPlanHandlers(user.Object, _db.Object, clock.Object, _payments.Object, Options.Create(_razorpay), Rules, Reconciler);
    }

    private BusinessService LiveService(string name, int minutesAgo = 60)
    {
        var service = new BusinessService
        {
            Name = name,
            IsActive = true,
            CreatedDate = Now.AddMinutes(-minutesAgo),
            BusinessOwnerProfile = new BusinessOwnerProfile { UserId = Owner },
        };
        _services.Add(service);
        return service;
    }

    private BusinessSubscription Running(string code, int daysLeft = 10)
    {
        var subscription = BusinessSubscription.Start(Owner, Plan(code));
        subscription.Activate("pay_old", Now.AddDays(-20), Now.AddDays(daysLeft - subscription.DurationDays));
        _subscriptions.Add(subscription);
        return subscription;
    }

    private Task<ListingAllowance> CheckAsync(ListingArea area, int? liveHere = null) =>
        Rules.CheckAsync(Owner, area, liveHere, _now, CancellationToken.None);

    // ---- The rule ----

    [Fact]
    public async Task A_new_business_on_Basic_may_put_up_one_listing_in_any_area()
    {
        (await CheckAsync(ListingArea.Service)).Allowed.Should().BeTrue();
        (await CheckAsync(ListingArea.Rent, liveHere: 0)).Allowed.Should().BeTrue();
        (await CheckAsync(ListingArea.Marketplace, liveHere: 0)).Allowed.Should().BeTrue();
    }

    [Fact]
    public async Task On_Basic_one_live_listing_anywhere_locks_every_area()
    {
        _areas.Live[ListingArea.Marketplace] = [new AreaListing(Guid.NewGuid(), Now)];

        var service = await CheckAsync(ListingArea.Service);
        service.Allowed.Should().BeFalse();
        service.Reason.Should().StartWith("The Basic plan allows 1 live listing in total.");
        (await CheckAsync(ListingArea.Marketplace, liveHere: 1)).Allowed.Should().BeFalse("a second Marketplace post is locked too");
    }

    [Fact]
    public async Task Taking_the_one_listing_down_frees_Basic_again()
    {
        var service = LiveService("AC service");
        (await CheckAsync(ListingArea.Rent, liveHere: 0)).Allowed.Should().BeFalse();

        service.IsActive = false;

        (await CheckAsync(ListingArea.Rent, liveHere: 0)).Allowed.Should().BeTrue();
    }

    [Fact]
    public async Task A_paid_plan_opens_its_areas_without_limit_and_leaves_the_others_locked()
    {
        Running("service-monthly");
        LiveService("AC service");
        LiveService("Plumbing");

        (await CheckAsync(ListingArea.Service)).Allowed.Should().BeTrue();
        _areas.Asked.Should().BeEmpty("a paid plan covering the area never needs the other APIs");
        var rent = await CheckAsync(ListingArea.Rent, liveHere: 0);
        rent.Allowed.Should().BeFalse();
        rent.Reason.Should().Be("Your plan does not include Rent. Get a plan with Rent to list here.");
    }

    [Fact]
    public async Task An_ended_plan_counts_for_nothing()
    {
        var old = Running("all3-monthly");
        old.EndsAt = Now.AddMinutes(-1);
        LiveService("AC service");

        (await CheckAsync(ListingArea.Rent, liveHere: 0)).Allowed.Should().BeFalse();
    }

    [Fact]
    public async Task An_area_that_cannot_be_reached_refuses_rather_than_lets_a_free_business_past_the_limit()
    {
        _areas.Unreachable = true;

        var add = () => Rules.EnsureCanAddAsync(Owner, ListingArea.Service, null, Now, CancellationToken.None);

        await add.Should().ThrowAsync<DomainException>().WithMessage("We couldn't check your plan just now.*");
    }

    [Fact]
    public async Task A_refusal_is_a_plan_limit_the_app_can_show_as_a_lock()
    {
        LiveService("AC service");

        var add = () => Rules.EnsureCanAddAsync(Owner, ListingArea.Service, null, Now, CancellationToken.None);

        await add.Should().ThrowAsync<PlanLimitException>();
    }

    // ---- My plan ----

    [Fact]
    public async Task My_plan_shows_Basic_the_counts_per_area_and_the_plans_on_sale()
    {
        LiveService("AC service");

        var plan = await Handlers().Handle(new GetMyBusinessPlanQuery(), default);

        plan.IsBasic.Should().BeTrue();
        plan.PlanName.Should().Be("Basic");
        plan.BasicLimit.Should().Be(1);
        plan.Areas.Select(a => (a.Area, a.LiveCount, a.CanAdd)).Should().Equal(
            ("Service", (int?)1, false), ("Rent", (int?)0, false), ("Marketplace", (int?)0, false));
        plan.Plans.Select(p => p.Code).Should().Equal("service-monthly", "all3-monthly");
    }

    // ---- Buying ----

    [Fact]
    public async Task Buying_raises_one_order_at_the_price_now_and_a_second_tap_reuses_it()
    {
        var first = await Handlers().Handle(new StartPlanPurchaseCommand(Plan("all3-monthly").Id), default);
        var again = await Handlers().Handle(new StartPlanPurchaseCommand(Plan("all3-monthly").Id), default);

        first.Amount.Should().Be(699m);
        first.ProviderOrderId.Should().Be("order_1");
        first.RazorpayKeyId.Should().Be("rzp_test_key");
        again.SubscriptionId.Should().Be(first.SubscriptionId);
        _payments.Verify(p => p.CreateCollectionOrderAsync(699m, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task A_price_set_after_a_purchase_started_never_changes_it()
    {
        var started = await Handlers().Handle(new StartPlanPurchaseCommand(Plan("all3-monthly").Id), default);
        Plan("all3-monthly").Price = 999m;

        var confirmed = await Handlers().Handle(new ConfirmPlanPurchaseCommand(started.SubscriptionId, "pay_1", "good"), default);

        _subscriptions.Single(s => s.Id == started.SubscriptionId).Amount.Should().Be(699m);
        confirmed.PlanName.Should().Be("All 3");
    }

    [Fact]
    public async Task A_plan_off_sale_or_Basic_cannot_be_bought()
    {
        var retired = () => Handlers().Handle(new StartPlanPurchaseCommand(Plan("retired").Id), default);
        var basic = () => Handlers().Handle(new StartPlanPurchaseCommand(Plan("basic").Id), default);

        await retired.Should().ThrowAsync<DomainException>().WithMessage("This plan is not on sale*");
        await basic.Should().ThrowAsync<DomainException>();
    }

    [Fact]
    public async Task A_paid_plan_runs_its_days_once_the_signature_checks_out_and_a_repeat_confirm_is_harmless()
    {
        var started = await Handlers().Handle(new StartPlanPurchaseCommand(Plan("all3-monthly").Id), default);

        var plan = await Handlers().Handle(new ConfirmPlanPurchaseCommand(started.SubscriptionId, "pay_1", "good"), default);
        var repeat = await Handlers().Handle(new ConfirmPlanPurchaseCommand(started.SubscriptionId, "pay_1", "good"), default);

        plan.IsBasic.Should().BeFalse();
        plan.EndsAt.Should().Be(Now.AddDays(30));
        plan.Areas.Should().OnlyContain(a => a.CanAdd);
        repeat.EndsAt.Should().Be(Now.AddDays(30), "the same payment confirmed twice runs the plan once");
    }

    [Fact]
    public async Task A_bad_signature_leaves_the_plan_unpaid()
    {
        var started = await Handlers().Handle(new StartPlanPurchaseCommand(Plan("all3-monthly").Id), default);

        var confirm = () => Handlers().Handle(new ConfirmPlanPurchaseCommand(started.SubscriptionId, "pay_1", "forged"), default);

        await confirm.Should().ThrowAsync<DomainException>().WithMessage("*could not be verified*");
        _subscriptions.Single().State.Should().Be(SubscriptionStatus.AwaitingPayment);
    }

    [Fact]
    public async Task Renewing_the_same_plan_adds_its_days_to_the_end()
    {
        Running("all3-monthly", daysLeft: 5);
        var started = await Handlers().Handle(new StartPlanPurchaseCommand(Plan("all3-monthly").Id), default);

        var plan = await Handlers().Handle(new ConfirmPlanPurchaseCommand(started.SubscriptionId, "pay_1", "good"), default);

        _subscriptions.Single(s => s.Id == started.SubscriptionId).StartsAt.Should().Be(Now.AddDays(5));
        _subscriptions.Single(s => s.Id == started.SubscriptionId).EndsAt.Should().Be(Now.AddDays(35));
        plan.EndsAt.Should().Be(Now.AddDays(35));
    }

    [Fact]
    public async Task Switching_to_another_plan_ends_the_old_one_and_pauses_what_only_it_allowed()
    {
        var old = Running("all3-monthly");
        var service = LiveService("AC service", minutesAgo: 300);
        var tent = Guid.NewGuid();
        _areas.Live[ListingArea.Rent] = [new AreaListing(tent, Now.AddMinutes(-100))];
        var started = await Handlers().Handle(new StartPlanPurchaseCommand(Plan("service-monthly").Id), default);

        await Handlers().Handle(new ConfirmPlanPurchaseCommand(started.SubscriptionId, "pay_1", "good"), default);

        old.State.Should().Be(SubscriptionStatus.Ended);
        service.IsActive.Should().BeTrue("Service is in the new plan");
        _areas.Paused.Should().Equal((ListingArea.Rent, tent));
        _paused.Should().ContainSingle(p => p.ListingId == tent && p.Area == ListingArea.Rent);
    }

    [Fact]
    public async Task A_first_plan_never_pauses_listings_a_business_already_had()
    {
        LiveService("AC service");
        _areas.Live[ListingArea.Rent] = [new AreaListing(Guid.NewGuid(), Now), new AreaListing(Guid.NewGuid(), Now)];
        var started = await Handlers().Handle(new StartPlanPurchaseCommand(Plan("service-monthly").Id), default);

        await Handlers().Handle(new ConfirmPlanPurchaseCommand(started.SubscriptionId, "pay_1", "good"), default);

        _areas.Paused.Should().BeEmpty();
    }

    // ---- A plan ends, and renewal ----

    [Fact]
    public async Task When_a_plan_ends_the_oldest_listing_stays_and_the_rest_are_paused()
    {
        var plan = Running("all3-monthly");
        plan.EndsAt = Now.AddMinutes(-5);
        var oldest = LiveService("AC service", minutesAgo: 900);
        var newer = LiveService("Plumbing", minutesAgo: 10);
        var tent = Guid.NewGuid();
        var saree = Guid.NewGuid();
        _areas.Live[ListingArea.Rent] = [new AreaListing(tent, Now.AddMinutes(-500))];
        _areas.Live[ListingArea.Marketplace] = [new AreaListing(saree, Now.AddMinutes(-50))];

        var ended = await Reconciler.EndDuePlansAsync(Now, CancellationToken.None);

        ended.Should().Be(1);
        plan.State.Should().Be(SubscriptionStatus.Ended);
        oldest.IsActive.Should().BeTrue("Basic keeps the oldest live listing");
        newer.IsActive.Should().BeFalse();
        _areas.Paused.Should().BeEquivalentTo([(ListingArea.Rent, tent), (ListingArea.Marketplace, saree)]);
        _paused.Should().HaveCount(3);
    }

    [Fact]
    public async Task A_listing_paused_before_and_switched_back_on_is_not_recorded_twice()
    {
        var plan = Running("all3-monthly");
        plan.EndsAt = Now.AddMinutes(-5);
        LiveService("AC service", minutesAgo: 900);
        var tent = Guid.NewGuid();
        _areas.Live[ListingArea.Rent] = [new AreaListing(tent, Now.AddMinutes(-100))];
        _paused.Add(new PlanPausedListing { OwnerUserId = Owner, Area = ListingArea.Rent, ListingId = tent, PausedAt = Now.AddDays(-40) });

        await Reconciler.EndDuePlansAsync(Now, CancellationToken.None);

        _paused.Should().ContainSingle(p => p.ListingId == tent).Which.PausedAt.Should().Be(Now);
    }

    [Fact]
    public async Task A_plan_end_that_cannot_reach_an_area_waits_for_the_next_run()
    {
        var plan = Running("all3-monthly");
        plan.EndsAt = Now.AddMinutes(-5);
        _areas.Unreachable = true;

        (await Reconciler.EndDuePlansAsync(Now, CancellationToken.None)).Should().Be(0);
        plan.State.Should().Be(SubscriptionStatus.Active);
    }

    [Fact]
    public async Task Renewing_brings_back_exactly_what_the_plan_end_paused()
    {
        var paused = LiveService("Plumbing");
        paused.IsActive = false;
        var tent = Guid.NewGuid();
        _paused.Add(new PlanPausedListing { OwnerUserId = Owner, Area = ListingArea.Service, ListingId = paused.Id });
        _paused.Add(new PlanPausedListing { OwnerUserId = Owner, Area = ListingArea.Rent, ListingId = tent });
        var started = await Handlers().Handle(new StartPlanPurchaseCommand(Plan("all3-monthly").Id), default);

        var plan = await Handlers().Handle(new ConfirmPlanPurchaseCommand(started.SubscriptionId, "pay_1", "good"), default);

        paused.IsActive.Should().BeTrue();
        _areas.Resumed.Should().Equal((ListingArea.Rent, tent));
        _paused.Should().BeEmpty();
        plan.PausedCount.Should().Be(0);
    }

    // ---- Super Admin gives a plan ----

    private GivePlanCommandHandler Give()
    {
        var clock = new Mock<IDateTimeProvider>();
        clock.Setup(c => c.UtcNow).Returns(() => _now);
        return new GivePlanCommandHandler(_db.Object, Reconciler, clock.Object);
    }

    private BusinessOwnerProfile Business()
    {
        var business = new BusinessOwnerProfile { UserId = Owner, BusinessName = "Test Store" };
        _db.Setup(d => d.BusinessOwnerProfiles).Returns(TestDbSet.From(business));
        return business;
    }

    [Fact]
    public async Task A_given_plan_is_free_runs_the_days_chosen_and_opens_its_areas()
    {
        var business = Business();
        LiveService("AC service");

        var given = await Give().Handle(new GivePlanCommand(business.Id, Plan("all3-monthly").Id, 90), default);

        given.PlanName.Should().Be("All 3");
        given.EndsAt.Should().Be(Now.AddDays(90));
        _subscriptions.Single().Amount.Should().Be(0m);
        _subscriptions.Single().PaymentId.Should().BeNull();
        (await CheckAsync(ListingArea.Rent, liveHere: 0)).Allowed.Should().BeTrue();
        _payments.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task Giving_the_same_plan_again_adds_the_days_and_Basic_cannot_be_given()
    {
        var business = Business();
        await Give().Handle(new GivePlanCommand(business.Id, Plan("all3-monthly").Id, 30), default);

        var again = await Give().Handle(new GivePlanCommand(business.Id, Plan("all3-monthly").Id, 30), default);
        again.EndsAt.Should().Be(Now.AddDays(60));

        var basic = () => Give().Handle(new GivePlanCommand(business.Id, Plan("basic").Id, 30), default);
        await basic.Should().ThrowAsync<DomainException>().WithMessage("Every business is on Basic already*");
        new GivePlanCommandValidator().TestValidate(new GivePlanCommand(business.Id, Plan("all3-monthly").Id, 0))
            .ShouldHaveValidationErrorFor(x => x.Days);
    }

    // ---- Super Admin prices ----

    [Fact]
    public async Task The_super_admin_changes_a_price_and_Basic_stays_free()
    {
        var admin = new PricingAdminHandlers(_db.Object);
        var all3 = Plan("all3-monthly");

        var changed = await admin.Handle(new UpdatePlanCommand(all3.Id, "All 3", 749m, 30, null, true, 3), default);
        changed.Price.Should().Be(749m);

        var basicPrice = () => admin.Handle(new UpdatePlanCommand(Plan("basic").Id, "Basic", 10m, null, 1, true, 1), default);
        await basicPrice.Should().ThrowAsync<DomainException>().WithMessage("The Basic plan stays free*");

        var basicLimit = await admin.Handle(new UpdatePlanCommand(Plan("basic").Id, "Starter", 0m, null, 2, true, 1), default);
        basicLimit.MaxLiveListings.Should().Be(2);
        basicLimit.Name.Should().Be("Starter");

        var noDays = () => admin.Handle(new UpdatePlanCommand(all3.Id, "All 3", 749m, null, null, true, 3), default);
        await noDays.Should().ThrowAsync<DomainException>().WithMessage("A paid plan needs a number of days.");
    }

    [Fact]
    public async Task The_super_admin_adds_and_edits_hiring_post_options()
    {
        var admin = new PricingAdminHandlers(_db.Object);

        var added = await admin.Handle(new SaveHiringPlanCommand(null, "3 months", 199m, 90, true, 2), default);
        await admin.Handle(new SaveHiringPlanCommand(_hiringPlans[0].Id, "1 month", 109m, 30, true, 1), default);

        _hiringPlans.Should().HaveCount(2);
        added.ListingDays.Should().Be(90);
        _hiringPlans[0].Amount.Should().Be(109m);
        (await admin.Handle(new GetPricingQuery(), default)).HiringPlans.Should().HaveCount(2);
    }

    [Fact]
    public void Prices_are_checked()
    {
        new UpdatePlanCommandValidator().TestValidate(new UpdatePlanCommand(Guid.NewGuid(), "", -1m, 0, null, true, 1))
            .ShouldHaveValidationErrorFor(x => x.Name);
        new SaveHiringPlanCommandValidator().TestValidate(new SaveHiringPlanCommand(null, "1 month", 99m, 0, true, 1))
            .ShouldHaveValidationErrorFor(x => x.ListingDays);
    }

    private sealed class FakeAreas : IAreaListings
    {
        public Dictionary<ListingArea, List<AreaListing>> Live { get; } = new()
        {
            [ListingArea.Rent] = [],
            [ListingArea.Marketplace] = [],
        };

        public List<ListingArea> Asked { get; } = [];

        public List<(ListingArea, Guid)> Paused { get; } = [];

        public List<(ListingArea, Guid)> Resumed { get; } = [];

        public bool Unreachable { get; set; }

        public Task<IReadOnlyList<AreaListing>> LiveAsync(ListingArea area, Guid ownerUserId, CancellationToken cancellationToken)
        {
            Asked.Add(area);
            return Unreachable
                ? throw new AreaUnavailableException(area)
                : Task.FromResult<IReadOnlyList<AreaListing>>(Live[area]);
        }

        public Task PauseAsync(ListingArea area, Guid ownerUserId, IReadOnlyCollection<Guid> listingIds, CancellationToken cancellationToken)
        {
            Paused.AddRange(listingIds.Select(id => (area, id)));
            return Task.CompletedTask;
        }

        public Task ResumeAsync(ListingArea area, Guid ownerUserId, IReadOnlyCollection<Guid> listingIds, CancellationToken cancellationToken)
        {
            Resumed.AddRange(listingIds.Select(id => (area, id)));
            return Task.CompletedTask;
        }
    }
}
