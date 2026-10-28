using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.Common;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.RaisePostCrewSalary;

/// <summary>
/// "Raise all": the same extra amount on every worker on this event who is still to be paid.
/// Workers already paid, or being paid, keep their wage. Saved in one go, so either the whole
/// crew is raised or nobody is.
/// </summary>
public class RaisePostCrewSalaryCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<RaisePostCrewSalaryCommand, HiringPostDto>
{
    public async Task<HiringPostDto> Handle(RaisePostCrewSalaryCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var post = await dbContext.LoadHiringPostAsync(
            dbContext.HiringPosts
                .Include(p => p.BusinessOwnerProfile)
                .Include(p => p.ServiceSubCategory)
                .Where(p => p.Id == request.HiringPostId),
            cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.HiringPost), request.HiringPostId);

        if (post.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This hiring post does not belong to your business.");
        }

        var raised = await CrewRaise.RaisePostHiresAsync(post, request.Increase, request.Reason, dbContext, cancellationToken);
        if (raised.Count == 0)
        {
            throw new DomainException("Nobody on this job is waiting to be paid, so there is no wage to raise.");
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await CrewRaise.NotifyAsync(post, raised, publisher, cancellationToken);

        return post.ToDto();
    }
}
