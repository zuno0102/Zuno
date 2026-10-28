using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Vacancies.Common;

namespace Zuno.Application.Modules.Vacancies.Commands.DeleteVacancy;

public class DeleteVacancyCommandHandler(
    ICurrentUserService currentUserService,
    IPrivateDocumentStore documentStore,
    IApplicationDbContext dbContext) : IRequestHandler<DeleteVacancyCommand>
{
    public async Task Handle(DeleteVacancyCommand request, CancellationToken cancellationToken)
    {
        var businessProfileId = await VacancyActor.BusinessProfileIdAsync(currentUserService, dbContext, cancellationToken);

        var vacancy = await VacancyActor.OwnedVacancyAsync(
            dbContext.Vacancies
                .Include(v => v.Requirements)
                .Include(v => v.Applications).ThenInclude(a => a.Answers),
            request.VacancyId,
            businessProfileId,
            cancellationToken);

        // Files first. If the database write below then fails the business simply deletes again, but
        // the other order could leave Aadhaar copies on disk behind a vacancy that reads as gone.
        documentStore.DeleteFolder(VacancyDocumentFolders.ForVacancy(vacancy.Id));

        foreach (var application in vacancy.Applications)
        {
            application.ErasePersonalData();
        }

        foreach (var requirement in vacancy.Requirements)
        {
            dbContext.VacancyRequirements.Remove(requirement);
        }

        // Soft-deleted by the save interceptor: the row stays as the record of the fee that was paid.
        dbContext.Vacancies.Remove(vacancy);
        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
