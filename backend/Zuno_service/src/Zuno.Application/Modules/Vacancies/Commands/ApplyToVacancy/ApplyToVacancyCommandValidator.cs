using FluentValidation;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Settings;

namespace Zuno.Application.Modules.Vacancies.Commands.ApplyToVacancy;

public class ApplyToVacancyCommandValidator : AbstractValidator<ApplyToVacancyCommand>
{
    public const int MaxAnswerLength = 1000;

    public ApplyToVacancyCommandValidator(IOptions<VacancySettings> settings)
    {
        RuleFor(x => x.Answers)
            .Must(a => a.Count <= settings.Value.MaxRequirements)
            .WithMessage("Too many answers for one application.");
        RuleFor(x => x.Answers)
            .Must(a => a.Select(i => i.RequirementId).Distinct().Count() == a.Count)
            .WithMessage("Each requirement can be answered only once.");
        RuleFor(x => x.Answers)
            .Must(a => a.Sum(i => i.Length) <= settings.Value.MaxApplicationUploadBytes)
            .WithMessage($"Your files add up to more than {settings.Value.MaxApplicationUploadBytes / (1024 * 1024)}MB.");
        RuleForEach(x => x.Answers).ChildRules(a =>
            a.RuleFor(i => i.Text).MaximumLength(MaxAnswerLength));
    }
}
