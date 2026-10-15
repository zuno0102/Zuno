using FluentValidation;

namespace Zuno.Application.Modules.HiringPost.Commands.InviteWorkerToHiringPost;

public class InviteWorkerToHiringPostCommandValidator : AbstractValidator<InviteWorkerToHiringPostCommand>
{
    public InviteWorkerToHiringPostCommandValidator()
    {
        RuleFor(x => x.HiringPostId).NotEmpty();
        RuleFor(x => x.WorkerIdentifier).NotEmpty().MaximumLength(256);
    }
}
