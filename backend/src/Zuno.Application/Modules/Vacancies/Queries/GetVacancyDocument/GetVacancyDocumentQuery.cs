using MediatR;

namespace Zuno.Application.Modules.Vacancies.Queries.GetVacancyDocument;

/// <summary>One applicant's uploaded document, for the business that owns the vacancy — nobody else.</summary>
public record GetVacancyDocumentQuery(Guid AnswerId) : IRequest<VacancyDocumentFile>;
