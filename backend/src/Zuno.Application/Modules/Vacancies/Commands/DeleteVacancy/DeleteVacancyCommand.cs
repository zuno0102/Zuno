using MediatR;

namespace Zuno.Application.Modules.Vacancies.Commands.DeleteVacancy;

/// <summary>
/// Deletes a vacancy at once, in any state. Every applicant's documents and answers go with it; the
/// fee already paid is not refunded.
/// </summary>
public record DeleteVacancyCommand(Guid VacancyId) : IRequest;
