using FluentValidation;

namespace Zuno.Application.Modules.Business.Commands.SetBusinessUpiId;

public class SetBusinessUpiIdCommandValidator : AbstractValidator<SetBusinessUpiIdCommand>
{
    public SetBusinessUpiIdCommandValidator() => RuleFor(x => x.UpiId).BusinessUpiId();
}
