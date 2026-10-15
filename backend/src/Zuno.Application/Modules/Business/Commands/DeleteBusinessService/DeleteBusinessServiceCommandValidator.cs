using FluentValidation;

namespace Zuno.Application.Modules.Business.Commands.DeleteBusinessService;

public class DeleteBusinessServiceCommandValidator : AbstractValidator<DeleteBusinessServiceCommand>
{
    public DeleteBusinessServiceCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}
