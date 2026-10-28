namespace Zuno.Application.Modules.Catalog.DTOs;

/// <summary>How the apps show one order stage: everything about it that is not a code decision.</summary>
public class OrderStageDto
{
    /// <summary>The stage's name — <c>AwaitingPayment</c> — matching an order's <c>Stage</c>.</summary>
    public string Code { get; set; } = string.Empty;

    /// <summary>What the chip and filter say: "Awaiting payment".</summary>
    public string Label { get; set; } = string.Empty;

    public int SortOrder { get; set; }

    /// <summary><c>success</c>, <c>progress</c>, <c>waiting</c> or <c>danger</c>.</summary>
    public string Tone { get; set; } = string.Empty;

    public bool ShowOnBookings { get; set; }

    public bool ShowOnWork { get; set; }
}
