using FluentValidation;

namespace Zuno.Application.Modules.Business.Commands.InviteWorker;

public class InviteWorkerCommandValidator : AbstractValidator<InviteWorkerCommand>
{
    public InviteWorkerCommandValidator()
    {
        RuleFor(x => x.WorkerIdentifier).NotEmpty().MaximumLength(256);
    }
}
