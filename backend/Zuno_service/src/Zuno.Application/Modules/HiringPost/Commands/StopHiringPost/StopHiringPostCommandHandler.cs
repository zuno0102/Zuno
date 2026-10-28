using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.Common;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.StopHiringPost;

/// <summary>
/// The business will manage with the crew it has. The vacancy closes for good: the post leaves
/// every worker's feed and no outstanding application or offer can be acted on any more. The
/// job itself carries on — the crew still starts, finishes and is paid as before.
/// </summary>
public class StopHiringPostCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IApplicationDbContext dbContext) : IRequestHandler<StopHiringPostCommand, HiringPostDto>
{
    public async Task<HiringPostDto> Handle(StopHiringPostCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var post = await dbContext.LoadHiringPostAsync(
            dbContext.HiringPosts
                .Include(p => p.BusinessOwnerProfile)
                .Where(p => p.Id == request.HiringPostId),
            cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.HiringPost), request.HiringPostId);

        if (post.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This hiring post does not belong to your business.");
        }

        if (post.HiringStoppedAt is not null)
        {
            throw new DomainException("Hiring for this job has already been stopped.");
        }

        post.HiringStoppedAt = dateTimeProvider.UtcNow;
        post.HiringPostStatus = HiringPostStatus.Closed;

        await dbContext.SaveChangesAsync(cancellationToken);

        return post.ToDto();
    }
}
