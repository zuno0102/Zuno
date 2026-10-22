using MediatR;

namespace Zuno.Application.Modules.HiringPost.Commands.RemoveUnfilledHiringPosts;

/// <summary>Soft-deletes up to <see cref="BatchSize"/> posts that ended with nobody hired.</summary>
public class RemoveUnfilledHiringPostsCommand : IRequest<int>
{
    public int BatchSize { get; set; }
}
