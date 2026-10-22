namespace Zuno.Application.Modules.Business.DTOs;

/// <summary>One booking behind a dashboard tile — enough to recognise it without opening it.</summary>
public class DashboardEventDto
{
    public Guid Id { get; set; }

    public string ServiceName { get; set; } = string.Empty;

    public string CategoryName { get; set; } = string.Empty;

    /// <summary>The package booked, by its sub-category name where it has one.</summary>
    public string? SubCategoryName { get; set; }

    public string CustomerName { get; set; } = string.Empty;

    public DateTimeOffset ScheduledDate { get; set; }

    public decimal Price { get; set; }

    public int RequiredWorkerCount { get; set; }

    public string Status { get; set; } = string.Empty;

    public DateTimeOffset? CancelledAt { get; set; }

    public string? CancellationReason { get; set; }

    public string? City { get; set; }
}

/// <summary>
/// One crew event — a hiring post the business ran. Separate from a booking: it is a call for
/// workers, so it has a crew and a wage bill rather than a customer and a price.
/// </summary>
public class CrewEventDto
{
    public Guid Id { get; set; }

    public string Title { get; set; } = string.Empty;

    public DateTimeOffset EventDate { get; set; }

    public string? Location { get; set; }

    public int WorkersNeeded { get; set; }

    public int WorkersHired { get; set; }

    public DateTimeOffset? WorkCompletedAt { get; set; }

    /// <summary>Whether every hired worker has been paid — what makes the event count.</summary>
    public bool IsFullySettled { get; set; }

    public decimal TotalWages { get; set; }

    public decimal OutstandingWages { get; set; }
}
