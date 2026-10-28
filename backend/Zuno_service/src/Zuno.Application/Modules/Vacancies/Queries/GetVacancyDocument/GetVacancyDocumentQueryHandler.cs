using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Vacancies.Queries.GetVacancyDocument;

public class GetVacancyDocumentQueryHandler(
    ICurrentUserService currentUserService,
    IPrivateDocumentStore documentStore,
    IApplicationDbContext dbContext) : IRequestHandler<GetVacancyDocumentQuery, VacancyDocumentFile>
{
    public async Task<VacancyDocumentFile> Handle(GetVacancyDocumentQuery request, CancellationToken cancellationToken)
    {
        var businessProfileId = await VacancyActor.BusinessProfileIdAsync(currentUserService, dbContext, cancellationToken);

        // Ownership is part of the lookup itself: another business's document is simply not found.
        var file = await dbContext.VacancyApplicationAnswers
            .AsNoTracking()
            .Where(a => a.Id == request.AnswerId
                && a.FileKey != null
                && a.VacancyApplication.Vacancy.BusinessOwnerProfileId == businessProfileId)
            .Select(a => new { a.FileKey, a.ContentType, a.FileName })
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw new EntityNotFoundException(nameof(VacancyApplicationAnswer), request.AnswerId);

        var content = documentStore.OpenRead(file.FileKey!)
            ?? throw new EntityNotFoundException(nameof(VacancyApplicationAnswer), request.AnswerId);

        return new VacancyDocumentFile(
            content,
            file.ContentType ?? "application/octet-stream",
            file.FileName ?? "document");
    }
}
