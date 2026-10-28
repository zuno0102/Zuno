using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.HiringPost.Common;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.CreatePayoutBatch;

/// <summary>
/// Opens a pay run for a finished job: one amount for the business to pay, split across everyone
/// still owed.
/// </summary>
public class CreatePayoutBatchCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IPayoutProvider payoutProvider,
    IOptions<RazorpaySettings> razorpaySettings,
    IApplicationDbContext dbContext) : IRequestHandler<CreatePayoutBatchCommand, PayoutBatchDto>
{
    public async Task<PayoutBatchDto> Handle(CreatePayoutBatchCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var post = await dbContext.LoadHiringPostAsync(
            dbContext.HiringPosts.Where(p => p.Id == request.HiringPostId),
            cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.HiringPost), request.HiringPostId);

        if (post.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This hiring post does not belong to your business.");
        }

        if (post.WorkCompletedAt is null)
        {
            throw new DomainException("Mark the work completed before paying the crew.");
        }

        // RULE 2 — a settled job cannot be paid again. Checked before anything else so a
        // double-tapped button is refused outright rather than opening a second run.
        if (post.IsFullySettled)
        {
            throw new DomainException("Payment already completed. Every worker on this job has been paid.");
        }

        // An unfinished run is reused rather than replaced. Tapping "Pay all" twice must lead back
        // to the same order, not create a second obligation for the same wages.
        var existing = await dbContext.PayoutBatches
            .Include(b => b.Items).ThenInclude(i => i.WorkerProfile).ThenInclude(w => w!.PayoutDetail)
            .FirstOrDefaultAsync(
                b => b.HiringPostId == post.Id
                     && (b.BatchStatus == PayoutBatchStatus.AwaitingCollection
                         || b.BatchStatus == PayoutBatchStatus.Disbursing
                         // A run that paid some and failed others is finished collecting: its
                         // money is already in. Raising a second order for the same wages is
                         // how the business ended up charged twice for one worker.
                         || b.BatchStatus == PayoutBatchStatus.PartiallyFailed),
                cancellationToken);

        // Money is already moving, or already in. Either way that run finishes as it is: a
        // PartiallyFailed one is retried by confirming it again, which re-sends the failed lines
        // from money already collected rather than asking the business for it a second time.
        if (existing is { BatchStatus: PayoutBatchStatus.Disbursing or PayoutBatchStatus.PartiallyFailed })
        {
            return existing.ToDto(razorpaySettings.Value.KeyId, razorpaySettings.Value.SimulateCollection);
        }

        // Nothing can be sent to anybody, so nothing is collected from anybody. This is a setting,
        // not a fact about one worker: payouts are a RazorpayX product and the gateway keys that
        // collect money cannot disburse it, so with no account number configured every payout on
        // this deployment fails.
        //
        // It was only read inside the provider, during disbursement — after the business had been
        // through Checkout and paid. A business was charged in full to be told the platform could
        // not pay anyone, which is the same mistake as charging for an unpayable worker, one level
        // up. Checked after the early returns above, so a run already funded can still be retried
        // once payouts are switched on.
        if (!razorpaySettings.Value.CanDisburse)
        {
            throw new DomainException(
                "Payouts are not switched on for this account yet, so nobody on this job can be "
                + "paid. Nothing has been charged. Enable RazorpayX payouts and set the payout "
                + "account number, then try again.");
        }

        var batch = new PayoutBatch
        {
            HiringPostId = post.Id,
            BusinessOwnerProfileId = businessProfile.Id,
            BatchStatus = PayoutBatchStatus.AwaitingCollection,
        };

        // Who was left out, and why, so the sheet can name them instead of the business noticing
        // a total that is lower than the wages it knows it owes.
        var excluded = new List<PayoutExclusion>();

        // RULE 1 — the total is summed here, from the wages agreed with each worker. Whatever the
        // client believes the figure is plays no part in it.
        foreach (var application in post.Applications
                     .Where(a => a.ApplicationStatus == HiringPostApplicationStatus.Accepted
                                 && a.PaymentStatus != PaymentStatus.Paid))
        {
            var amount = application.AgreedSalaryAmount ?? 0m;

            // A ₹0 wage is a data fault, not a free worker. Paying it would silently settle
            // someone for nothing and count the job as complete.
            if (amount <= 0m)
            {
                var name = application.WorkerProfile.User is null
                    ? "A worker"
                    : $"{application.WorkerProfile.User.FirstName} {application.WorkerProfile.User.LastName}".Trim();

                throw new DomainException(
                    $"{name} has no agreed salary recorded for this job. Set it before paying the crew.");
            }

            var workerName = application.WorkerProfile.User is null
                ? "Worker"
                : $"{application.WorkerProfile.User.FirstName} {application.WorkerProfile.User.LastName}".Trim();

            // Nobody is charged for a worker the money cannot reach. The destination used to be
            // read only at disbursement, long after the business had paid for the whole crew —
            // so a wage that could never be delivered was collected anyway and, with no refund
            // anywhere in this system, simply kept.
            //
            // Left out of the run rather than added and failed: the application stays Unpaid, so
            // the job keeps saying Awaiting payment and the business can pay them in a later run
            // once there is somewhere to send it. Four payable workers at ₹1,000 collect ₹4,000,
            // and the fifth costs ₹1,000 when they are ready — never ₹5,000 for four.
            var destination = application.WorkerProfile.PayoutDetail;
            if (destination is null || !destination.CanReceivePayouts)
            {
                excluded.Add(new PayoutExclusion(
                    workerName,
                    destination is null || !destination.HasDestination
                        ? "No UPI ID on file — ask the worker to add one."
                        : "UPI is not verified — check with the worker."));
                continue;
            }

            batch.Items.Add(new PayoutBatchItem
            {
                HiringPostApplicationId = application.Id,
                WorkerProfileId = application.WorkerProfileId,
                WorkerName = workerName,
                Amount = amount,
                PaymentStatus = PaymentStatus.Unpaid,
            });
        }

        if (batch.Items.Count == 0)
        {
            // Said in terms of why, not just that there is nobody. "Nobody left to pay" on a job
            // with five unpaid workers reads as a bug, and the business would keep pressing it.
            throw new DomainException(
                excluded.Count == 0
                    ? "There is nobody left to pay on this job."
                    : "Nobody on this job can be paid yet. "
                      + string.Join(" ", excluded.Select(e => $"{e.WorkerName}: {e.Reason}")));
        }

        batch.TotalAmount = batch.Items.Sum(i => i.Amount);

        // The client's figure is only ever a cross-check. Disagreeing with the server means the
        // two are looking at different crews, and paying either amount would be wrong.
        // Only a total *higher* than the business expected is a disagreement worth refusing. The
        // guard used to demand the two match exactly, which stopped being right once a run could
        // leave someone out: the client sends every wage the job owes, and a run that skips an
        // unpayable worker collects less than that on purpose. Refusing it would make a job with
        // one unpaid-able worker impossible to pay at all.
        //
        // Lower is always safe — nobody is charged for someone who was not included, and
        // ExcludedPayees says who and why. Higher still throws, because being charged more than
        // the screen said is the thing this was written to prevent.
        if (request.ExpectedTotal is { } claimed && batch.TotalAmount > claimed)
        {
            throw new DomainException(
                $"Amount mismatch. This job owes {batch.TotalAmount:C0} across {batch.Items.Count} worker(s), "
                + $"not {claimed:C0}. Reload the job and try again.");
        }

        if (existing is not null)
        {
            if (existing.PaysSameWagesAs(batch))
            {
                return existing.ToDto(razorpaySettings.Value.KeyId, razorpaySettings.Value.SimulateCollection);
            }

            // A salary was raised after this run was opened but before the business paid it.
            // Reusing it would collect the old total, so it is closed and a run at the new total
            // takes its place.
            existing.BatchStatus = PayoutBatchStatus.Abandoned;
        }

        var order = await payoutProvider.CreateCollectionOrderAsync(
            batch.TotalAmount,
            batch.IdempotencyKey,
            $"{post.Title} — {batch.Items.Count} worker(s)",
            cancellationToken);

        batch.ProviderOrderId = order.ProviderOrderId;

        dbContext.PayoutBatches.Add(batch);
        await dbContext.SaveChangesAsync(cancellationToken);

        return batch.ToDto(
            razorpaySettings.Value.KeyId,
            razorpaySettings.Value.SimulateCollection,
            [.. excluded.Select(e => new PayoutExclusionDto { WorkerName = e.WorkerName, Reason = e.Reason })]);
    }
}

/// <summary>A worker a pay run could not include, and the reason.</summary>
internal sealed record PayoutExclusion(string WorkerName, string Reason);
