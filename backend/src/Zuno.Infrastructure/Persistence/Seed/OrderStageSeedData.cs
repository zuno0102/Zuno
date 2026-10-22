using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Infrastructure.Persistence.Seed;

/// <summary>
/// The starting names, colours and order of the order stages — the words the apps showed before
/// they came from the database. Edit the rows, not this file, to change them on a live system.
/// </summary>
public static class OrderStageSeedData
{
    private static readonly DateTimeOffset SeedDate = new(2026, 10, 22, 0, 0, 0, TimeSpan.Zero);

    public static OrderStageDefinition[] All =>
    [
        Build("b1111111-0000-0000-0000-000000000001", OrderStage.Active, "Active", 1, "waiting", onBookings: true, onWork: false),
        Build("b1111111-0000-0000-0000-000000000002", OrderStage.Confirmed, "Confirmed", 2, "success", onBookings: true, onWork: true),
        Build("b1111111-0000-0000-0000-000000000003", OrderStage.InProgress, "In progress", 3, "progress", onBookings: true, onWork: true),
        Build("b1111111-0000-0000-0000-000000000004", OrderStage.AwaitingPayment, "Awaiting payment", 4, "progress", onBookings: true, onWork: true),
        Build("b1111111-0000-0000-0000-000000000005", OrderStage.Completed, "Completed", 5, "success", onBookings: true, onWork: true),
        // Not on Status management: a cancelled order has no work left to move along.
        Build("b1111111-0000-0000-0000-000000000006", OrderStage.Cancelled, "Cancelled", 6, "danger", onBookings: true, onWork: false),
    ];

    private static OrderStageDefinition Build(
        string id,
        OrderStage stage,
        string displayName,
        int sortOrder,
        string tone,
        bool onBookings,
        bool onWork) =>
        new()
        {
            Id = new Guid(id),
            Stage = stage,
            DisplayName = displayName,
            SortOrder = sortOrder,
            Tone = tone,
            ShowOnBookings = onBookings,
            ShowOnWork = onWork,
            CreatedDate = SeedDate,
            IsDeleted = false,
        };
}
