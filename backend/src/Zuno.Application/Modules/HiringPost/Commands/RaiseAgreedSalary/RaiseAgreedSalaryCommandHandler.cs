using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Application.Modules.HiringPost.Events;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.RaiseAgreedSalary;

/// <summary>
/// Raises the salary locked in for one confirmed worker — the "they stayed three extra hours"
/// case. Deliberately one-directional: the new amount must exceed the current one, and every
/// raise is appended to <see cref="HiringPostSalaryAdjustment"/> rather than overwriting history,
/// so the worker can always see what was promised, when, and why.
/// </summary>
public class RaiseAgreedSalaryCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<RaiseAgreedSalaryCommand, HiringPostDto>
{
    public async Task<HiringPostDto> Handle(RaiseAgreedSalaryCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var application = await dbContext.HiringPostApplications
            .Include(a => a.SalaryAdjustments)
            .Include(a => a.HiringPost).ThenInclude(p => p.BusinessOwnerProfile)
            .Include(a => a.HiringPost).ThenInclude(p => p.ServiceSubCategory)
            .Include(a => a.HiringPost).ThenInclude(p => p.Applications).ThenInclude(x => x.WorkerProfile).ThenInclude(wp => wp.User)
            .Include(a => a.HiringPost).ThenInclude(p => p.Applications).ThenInclude(x => x.SalaryAdjustments)
            .FirstOrDefaultAsync(a => a.Id == request.ApplicationId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(HiringPostApplication), request.ApplicationId);

        if (application.HiringPost.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This application does not belong to your business.");
        }

        // A run already sending money includes this worker at the old figure. A run the business
        // has not paid yet is fine: Pay all rebuilds it at the new total
        // (CreatePayoutBatchCommandHandler).
        var isBeingPaid = await dbContext.PayoutBatches.AnyAsync(
            b => b.BatchStatus == PayoutBatchStatus.Disbursing
                 && b.Items.Any(i => i.HiringPostApplicationId == application.Id),
            cancellationToken);

        if (isBeingPaid)
        {
            throw new DomainException(
                "This worker's payment is already being sent, so their salary can no longer be raised.");
        }

        dbContext.HiringPostSalaryAdjustments.Add(application.RaiseSalary(request.NewAmount, request.Reason));

        await dbContext.SaveChangesAsync(cancellationToken);

        // A raise the worker is never told about is a raise that does nothing — it was agreed to
        // acknowledge work already done, and the acknowledgement is the point.
        await publisher.Publish(
            new HiringPostSalaryRaisedEvent(
                application.HiringPostId,
                application.HiringPost.Applications
                    .First(a => a.Id == application.Id)
                    .WorkerProfile.UserId,
                application.HiringPost.Title,
                request.NewAmount,
                application.AgreedSalaryUnit ?? application.HiringPost.SalaryUnit,
                application.HiringPost.EventDate),
            cancellationToken);

        return application.HiringPost.ToDto();
    }
}
