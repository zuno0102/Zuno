namespace Zuno.Application.Modules.Booking.DTOs;

public class BookingDto
{
    public Guid Id { get; set; }

    /// <summary>The short order code — "#7A3F91C2" — shown to people and quoted on hires.</summary>
    public string Reference { get; set; } = string.Empty;

    /// <summary>
    /// How far staffing has got: NotStaffed, PartStaffed, FullyStaffed, Done. A separate track
    /// from <c>Status</c>, which is the order's own progress.
    /// </summary>
    public string CrewStatus { get; set; } = string.Empty;

    /// <summary>People on the job right now — offered or accepted.</summary>
    public int ActiveCrewCount { get; set; }

    /// <summary>
    /// Where the crew's wages stand: NoWagesThroughZuno, Disputed, Outstanding or Settled. Empty
    /// for a customer, and empty when the caller did not ask for it — which is not the same as
    /// owing nothing.
    /// </summary>
    public string WageStatus { get; set; } = string.Empty;

    /// <summary>Accepted workers owed a wage through the app, across every hiring post on this order.</summary>
    public int WagePayeeCount { get; set; }

    public int WagePaidPayeeCount { get; set; }

    public decimal WageTotalPayable { get; set; }

    public decimal WageOutstandingAmount { get; set; }

    /// <summary>When the business marked the work under way.</summary>
    public DateTimeOffset? WorkStartedAt { get; set; }

    public Guid BusinessOwnerProfileId { get; set; }

    public string BusinessName { get; set; } = string.Empty;

    public string? BusinessLogoUrl { get; set; }

    public string? BusinessPhone { get; set; }

    public Guid CustomerProfileId { get; set; }

    public string CustomerName { get; set; } = string.Empty;

    public string? CustomerPhone { get; set; }

    public Guid BusinessServiceId { get; set; }

    public string ServiceName { get; set; } = string.Empty;

    public string ServiceCategoryName { get; set; } = string.Empty;

    public Guid? BusinessServiceVariantId { get; set; }

    public string? VariantName { get; set; }

    /// <summary>The kind of work this order is for, from the package the customer chose.</summary>
    public Guid? ServiceSubCategoryId { get; set; }

    public string? ServiceSubCategoryName { get; set; }

    public string? ImageUrl { get; set; }

    public int RequiredWorkerCount { get; set; } = 1;

    public List<BookingWorkerAssignmentDto> AssignedWorkers { get; set; } = [];

    public string? MyAssignmentStatus { get; set; }

    /// <summary>What the viewing worker is on this one job — "Supervisor". Null for everyone else.</summary>
    /// <remarks>
    /// Holding a role is what lets a worker say this job's work has started and finished, so their
    /// own screen has to know whether they hold one. Per job, never per person: the same worker can
    /// lead Saturday's job and be an ordinary pair of hands on Sunday's.
    /// </remarks>
    public string? MyRole { get; set; }

    /// <summary>Where the viewing worker's own wage stands on this order. Null for anyone else.</summary>
    /// <remarks>
    /// Their own row, never the crew's. <see cref="WageStatus"/> rolls up every worker on the order
    /// and is the business's view of it; a worker shown that figure would read somebody else's unpaid
    /// wage as their own. It is also only populated when a caller asks for wages, which the worker's
    /// job list does not — so without this the worker's own screens had no wage information at all.
    /// </remarks>
    public string? MyPaymentStatus { get; set; }

    /// <summary>
    /// The wage on the viewing worker's own assignment, or null when there is none on it.
    /// </summary>
    /// <remarks>
    /// Null is the ordinary case for a worker who reached this order through a hiring post: accepting
    /// creates a mirror assignment deliberately without a salary, because the wage lives on the
    /// application and money must never be recorded twice. So a null here means "my pay for this job
    /// is not held on this row", not "I am owed nothing".
    /// </remarks>
    public decimal? MyWageAmount { get; set; }

    public string Status { get; set; } = string.Empty;

    /// <summary>
    /// Where the order stands as the viewer reads it — an <c>OrderStage</c> name such as
    /// <c>AwaitingPayment</c>. The apps look its name and colour up in <c>/order-stages</c>.
    /// </summary>
    public string Stage { get; set; } = string.Empty;

    public DateTimeOffset ScheduledDate { get; set; }

    public string? Notes { get; set; }

    public decimal PriceQuoted { get; set; }

    /// <summary>
    /// What <see cref="PriceQuoted"/> is a price of — Fixed, Hourly, Daily or PerPerson.
    /// </summary>
    /// <remarks>
    /// Null on orders placed before this was recorded; the client shows those unitless, exactly
    /// as it always did. Sent to every viewer, including the customer: this is what the order
    /// costs, which is the customer's business even though the crew size is not.
    /// </remarks>
    public string? PriceType { get; set; }

    /// <summary>
    /// What the customer told the business about this job — the thing that says how many people
    /// it actually needs.
    /// </summary>
    /// <remarks>
    /// Sent to everyone who can see the order. The crew size is kept from the customer, but what
    /// the customer themselves wrote plainly is not a secret from them.
    /// </remarks>
    public List<BookingServiceAnswerDto> ServiceAnswers { get; set; } = [];

    /// <summary>
    /// Who owes the other a reply on the crew and price: NotRequired, AwaitingBusiness,
    /// AwaitingCustomer, Agreed or Closed.
    /// </summary>
    /// <remarks>
    /// Derived, never stored — and deliberately not a <c>BookingStatus</c> value, so no switch
    /// over the order's own status had to change and no older build can meet a status it cannot
    /// label.
    /// </remarks>
    public string AgreementStatus { get; set; } = "NotRequired";

    /// <summary>Every offer and counter-offer, oldest first.</summary>
    public List<BookingTermsProposalDto> Proposals { get; set; } = [];

    public string? AddressLine1 { get; set; }

    /// <summary>Landmark or second line — the part that tells somebody which gate.</summary>
    public string? AddressLine2 { get; set; }

    /// <summary>The pinned job location. Null on bookings made before pinning existed.</summary>
    public decimal? Latitude { get; set; }

    public decimal? Longitude { get; set; }

    public string? City { get; set; }

    public string? State { get; set; }

    public string? PostalCode { get; set; }

    public DateTimeOffset? CompletedAt { get; set; }

    public DateTimeOffset? CancelledAt { get; set; }

    public string? CancellationReason { get; set; }

    public RatingDto? Rating { get; set; }
}
