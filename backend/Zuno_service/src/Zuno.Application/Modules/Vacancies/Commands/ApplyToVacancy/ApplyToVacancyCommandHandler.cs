using System.Globalization;
using System.Text.RegularExpressions;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Application.Common;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Application.Modules.Vacancies.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Vacancies.Commands.ApplyToVacancy;

public partial class ApplyToVacancyCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IPrivateDocumentStore documentStore,
    INotificationSender notificationSender,
    IOptions<VacancySettings> settings,
    IApplicationDbContext dbContext) : IRequestHandler<ApplyToVacancyCommand, VacancyDto>
{
    public async Task<VacancyDto> Handle(ApplyToVacancyCommand request, CancellationToken cancellationToken)
    {
        var workerProfileId = await VacancyActor.WorkerProfileIdAsync(currentUserService, dbContext, cancellationToken);
        var now = dateTimeProvider.UtcNow;

        var vacancy = await dbContext.Vacancies
            .AsNoTracking()
            .Include(v => v.Requirements)
            .Include(v => v.BusinessOwnerProfile)
            .FirstOrDefaultAsync(v => v.Id == request.VacancyId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Vacancy), request.VacancyId);

        if (!vacancy.IsLiveAt(now))
        {
            throw new DomainException("This job is no longer taking applications.");
        }

        if (await AlreadyAppliedAsync(vacancy.Id, workerProfileId, cancellationToken))
        {
            throw new DomainException("You have already applied for this job.");
        }

        var application = new VacancyApplication
        {
            VacancyId = vacancy.Id,
            WorkerProfileId = workerProfileId,
            ApplicationStatus = VacancyApplicationStatus.Applied,
            StatusChangedAt = now,
        };

        var folder = VacancyDocumentFolders.ForApplication(vacancy.Id, application.Id);

        try
        {
            await AddAnswersAsync(application, vacancy, request.Answers, folder, cancellationToken);

            dbContext.VacancyApplications.Add(application);
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DomainException)
        {
            // Nothing is kept from an application that did not go through — least of all ID documents.
            documentStore.DeleteFolder(folder);
            throw;
        }
        catch (DbUpdateException)
        {
            documentStore.DeleteFolder(folder);

            // The unique index caught two Apply taps racing past the check above. Any other failure
            // is not that, and is left to surface as what it is.
            if (await AlreadyAppliedAsync(vacancy.Id, workerProfileId, cancellationToken))
            {
                throw new DomainException("You have already applied for this job.");
            }

            throw;
        }

        await notificationSender.NotifyAsync(
            vacancy.BusinessOwnerProfile.UserId,
            NotificationKind.VacancyApplicationReceived,
            "New applicant",
            $"Someone applied for {vacancy.Title}.",
            NotificationTarget.VacancyApplicants,
            vacancy.Id,
            cancellationToken);

        return await VacancyReader.GetAsync(dbContext, vacancy.Id, workerProfileId, now, cancellationToken);
    }

    private Task<bool> AlreadyAppliedAsync(Guid vacancyId, Guid workerProfileId, CancellationToken cancellationToken) =>
        dbContext.VacancyApplications.AnyAsync(
            a => a.VacancyId == vacancyId && a.WorkerProfileId == workerProfileId, cancellationToken);

    private async Task AddAnswersAsync(
        VacancyApplication application,
        Vacancy vacancy,
        IReadOnlyCollection<VacancyAnswerUpload> uploads,
        string folder,
        CancellationToken cancellationToken)
    {
        var byRequirement = uploads.ToDictionary(u => u.RequirementId);

        if (byRequirement.Keys.Any(id => vacancy.Requirements.All(r => r.Id != id)))
        {
            throw new DomainException("This job's form has changed. Reload it and apply again.");
        }


        foreach (var requirement in vacancy.Requirements.OrderBy(r => r.SortOrder))
        {
            byRequirement.TryGetValue(requirement.Id, out var upload);

            var answer = requirement.Kind == VacancyRequirementKind.File
                ? await SaveFileAsync(requirement, upload, folder, cancellationToken)
                : AnswerField(requirement, upload?.Text);

            if (answer is not null)
            {
                answer.SortOrder = requirement.SortOrder;
                application.Answers.Add(answer);
            }
        }
    }

    /// <summary>A typed answer, checked against the kind of field it is for.</summary>
    private static VacancyApplicationAnswer? AnswerField(VacancyRequirement requirement, string? raw)
    {
        var text = raw?.Trim();

        if (string.IsNullOrEmpty(text))
        {
            return requirement.IsRequired
                ? throw new DomainException($"Please answer: {requirement.Prompt}")
                : null;
        }

        var value = requirement.Kind switch
        {
            VacancyRequirementKind.Number => decimal.TryParse(text, NumberStyles.Number, CultureInfo.InvariantCulture, out var number)
                ? number.ToString(CultureInfo.InvariantCulture)
                : throw new DomainException($"{requirement.Prompt} must be a number."),
            VacancyRequirementKind.YesNo => text.Equals("yes", StringComparison.OrdinalIgnoreCase) ? "Yes"
                : text.Equals("no", StringComparison.OrdinalIgnoreCase) ? "No"
                : throw new DomainException($"Answer Yes or No: {requirement.Prompt}"),
            _ => text,
        };

        return new VacancyApplicationAnswer
        {
            VacancyRequirementId = requirement.Id,
            Kind = requirement.Kind,
            Prompt = requirement.Prompt,
            AnswerText = value,
        };
    }

    private async Task<VacancyApplicationAnswer?> SaveFileAsync(
        VacancyRequirement requirement,
        VacancyAnswerUpload? upload,
        string folder,
        CancellationToken cancellationToken)
    {
        var rules = settings.Value;

        if (upload?.Content is not { } content || upload.Length == 0)
        {
            return requirement.IsRequired
                ? throw new DomainException($"Please upload: {requirement.Prompt}")
                : null;
        }

        if (upload.Length > rules.MaxFileSizeBytes)
        {
            throw new DomainException(
                $"{requirement.Prompt} must be {rules.MaxFileSizeBytes / (1024 * 1024)}MB or smaller.");
        }

        // Judged by the bytes, not the name or type the phone sent: a renamed script is still refused.
        var header = new byte[FileSignature.HeaderLength];
        var read = await content.ReadAtLeastAsync(header, header.Length, throwOnEndOfStream: false, cancellationToken);
        content.Position = 0;

        var detected = FileSignature.Detect(header.AsSpan(0, read));

        if (detected is null || !detected.Aliases.Any(rules.AcceptsFile))
        {
            throw new DomainException(
                $"{requirement.Prompt} must be one of these file types: {string.Join(", ", rules.AllowedFileExtensions)}.");
        }

        var key = await documentStore.SaveAsync(folder, content, detected.Extension, cancellationToken);

        return new VacancyApplicationAnswer
        {
            VacancyRequirementId = requirement.Id,
            Kind = VacancyRequirementKind.File,
            Prompt = requirement.Prompt,
            FileKey = key,
            FileName = $"{SafeFileStem(requirement.Prompt)}.{detected.Extension}",
            ContentType = detected.ContentType,
            FileSizeBytes = upload.Length,
        };
    }

    /// <summary>
    /// The field's label as a download name — "Aadhaar.pdf". Only plain characters survive, because the
    /// label is the business's free text and ends up in a Content-Disposition header.
    /// </summary>
    private static string SafeFileStem(string label)
    {
        var stem = UnsafeFileNameCharacters().Replace(label, string.Empty).Trim();
        return stem.Length == 0 ? "document" : stem[..Math.Min(stem.Length, 60)];
    }

    [GeneratedRegex(@"[^A-Za-z0-9 _\-]")]
    private static partial Regex UnsafeFileNameCharacters();
}
