using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.HiringPost.Common;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Application.Modules.HiringPost.Events;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.ConfirmPayoutCollection;

/// <summary>
/// Funds a pay run and sends each worker their share.
/// </summary>
/// <remarks>
/// This is the whole point of the single-PIN design: the business authorises one debit, and every
/// worker is paid from it without another PIN. Beyond about five people the alternative — one PIN
/// each — stops being usable at all.
/// </remarks>
public class ConfirmPayoutCollectionCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessReputationService reputationService,
    IPayoutProvider payoutProvider,
    IApplicationDbContext dbContext,
    IPublisher publisher,
    IOptions<RazorpaySettings> razorpaySettings) : IRequestHandler<ConfirmPayoutCollectionCommand, PayoutBatchDto>
{
    public async Task<PayoutBatchDto> Handle(ConfirmPayoutCollectionCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var batch = await dbContext.PayoutBatches
            .Include(b => b.Items).ThenInclude(i => i.WorkerProfile).ThenInclude(w => w!.PayoutDetail)
            .Include(b => b.Items).ThenInclude(i => i.HiringPostApplication)
            .FirstOrDefaultAsync(b => b.Id == request.PayoutBatchId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(PayoutBatch), request.PayoutBatchId);

        if (batch.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This pay run does not belong to your business.");
        }

        // RULE 3 — the same collection confirmed twice funds the batch once. A retried request, a
        // duplicated webhook and a double-tapped button all land here, and only the first does
        // anything; the rest read back the state the first one produced.
        //
        // Unless a line failed. The money for it was collected on the first pass and is sitting
        // with us, so the way to pay it is to send it again — not to charge the business a second
        // time, which is what happened while this returned for every funded batch. Nothing is
        // re-collected here: the collection half is already done and skipped below.
        if (batch.FundedAt is not null)
        {
            var retryable = batch.Items
                .Where(i => i.PaymentStatus is PaymentStatus.Unpaid or PaymentStatus.Failed)
                .ToList();

            if (retryable.Count == 0)
            {
                return batch.ToDto();
            }

            var retriedAt = dateTimeProvider.UtcNow;

            foreach (var item in retryable)
            {
                await DisburseAsync(item, batch, retriedAt, cancellationToken);
            }

            await FinishAsync(batch, retryable, retriedAt, cancellationToken);
            return batch.ToDto();
        }

        if (batch.BatchStatus is PayoutBatchStatus.Completed or PayoutBatchStatus.Abandoned)
        {
            throw new DomainException("This pay run is already closed.");
        }

        var now = dateTimeProvider.UtcNow;

        // The payment is proved before anything is disbursed. The client tells us it paid, and
        // the client is the one party with a motive to lie — only a signature computed with the
        // key secret, which never leaves the server, settles it.
        if (batch.ProviderOrderId is { Length: > 0 } orderId)
        {
            if (!payoutProvider.VerifyPaymentSignature(
                    orderId, request.ProviderPaymentId, request.Signature ?? string.Empty))
            {
                throw new DomainException(
                    "This payment could not be verified with Razorpay. Nothing has been sent to "
                    + "the crew — try paying again.");
            }
        }
        else if (!razorpaySettings.Value.SimulateCollection)
        {
            // No order means collection was simulated when the run was opened. Honoured only while it
            // still is, so a run left over from a Development session can never be paid out for free.
            throw new DomainException(
                "This payment could not be verified. Nothing has been sent to the crew — open the pay run again.");
        }

        batch.ProviderPaymentId = request.ProviderPaymentId;
        batch.FundedAt = now;
        batch.BatchStatus = PayoutBatchStatus.Disbursing;

        var attempted = batch.Items
            .Where(i => i.PaymentStatus is PaymentStatus.Unpaid or PaymentStatus.Failed)
            .ToList();

        foreach (var item in attempted)
        {
            await DisburseAsync(item, batch, now, cancellationToken);
        }

        await FinishAsync(batch, attempted, now, cancellationToken);

        return batch.ToDto();
    }

    /// <summary>
    /// Closes a disbursement pass: settles the batch, the job and the business's standing, then
    /// tells the crew.
    /// </summary>
    /// <remarks>
    /// Shared by the first attempt and by a retry of a batch already funded, so a run that
    /// finally pays its last worker settles exactly as one that paid everybody first time. Split
    /// out when retries became reachable — duplicating it is how the two paths would start
    /// disagreeing about when a job is finished.
    /// </remarks>
    private async Task FinishAsync(
        PayoutBatch batch,
        IReadOnlyList<PayoutBatchItem> attempted,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        batch.BatchStatus = batch.AllItemsPaid
            ? PayoutBatchStatus.Completed
            : PayoutBatchStatus.PartiallyFailed;

        if (batch.AllItemsPaid)
        {
            batch.CompletedAt = now;
        }

        await SyncPostSettlementAsync(batch.HiringPostId, now, cancellationToken);

        await dbContext.SaveChangesAsync(cancellationToken);

        // Afterwards, so the count sees the wages that just landed. This is where "the entire
        // hiring is finished" is finally decided.
        await reputationService.RecalculateAndSaveAsync(
            batch.BusinessOwnerProfileId, cancellationToken);

        // Only this pass. Passing every item would congratulate workers paid in an earlier one
        // all over again each time a straggler is retried.
        await NotifyPaidWorkersAsync(batch, attempted, cancellationToken);
    }

    private async Task DisburseAsync(
        PayoutBatchItem item,
        PayoutBatch batch,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        // Already paid by another run, so this line is not sent. The idempotency key below is
        // built from this batch's own key and only stops a worker being paid twice *within* one
        // run — across runs the keys differ and the provider sees two unrelated instructions.
        //
        // That matters because a job can carry several funded batches for the same worker: a
        // failed run used to be replaced by a new one rather than retried, and each took the
        // money again. Retrying those now would send the wage once per batch.
        if (item.HiringPostApplication is { PaymentStatus: PaymentStatus.Paid })
        {
            item.PaymentStatus = PaymentStatus.Failed;
            item.FailureReason =
                "Already paid on another run, so this was not sent again. The amount collected "
                + "for it is owed back to you — contact support to have it returned.";
            return;
        }

        var payoutDetail = item.WorkerProfile?.PayoutDetail;

        if (payoutDetail is null || !payoutDetail.CanReceivePayouts)
        {
            item.PaymentStatus = PaymentStatus.Failed;
            item.FailureReason = payoutDetail is null || !payoutDetail.HasDestination
                ? "No UPI ID or bank account on file. Ask the worker to add one, then retry."
                : "Payout details are not verified yet. Retry once verification completes.";
            MirrorToSource(item, item.PaymentStatus, null);
            return;
        }

        var destination = new PayoutDestination(
            item.WorkerName,
            payoutDetail.UpiVpa,
            payoutDetail.AccountNumber,
            payoutDetail.IfscCode,
            payoutDetail.ProviderFundAccountId);

        // Keyed per item, so retrying a failed line can never pay a worker who already got theirs.
        var result = await payoutProvider.CreatePayoutAsync(
            destination,
            item.Amount,
            $"{batch.IdempotencyKey}-{item.Id:N}",
            $"Wages — {item.WorkerName}",
            cancellationToken);

        item.ProviderPayoutId = result.ProviderPayoutId;

        if (result.Accepted)
        {
            // Optimistic only as far as the provider taking the instruction. A real provider's
            // webhook is what moves this to Paid; the fake resolves immediately in Development.
            item.PaymentStatus = PaymentStatus.Paid;
            item.PaidAt = now;
            item.FailureReason = null;
            MirrorToSource(item, PaymentStatus.Paid, now);
        }
        else
        {
            item.PaymentStatus = PaymentStatus.Failed;
            item.FailureReason = result.FailureReason ?? "The payout provider rejected this payment.";
            MirrorToSource(item, PaymentStatus.Failed, null);
        }
    }

    /// <summary>
    /// Copies the outcome onto the application the item was created from. That row is what every
    /// other screen reads, so it has to move in step with the batch.
    /// </summary>
    private static void MirrorToSource(PayoutBatchItem item, PaymentStatus status, DateTimeOffset? paidAt)
    {
        if (item.HiringPostApplication is { } application)
        {
            application.PaymentStatus = status;
            application.PaidAt = paidAt;
        }
    }

    /// <summary>Stamps the job settled when the last worker is paid.</summary>
    /// <summary>
    /// Tells each worker the money is on its way.
    /// </summary>
    /// <remarks>
    /// Only the lines this call actually paid. A pay run can be retried after a partial failure,
    /// and a worker who was paid the first time must not be told twice — one notification per
    /// real-world event, which is why only <paramref name="attempted"/> is considered.
    ///
    /// A failed line gets nothing. There is no good notification for "we tried to pay you and it
    /// did not work"; the business is the one who has to act, and it is looking at the pay run.
    /// </remarks>
    private async Task NotifyPaidWorkersAsync(
        PayoutBatch batch,
        IReadOnlyCollection<PayoutBatchItem> attempted,
        CancellationToken cancellationToken)
    {
        var paid = attempted
            .Where(i => i.PaymentStatus == PaymentStatus.Paid && i.WorkerProfile is not null)
            .ToList();

        if (paid.Count == 0)
        {
            return;
        }

        // The job's own name, so "₹900 paid" says what it was for. Read here rather than carried
        // through the disbursement loop, which has no business knowing about wording.
        var postTitle = await dbContext.HiringPosts
            .Where(p => p.Id == batch.HiringPostId)
            .Select(p => p.Title)
            .FirstOrDefaultAsync(cancellationToken) ?? "your job";

        foreach (var item in paid)
        {
            await publisher.Publish(
                new WagesPaidEvent(
                    batch.HiringPostId,
                    item.WorkerProfile!.UserId,
                    postTitle,
                    item.Amount),
                cancellationToken);
        }
    }

    private async Task SyncPostSettlementAsync(
        Guid hiringPostId,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        var post = await dbContext.LoadHiringPostAsync(
            dbContext.HiringPosts.Where(p => p.Id == hiringPostId),
            cancellationToken,
            HiringPostCrewDetail.ApplicationsOnly);

        if (post is null)
        {
            return;
        }

        post.SyncSettlement(now);
    }
}
