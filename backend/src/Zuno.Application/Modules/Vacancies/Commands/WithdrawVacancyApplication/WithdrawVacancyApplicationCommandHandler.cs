using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Vacancies.Commands.WithdrawVacancyApplication;

public class WithdrawVacancyApplicationCommandHandler(
    ICurrentUserService currentUserService,
    IPrivateDocumentStore documentStore,
    IApplicationDbContext dbContext) : IRequestHandler<WithdrawVacancyApplicationCommand>
{
    public async Task Handle(WithdrawVacancyApplicationCommand request, CancellationToken cancellationToken)
    {
        var workerProfileId = await VacancyActor.WorkerProfileIdAsync(currentUserService, dbContext, cancellationToken);

        var application = await dbContext.VacancyApplications
            .Include(a => a.Answers)
            .FirstOrDefaultAsync(
                a => a.Id == request.ApplicationId && a.WorkerProfileId == workerProfileId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(VacancyApplication), request.ApplicationId);

        // Once hired the record is the business's too; leaving the job is a conversation, not a button.
        if (application.ApplicationStatus == VacancyApplicationStatus.Hired)
        {
            throw new DomainException("You have been hired for this job, so the application cannot be withdrawn.");
        }

        documentStore.DeleteFolder(VacancyDocumentFolders.ForApplication(application.VacancyId, application.Id));
        application.ErasePersonalData();

        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
