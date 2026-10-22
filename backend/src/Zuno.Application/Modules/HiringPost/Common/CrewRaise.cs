using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.Events;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using MediatR;

namespace Zuno.Application.Modules.HiringPost.Common;

/// <summary>
/// The one way a whole crew's hiring-post wages go up together: the same extra amount on every
/// worker still waiting to be paid. Shared by the order and own-event "Raise all" commands.
/// </summary>
public static class CrewRaise
{
    /// <summary>
    /// Adds <paramref name="increase"/> to each raisable hire on <paramref name="post"/>, skipping
    /// anyone whose pay is already being sent. Adjustments are added to the context, not saved.
    /// </summary>
    /// <returns>The hires that were raised.</returns>
    public static async Task<List<HiringPostApplication>> RaisePostHiresAsync(
        Domain.Entities.HiringPost post,
        decimal increase,
        string? reason,
        IApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var candidates = post.Applications.Where(a => a.IsRaisableCrewMember).ToList();
        if (candidates.Count == 0)
        {
            return candidates;
        }

        var candidateIds = candidates.Select(a => a.Id).ToList();
        var beingPaid = await dbContext.PayoutBatches
            .Where(b => b.BatchStatus == PayoutBatchStatus.Disbursing)
            .SelectMany(b => b.Items)
            .Where(i => i.HiringPostApplicationId != null && candidateIds.Contains(i.HiringPostApplicationId.Value))
            .Select(i => i.HiringPostApplicationId!.Value)
            .ToListAsync(cancellationToken);

        var raised = candidates.Where(a => !beingPaid.Contains(a.Id)).ToList();
        foreach (var hire in raised)
        {
            dbContext.HiringPostSalaryAdjustments.Add(
                hire.RaiseSalary(hire.AgreedSalaryAmount!.Value + increase, reason));
        }

        return raised;
    }

    /// <summary>Tells each raised worker their new wage, as a single raise does.</summary>
    public static async Task NotifyAsync(
        Domain.Entities.HiringPost post,
        IEnumerable<HiringPostApplication> raised,
        IPublisher publisher,
        CancellationToken cancellationToken)
    {
        foreach (var hire in raised)
        {
            await publisher.Publish(
                new HiringPostSalaryRaisedEvent(
                    post.Id,
                    hire.WorkerProfile.UserId,
                    post.Title,
                    hire.AgreedSalaryAmount!.Value,
                    hire.AgreedSalaryUnit ?? post.SalaryUnit,
                    post.EventDate),
                cancellationToken);
        }
    }
}
