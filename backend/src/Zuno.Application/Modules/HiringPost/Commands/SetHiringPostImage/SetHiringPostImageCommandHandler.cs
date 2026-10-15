using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.SetHiringPostImage;

public class SetHiringPostImageCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IFileStorageService fileStorageService,
    IApplicationDbContext dbContext) : IRequestHandler<SetHiringPostImageCommand, HiringPostDto>
{
    public async Task<HiringPostDto> Handle(SetHiringPostImageCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var post = await dbContext.HiringPosts
            .Include(p => p.BusinessOwnerProfile)
            .Include(p => p.Applications).ThenInclude(a => a.WorkerProfile).ThenInclude(wp => wp.User)
            .Include(p => p.Applications).ThenInclude(a => a.SalaryAdjustments)
            .FirstOrDefaultAsync(p => p.Id == request.HiringPostId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.HiringPost), request.HiringPostId);

        if (post.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This post does not belong to your business.");
        }

        // Written only now. Saving clears the post's existing picture first, so doing it before the
        // check above let one business delete another's by guessing a post id.
        post.ImageUrl = await fileStorageService.SaveHiringPostImageAsync(
            post.Id, request.Content, request.FileExtension, cancellationToken);

        await dbContext.SaveChangesAsync(cancellationToken);

        return post.ToDto();
    }
}
