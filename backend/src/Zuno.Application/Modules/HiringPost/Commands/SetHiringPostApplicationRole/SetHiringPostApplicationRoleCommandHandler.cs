using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.Common;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Modules.HiringPost.Commands.SetHiringPostApplicationRole;

public class SetHiringPostApplicationRoleCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IApplicationDbContext dbContext) : IRequestHandler<SetHiringPostApplicationRoleCommand, HiringPostDto>
{
    public async Task<HiringPostDto> Handle(
        SetHiringPostApplicationRoleCommand request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        // The owner alone: a Lead can start and finish the work, so a Lead who could appoint another
        // would be handing on authority the owner never gave.
        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var application = await dbContext.LoadHiringPostApplicationAsync(
            dbContext.HiringPostApplications
                .Include(a => a.HiringPost).ThenInclude(p => p.BusinessOwnerProfile)
                .Include(a => a.HiringPost).ThenInclude(p => p.ServiceSubCategory)
                .Where(a => a.Id == request.ApplicationId),
            cancellationToken)
            ?? throw new EntityNotFoundException(nameof(HiringPostApplication), request.ApplicationId);

        var post = application.HiringPost;

        if (post.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This hiring post does not belong to your business.");
        }

        // A post for a customer order keeps its roles on the order, so they are set in one place.
        if (!HiringPostWorkControl.HoldsOwnRoles(post))
        {
            throw new DomainException(
                "This job is for a customer order. Set roles on the order's crew in Status management.");
        }

        if (!HiringPostWorkControl.CanHoldRoles(post))
        {
            throw new DomainException("This job is finished, so there is nothing left to lead.");
        }

        // Only somebody who has said yes. Until a worker answers they might still decline, and a
        // Lead who is not coming could otherwise be handed the power to start the job.
        if (application.ApplicationStatus != HiringPostApplicationStatus.Accepted)
        {
            throw new DomainException(application.ApplicationStatus switch
            {
                HiringPostApplicationStatus.Applied =>
                    "They have only applied. Confirm them, and give them a role once they accept.",
                HiringPostApplicationStatus.Confirmed =>
                    "They have not accepted this job yet. You can give them a role once they do.",
                _ => "That worker is not on this job, so they cannot be given a role on it.",
            });
        }

        // Blank takes the role away, so no separate "remove" call is needed.
        application.Role = JobRole.Canonical(request.Role);

        await dbContext.SaveChangesAsync(cancellationToken);

        return post.ToDto();
    }
}
