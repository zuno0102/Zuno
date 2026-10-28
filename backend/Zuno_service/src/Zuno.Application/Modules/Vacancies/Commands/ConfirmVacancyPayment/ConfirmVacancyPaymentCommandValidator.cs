using FluentValidation;

namespace Zuno.Application.Modules.Vacancies.Commands.ConfirmVacancyPayment;

public class ConfirmVacancyPaymentCommandValidator : AbstractValidator<ConfirmVacancyPaymentCommand>
{
    public ConfirmVacancyPaymentCommandValidator()
    {
        RuleFor(x => x.ProviderPaymentId).MaximumLength(100);
        RuleFor(x => x.Signature).MaximumLength(200);
    }
}
