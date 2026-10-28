using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.DeleteHiringPost;

/// <summary>
/// Removes one of the business's own hiring posts, whatever stage it is at — a post created by
/// mistake is as worth deleting as a finished one, so this is not gated on the event date.
/// The delete is soft, so the applications and agreed-salary history behind it survive as a
/// record of anyone who was hired.
/// </summary>
public class DeleteHiringPostCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IApplicationDbContext dbContext) : IRequestHandler<DeleteHiringPostCommand>
{
    public async Task Handle(DeleteHiringPostCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var post = await dbContext.HiringPosts
            .FirstOrDefaultAsync(p => p.Id == request.HiringPostId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.HiringPost), request.HiringPostId);

        if (post.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This hiring post does not belong to your business.");
        }

        // Soft delete: the global query filter hides it from every read, while the applications
        // and salary history stay on record should a past hiring ever need to be evidenced.
        post.IsDeleted = true;

        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
