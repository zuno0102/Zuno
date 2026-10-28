using MediatR;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Commands.ApplyToVacancy;

/// <summary>A worker applying, with an answer or a file for each of the vacancy's requirements.</summary>
public class ApplyToVacancyCommand : IRequest<VacancyDto>
{
    public Guid VacancyId { get; set; }

    public List<VacancyAnswerUpload> Answers { get; set; } = [];
}
