using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Application.Modules.HiringPost.Commands.RemoveUnfilledHiringPosts;

/// <summary>
/// Clears away posts whose time ran out with nobody ever hired. Nobody worked them and nothing is
/// owed, so there is nothing to keep showing. Soft delete, as DeleteHiringPost does: hidden from
/// every read, with the applications kept on record. One bounded batch per call, oldest first.
/// </summary>
public class RemoveUnfilledHiringPostsCommandHandler(
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext) : IRequestHandler<RemoveUnfilledHiringPostsCommand, int>
{
    public async Task<int> Handle(RemoveUnfilledHiringPostsCommand request, CancellationToken cancellationToken)
    {
        var posts = await dbContext.HiringPosts
            .Where(Domain.Entities.HiringPost.UnfilledAndOverAt(dateTimeProvider.UtcNow))
            .OrderBy(p => p.EventDate)
            .Take(request.BatchSize)
            .ToListAsync(cancellationToken);

        if (posts.Count == 0)
        {
            return 0;
        }

        foreach (var post in posts)
        {
            post.IsDeleted = true;
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        return posts.Count;
    }
}
