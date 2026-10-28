using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Application.Modules.Vacancies.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Vacancies.Commands.SetVacancyApplicationStatus;

public class SetVacancyApplicationStatusCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    INotificationSender notificationSender,
    IPrivateDocumentStore documentStore,
    IApplicationDbContext dbContext) : IRequestHandler<SetVacancyApplicationStatusCommand, VacancyApplicationDto>
{
    public async Task<VacancyApplicationDto> Handle(
        SetVacancyApplicationStatusCommand request, CancellationToken cancellationToken)
    {
        var businessProfileId = await VacancyActor.BusinessProfileIdAsync(currentUserService, dbContext, cancellationToken);

        var application = await dbContext.VacancyApplications
            .Include(a => a.Vacancy)
            .Include(a => a.WorkerProfile)
            .Include(a => a.Answers)
            .FirstOrDefaultAsync(
                a => a.Id == request.ApplicationId && a.Vacancy.BusinessOwnerProfileId == businessProfileId,
                cancellationToken)
            ?? throw new EntityNotFoundException(nameof(VacancyApplication), request.ApplicationId);

        if (request.Note is not null)
        {
            if (application.ApplicationStatus == VacancyApplicationStatus.Rejected)
            {
                throw new DomainException("This applicant was rejected, so there is nothing to add a note to.");
            }

            application.BusinessNote = string.IsNullOrWhiteSpace(request.Note) ? null : request.Note.Trim();
        }

        var changed = request.Status is { } decision
            && application.Decide(decision, dateTimeProvider.UtcNow);

        // Files first, as on delete: a failed save leaves a rejection to repeat, never documents behind.
        if (changed && application.ApplicationStatus == VacancyApplicationStatus.Rejected)
        {
            documentStore.DeleteFolder(VacancyDocumentFolders.ForApplication(application.VacancyId, application.Id));
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        if (changed && WorkerMessage(application.ApplicationStatus, application.Vacancy) is { } message)
        {
            await notificationSender.NotifyAsync(
                application.WorkerProfile.UserId,
                NotificationKind.VacancyApplicationUpdated,
                message.Title,
                message.Body,
                NotificationTarget.MyVacancyApplications,
                Guid.Empty,
                cancellationToken);
        }

        return await dbContext.VacancyApplications
            .AsNoTracking()
            .Where(a => a.Id == application.Id)
            .Select(VacancyProjections.ToApplicationDto)
            .FirstAsync(cancellationToken);
    }

    private static (string Title, string Body)? WorkerMessage(VacancyApplicationStatus status, Vacancy vacancy) =>
        status switch
        {
            VacancyApplicationStatus.Shortlisted => ("You are shortlisted", $"You are shortlisted for {vacancy.Title}. Expect a call."),
            VacancyApplicationStatus.Hired => ("You got the job", $"You have been hired for {vacancy.Title}."),
            VacancyApplicationStatus.Rejected => ("Application update", $"Your application for {vacancy.Title} was rejected."),
            _ => null,
        };
}
