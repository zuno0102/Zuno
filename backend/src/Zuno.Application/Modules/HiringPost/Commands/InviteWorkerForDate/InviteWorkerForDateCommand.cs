using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.HiringPost.Commands.InviteWorkerForDate;

/// <summary>
/// Offers a worker a day's work on a date of the business's choosing, with no hiring post to
/// attach it to and no customer order behind it.
/// </summary>
/// <remarks>
/// The gap this fills: a business that wants the same worker on the 14th and again on the 20th had
/// nowhere to say so. Adding them to the workers list is a one-off — the roster holds one row per
/// worker and carries no date, so a second invite was refused as a duplicate — and inviting them to
/// a job meant creating a whole hiring post first.
///
/// So this creates the post itself, as the business's own event, and sends the offer in the same
/// breath. One date, one post, which is what lets the same worker be asked for as many days as the
/// business likes: each is a separate offer they can take or turn down on its own.
/// </remarks>
public class InviteWorkerForDateCommand : IRequest<HiringPostDto>
{
    /// <summary>The email or phone number the worker registered with.</summary>
    public string WorkerIdentifier { get; set; } = string.Empty;

    /// <summary>When the work starts.</summary>
    public DateTimeOffset EventDate { get; set; }

    /// <summary>What the worker is being offered. Shown to them before they answer.</summary>
    public decimal SalaryAmount { get; set; }

    public SalaryUnit SalaryUnit { get; set; } = SalaryUnit.PerEvent;

    /// <summary>
    /// Optional. Left empty, the post is named for the day it falls on, which is all the business
    /// gave us and all the worker needs to tell one offer from another.
    /// </summary>
    public string? Title { get; set; }

    /// <summary>How long the work runs. Defaults to the same two hours a hiring post does.</summary>
    public int DurationMinutes { get; set; } = 120;
}
