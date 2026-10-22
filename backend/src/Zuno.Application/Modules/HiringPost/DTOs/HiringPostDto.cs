namespace Zuno.Application.Modules.HiringPost.DTOs;

public class HiringPostDto
{
    public Guid Id { get; set; }

    public Guid BusinessOwnerProfileId { get; set; }

    /// <summary>The customer order this crew was hired for, when the post was raised from one.</summary>
    public Guid? BookingId { get; set; }

    /// <summary>"Catering · 28 Sep" — enough for a card to say what the hire is for.</summary>
    public string? BookingReference { get; set; }

    /// <summary>
    /// Where that order stands — Confirmed, Completed, Cancelled. Null for a standalone post,
    /// which answers to no order.
    /// </summary>
    /// <remarks>
    /// Carried so a client can stop offering a job whose order is already over. A post does not
    /// close itself when its order completes, so its own <see cref="Status"/> says nothing about
    /// this.
    /// </remarks>
    public string? BookingStatus { get; set; }

    public string BusinessName { get; set; } = string.Empty;

    public string? BusinessLogoUrl { get; set; }

    /// <summary>
    /// The business's phone number. Only filled for a worker's own accepted jobs ("Jobs you took"),
    /// so a worker can call the business about the work; empty everywhere else.
    /// </summary>
    public string? BusinessPhone { get; set; }

    public string Title { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string? ImageUrl { get; set; }

    public DateTimeOffset EventDate { get; set; }

    public int DurationMinutes { get; set; }

    /// <summary>Computed from EventDate + DurationMinutes; the window the job occupies.</summary>
    public DateTimeOffset EventEndDate { get; set; }

    /// <summary>Set when the business says the crew has started. Null while the job is only scheduled.</summary>
    public DateTimeOffset? WorkStartedAt { get; set; }

    /// <summary>Set when the business marks the work done. Releases the crew for other jobs.</summary>
    public DateTimeOffset? WorkCompletedAt { get; set; }

    /// <summary>Set when the business stopped hiring and will manage with the crew it has.</summary>
    public DateTimeOffset? HiringStoppedAt { get; set; }

    /// <summary>Set when the last worker was paid. The moment the hiring genuinely ended.</summary>
    public DateTimeOffset? SettledAt { get; set; }

    /// <summary>What the whole crew is owed. Calculated on the server from each agreed wage.</summary>
    public decimal TotalPayable { get; set; }

    /// <summary>Still owed. Zero exactly when everyone has been paid.</summary>
    public decimal OutstandingAmount { get; set; }

    public int PayeeCount { get; set; }

    public int PaidPayeeCount { get; set; }

    /// <summary>A worker has reported their wages never arrived.</summary>
    public bool HasDisputedPayment { get; set; }

    /// <summary>
    /// The work is done and every worker has been paid — the whole hiring finished, as distinct
    /// from the event merely being over or the places merely being filled. Only this counts
    /// toward the business's completed-job total.
    /// </summary>
    public bool IsFullyComplete { get; set; }

    public string? Location { get; set; }

    public Guid? DistrictId { get; set; }

    /// <summary>
    /// Where the job is, for drawing it on a map. Null when the post has no position.
    /// </summary>
    /// <remarks>
    /// Sent to every viewer, not just workers: a business needs to see the pin it set in order to
    /// check it, and the value is the job site rather than anybody's home address.
    /// </remarks>
    public decimal? Latitude { get; set; }

    public decimal? Longitude { get; set; }

    /// <summary>The district name, for grouping the feed and labelling a card.</summary>
    public string? DistrictName { get; set; }

    /// <summary>
    /// How well the job's position is known: None, DistrictApprox, Geocoded or Pinned.
    /// </summary>
    /// <remarks>
    /// None means the post cannot take part in a distance search at all, and the client lists it
    /// separately rather than hiding it. Anything less than Pinned should be shown as approximate.
    /// </remarks>
    public string LocationPrecision { get; set; } = string.Empty;

    /// <summary>
    /// Straight-line kilometres from the worker who asked, or null.
    /// </summary>
    /// <remarks>
    /// Null in three different situations, which the client tells apart using
    /// <see cref="LocationPrecision"/>: the viewer is not a worker, the worker gave no location, or
    /// the post has no position. Straight-line, so it reads lower than road distance — roughly 1.15
    /// to 1.8 times lower in Kerala.
    /// </remarks>
    public double? DistanceKm { get; set; }

    /// <summary>The kind of work, inside the category — "Interior wall painting".</summary>
    public Guid? ServiceSubCategoryId { get; set; }

    /// <summary>Its name, so a worker can judge the job without opening it.</summary>
    public string? ServiceSubCategoryName { get; set; }

    public int WorkersNeeded { get; set; }

    public decimal SalaryAmount { get; set; }

    public string SalaryUnit { get; set; } = string.Empty;

    public int ConfirmedCount { get; set; }

    /// <summary>Offers approved by the business that the worker has not answered yet.</summary>
    public int PendingOfferCount { get; set; }

    /// <summary>Everyone actually working the event: the workers who accepted.</summary>
    public int FilledCount { get; set; }

    public string Status { get; set; } = string.Empty;

    /// <summary>
    /// Where the business's own event stands — an <c>OrderStage</c> name, the same words as an
    /// order's, so both sit under one set of filters. Looked up in <c>/order-stages</c>.
    /// </summary>
    public string Stage { get; set; } = string.Empty;

    public DateTimeOffset CreatedDate { get; set; }

    public string? MyApplicationStatus { get; set; }

    /// <summary>For a worker viewing the post: their own application id, so they can respond to an offer.</summary>
    public Guid? MyApplicationId { get; set; }

    /// <summary>
    /// For a worker viewing the post: the salary locked in for them personally. Once confirmed
    /// this is the binding figure, which may differ from <see cref="SalaryAmount"/> if the post
    /// was later edited upwards or they were granted a raise.
    /// </summary>
    public decimal? MyAgreedSalaryAmount { get; set; }

    /// <summary>
    /// For a worker viewing the post: whether <em>their own</em> wages have been paid.
    /// </summary>
    /// <remarks>
    /// Carried here rather than read off <see cref="Applications"/>, which is withheld from worker
    /// viewers so one applicant cannot see the rest of the crew's contact details. Without these
    /// fields a worker has no way to learn whether they were paid — and no standing to dispute it.
    /// </remarks>
    public string? MyPaymentStatus { get; set; }

    public DateTimeOffset? MyPaidAt { get; set; }

    public string? MyDisputeReason { get; set; }

    public List<HiringPostApplicationDto> Applications { get; set; } = [];

}
