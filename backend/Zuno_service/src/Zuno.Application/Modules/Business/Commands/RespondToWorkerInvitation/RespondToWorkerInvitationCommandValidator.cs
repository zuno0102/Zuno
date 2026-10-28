using FluentValidation;

namespace Zuno.Application.Modules.Business.Commands.RespondToWorkerInvitation;

public class RespondToWorkerInvitationCommandValidator : AbstractValidator<RespondToWorkerInvitationCommand>
{
    public RespondToWorkerInvitationCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}
