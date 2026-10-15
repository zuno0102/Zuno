using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.Events;
using Zuno.Application.Modules.Notifications.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.RespondToPayment;

/// <summary>
/// Records whether a worker actually received their wages, and settles or disputes the job on
/// their answer.
/// </summary>
public class RespondToPaymentCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBusinessReputationService reputationService,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<RespondToPaymentCommand, Unit>
{
    public async Task<Unit> Handle(RespondToPaymentCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var application = await dbContext.HiringPostApplications
            .Include(a => a.WorkerProfile)
            .Include(a => a.HiringPost).ThenInclude(p => p.Applications)
            .FirstOrDefaultAsync(a => a.Id == request.HiringPostApplicationId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(HiringPostApplication), request.HiringPostApplicationId);

        if (application.WorkerProfile.UserId != userId)
        {
            throw new UnauthorizedAccessException("This job does not belong to you.");
        }

        if (application.PaymentStatus is PaymentStatus.Unpaid)
        {
            throw new DomainException("Your employer has not sent this payment yet.");
        }

        var now = dateTimeProvider.UtcNow;

        if (request.Received)
        {
            application.PaymentStatus = PaymentStatus.Paid;
            application.PaidAt ??= now;
            application.DisputeReason = null;
            application.DisputedAt = null;
        }
        else
        {
            application.PaymentStatus = PaymentStatus.Disputed;
            application.DisputeReason = string.IsNullOrWhiteSpace(request.DisputeReason)
                ? "The worker reports this payment never arrived."
                : request.DisputeReason.Trim();
            application.DisputedAt = now;
        }

        application.HiringPost.SyncSettlement(now);

        await dbContext.SaveChangesAsync(cancellationToken);

        // A dispute has to reach the business's standing immediately — that is the entire point of
        // recording it. Confirming has to as well, since it may be the payment that completes the
        // job. After the save, because the standing is counted in the database and cannot see a
        // payment that is still only in the change tracker.
        await reputationService.RecalculateAndSaveAsync(
            application.HiringPost.BusinessOwnerProfileId, cancellationToken);

        if (application.PaymentStatus == PaymentStatus.Disputed)
        {
            // Projected rather than read off the graph above: that one was loaded for the
            // settlement rules and brings neither the owner's user id nor the worker's name.
            var dispute = await dbContext.HiringPostApplications
                .Where(a => a.Id == application.Id)
                .Select(a => new
                {
                    BusinessUserId = a.HiringPost.BusinessOwnerProfile.UserId,
                    a.WorkerProfile.User.FirstName,
                    a.WorkerProfile.User.LastName,
                })
                .FirstAsync(cancellationToken);

            // The one notification in this app about money going missing. It always goes out —
            // the business cannot answer a dispute it has not been told about.
            await publisher.Publish(
                new WagesDisputedEvent(
                    application.HiringPostId,
                    dispute.BusinessUserId,
                    NotificationText.Person(dispute.FirstName, dispute.LastName),
                    application.AgreedSalaryAmount ?? 0m,
                    application.DisputeReason ?? string.Empty),
                cancellationToken);
        }

        return Unit.Value;
    }
}
