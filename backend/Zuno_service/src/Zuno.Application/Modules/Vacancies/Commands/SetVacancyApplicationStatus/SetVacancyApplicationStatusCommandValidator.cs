using FluentValidation;
using Zuno.Domain.Entities;

namespace Zuno.Application.Modules.Vacancies.Commands.SetVacancyApplicationStatus;

public class SetVacancyApplicationStatusCommandValidator : AbstractValidator<SetVacancyApplicationStatusCommand>
{
    public SetVacancyApplicationStatusCommandValidator()
    {
        RuleFor(x => x.Status)
            .Must(s => s is null || VacancyApplication.IsDecision(s.Value))
            .WithMessage("Choose Shortlist, Hire or Reject.");
        RuleFor(x => x)
            .Must(x => x.Status is not null || x.Note is not null)
            .WithMessage("Nothing to change.");
        RuleFor(x => x.Note).MaximumLength(500);
    }
}
