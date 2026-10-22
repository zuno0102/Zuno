using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
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

        var post = await dbContext.HiringPosts
            .Include(p => p.Applications).ThenInclude(a => a.WorkerProfile).ThenInclude(w => w.User)
            .Include(p => p.Applications).ThenInclude(a => a.WorkerProfile).ThenInclude(w => w.PayoutDetail)
            .FirstOrDefaultAsync(p => p.Id == request.HiringPostId, cancellationToken)
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
                         || b.BatchStatus == PayoutBatchStatus.Disbursing),
                cancellationToken);

        // Money is already moving; that run finishes as it is.
        if (existing is { BatchStatus: PayoutBatchStatus.Disbursing })
        {
            return existing.ToDto(razorpaySettings.Value.KeyId, razorpaySettings.Value.SimulateCollection);
        }

        var batch = new PayoutBatch
        {
            HiringPostId = post.Id,
            BusinessOwnerProfileId = businessProfile.Id,
            BatchStatus = PayoutBatchStatus.AwaitingCollection,
        };

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

            batch.Items.Add(new PayoutBatchItem
            {
                HiringPostApplicationId = application.Id,
                WorkerProfileId = application.WorkerProfileId,
                WorkerName = application.WorkerProfile.User is null
                    ? "Worker"
                    : $"{application.WorkerProfile.User.FirstName} {application.WorkerProfile.User.LastName}".Trim(),
                Amount = amount,
                PaymentStatus = PaymentStatus.Unpaid,
            });
        }

        if (batch.Items.Count == 0)
        {
            throw new DomainException("There is nobody left to pay on this job.");
        }

        batch.TotalAmount = batch.Items.Sum(i => i.Amount);

        // The client's figure is only ever a cross-check. Disagreeing with the server means the
        // two are looking at different crews, and paying either amount would be wrong.
        if (request.ExpectedTotal is { } claimed && claimed != batch.TotalAmount)
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

        return batch.ToDto(razorpaySettings.Value.KeyId, razorpaySettings.Value.SimulateCollection);
    }
}
