using FluentValidation;

namespace Zuno.Application.Modules.Business.Commands.RemoveBusinessWorker;

public class RemoveBusinessWorkerCommandValidator : AbstractValidator<RemoveBusinessWorkerCommand>
{
    public RemoveBusinessWorkerCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}
