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

        // Raising is allowed both for a worker who has accepted and for one still weighing an
        // offer — sweetening a pending offer is legitimate; a declined one is not.
        if (application.ApplicationStatus is not (HiringPostApplicationStatus.Accepted
            or HiringPostApplicationStatus.Confirmed))
        {
            throw new DomainException(
                "Only a worker who has accepted, or who has an offer pending, can have their salary adjusted.");
        }

        var currentAmount = application.AgreedSalaryAmount
            ?? throw new DomainException("This application has no agreed salary recorded.");

        if (request.NewAmount <= currentAmount)
        {
            throw new DomainException(
                $"The agreed salary can only be increased. It is currently {currentAmount:0.##}, " +
                $"so the new amount must be greater than that.");
        }

        dbContext.HiringPostSalaryAdjustments.Add(new HiringPostSalaryAdjustment
        {
            HiringPostApplicationId = application.Id,
            HiringPostApplication = application,
            PreviousAmount = currentAmount,
            NewAmount = request.NewAmount,
            Reason = request.Reason,
        });

        application.AgreedSalaryAmount = request.NewAmount;

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
