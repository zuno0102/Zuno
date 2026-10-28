using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Domain.Common;

namespace Zuno.Application.Modules.Vacancies.Common;

/// <summary>The form's rules, shared by create and update.</summary>
public abstract class VacancyFieldsValidator<T> : AbstractValidator<T>
    where T : VacancyFieldsCommand
{
    protected VacancyFieldsValidator(
        IApplicationDbContext dbContext, IOptions<VacancySettings> settings, IPlatformSettings platformSettings)
    {
        RuleFor(x => x.Title).NotEmpty().MaximumLength(VacancyFieldLimits.MaxTitleLength);
        RuleFor(x => x.Description).MaximumLength(VacancyFieldLimits.MaxDescriptionLength);
        RuleFor(x => x.Location).MaximumLength(VacancyFieldLimits.MaxLocationLength);

        RuleFor(x => x.JobTypeId)
            .MustAsync((id, ct) => dbContext.VacancyJobTypes.AnyAsync(t => t.Id == id && t.IsActive, ct))
            .WithMessage("Choose a job type from the list.");

        RuleFor(x => x.ServiceSubCategoryId)
            .MustAsync((id, ct) => dbContext.ServiceSubCategories.AnyAsync(s => s.Id == id && s.IsActive, ct))
            .When(x => x.ServiceSubCategoryId.HasValue)
            .WithMessage("That kind of work is not one Zuno lists.");

        RuleFor(x => x.Openings)
            .Must(n => n >= 1 && n <= platformSettings.Current.VacancyMaxOpenings)
            .WithMessage(_ => $"Openings must be between 1 and {platformSettings.Current.VacancyMaxOpenings}.");
        RuleFor(x => x.SalaryMin)
            .GreaterThan(0).WithMessage("Salary must be greater than 0.")
            .LessThanOrEqualTo(MoneyLimits.MaxAmount);
        RuleFor(x => x.SalaryMax)
            .GreaterThanOrEqualTo(x => x.SalaryMin).WithMessage("The top of the salary range cannot be below the bottom.")
            .LessThanOrEqualTo(MoneyLimits.MaxAmount)
            .When(x => x.SalaryMax.HasValue);
        RuleFor(x => x.PayPeriod).IsInEnum();
        RuleFor(x => x.WorkingDaysPerWeek).InclusiveBetween((short)1, (short)7);
        RuleFor(x => x)
            .Must(x => x.ShiftStart.HasValue == x.ShiftEnd.HasValue)
            .WithMessage("Give both the shift start and end time, or neither.");
        RuleFor(x => x.ContractMonths)
            .Must(m => m >= 1 && m <= platformSettings.Current.VacancyMaxContractMonths)
            .When(x => x.ContractMonths.HasValue)
            .WithMessage(_ => $"A contract must run between 1 and {platformSettings.Current.VacancyMaxContractMonths} months.");

        RuleFor(x => x.Latitude).InclusiveBetween(-90m, 90m);
        RuleFor(x => x.Longitude).InclusiveBetween(-180m, 180m);
        RuleFor(x => x)
            .Must(x => x.Latitude.HasValue == x.Longitude.HasValue)
            .WithMessage("Send both latitude and longitude, or neither.");

        RuleFor(x => x.Requirements)
            .Must(r => r.Count <= settings.Value.MaxRequirements)
            .WithMessage($"Add at most {settings.Value.MaxRequirements} fields.");
        RuleFor(x => x.Requirements)
            .Must(r => r
                .GroupBy(i => i.Prompt.Trim(), StringComparer.OrdinalIgnoreCase)
                .All(g => g.Count() == 1))
            .WithMessage("Each field needs a different name.");

        RuleForEach(x => x.Requirements).ChildRules(r =>
        {
            r.RuleFor(i => i.Kind).IsInEnum();
            r.RuleFor(i => i.Prompt)
                .NotEmpty().WithMessage("Give every field a name.")
                .MaximumLength(VacancyFieldLimits.MaxPromptLength);
        });
    }
}
