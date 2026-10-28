using FluentValidation;

namespace Zuno.Application.Modules.Vacancies.Queries.GetOpenVacancies;

public class GetOpenVacanciesQueryValidator : AbstractValidator<GetOpenVacanciesQuery>
{
    public GetOpenVacanciesQueryValidator()
    {
        RuleFor(x => x.Latitude).InclusiveBetween(-90, 90);
        RuleFor(x => x.Longitude).InclusiveBetween(-180, 180);
        RuleFor(x => x.RadiusKm).InclusiveBetween(1, 500);
        RuleFor(x => x.DistrictIds).Must(d => d is null || d.Count <= 50).WithMessage("Choose at most 50 districts.");
    }
}
