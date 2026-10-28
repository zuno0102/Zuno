using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.HiringPost.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Vacancies.Common;

/// <summary>Copies the form onto a vacancy. Shared by create and update so both write it the same way.</summary>
public static class VacancyWriter
{
    public static async Task ApplyAsync(
        Vacancy vacancy,
        VacancyFieldsCommand form,
        PlatformRules rules,
        IApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var hasFixedLength = await dbContext.VacancyJobTypes
            .Where(t => t.Id == form.JobTypeId)
            .Select(t => t.HasFixedLength)
            .FirstAsync(cancellationToken);

        // The job type decides whether a length means anything — a contract needs one, a permanent job
        // must not carry a stale one from before its type was changed.
        if (hasFixedLength && form.ContractMonths is null)
        {
            throw new DomainException("Say how many months this job runs for.");
        }

        vacancy.Title = form.Title.Trim();
        vacancy.Description = string.IsNullOrWhiteSpace(form.Description) ? null : form.Description.Trim();
        vacancy.VacancyJobTypeId = form.JobTypeId;
        vacancy.ServiceSubCategoryId = form.ServiceSubCategoryId;
        vacancy.Openings = form.Openings;
        vacancy.SalaryMin = form.SalaryMin;
        vacancy.SalaryMax = form.SalaryMax;
        vacancy.PayPeriod = form.PayPeriod;
        vacancy.WorkingDaysPerWeek = form.WorkingDaysPerWeek;
        vacancy.ShiftStart = form.ShiftStart;
        vacancy.ShiftEnd = form.ShiftEnd;
        vacancy.ContractMonths = hasFixedLength ? form.ContractMonths : null;
        vacancy.Location = string.IsNullOrWhiteSpace(form.Location) ? null : form.Location.Trim();

        await PlaceAsync(vacancy, form, rules, dbContext, cancellationToken);
        ReplaceRequirements(vacancy, form.Requirements, dbContext);
    }

    private static async Task PlaceAsync(
        Vacancy vacancy, VacancyFieldsCommand form, PlatformRules rules, IApplicationDbContext dbContext, CancellationToken cancellationToken)
    {
        if (form is not { Latitude: { } lat, Longitude: { } lon })
        {
            vacancy.Latitude = null;
            vacancy.Longitude = null;
            vacancy.DistrictId = null;
            vacancy.LocationPrecision = HiringPostLocationPrecision.None;
            return;
        }

        // The same district lookup hiring posts use, so both feeds agree where a place is.
        vacancy.Latitude = Math.Round(lat, 6);
        vacancy.Longitude = Math.Round(lon, 6);
        vacancy.LocationPrecision = HiringPostLocation.ParsePrecision(form.LocationPrecision);
        vacancy.DistrictId = await HiringPostLocation.NearestDistrictIdAsync(
            lat, lon, rules.DistrictMatchMaxDistanceKm, dbContext, cancellationToken);
    }

    /// <summary>
    /// Swaps the whole requirement set for the one on the form. Earlier applicants keep what they were
    /// asked — their answers carry their own copy of each prompt.
    /// </summary>
    private static void ReplaceRequirements(
        Vacancy vacancy,
        IReadOnlyList<VacancyRequirementInput> inputs,
        IApplicationDbContext dbContext)
    {
        foreach (var existing in vacancy.Requirements.ToList())
        {
            dbContext.VacancyRequirements.Remove(existing);
            vacancy.Requirements.Remove(existing);
        }

        short order = 0;
        foreach (var input in inputs)
        {
            // Added to the context, not only to the collection. The row carries its id from birth, and
            // EF treats a keyed entity reached through an already-tracked vacancy as one that exists —
            // so on an edit it would UPDATE a row that is not there.
            var requirement = new VacancyRequirement
            {
                VacancyId = vacancy.Id,
                Kind = input.Kind,
                Prompt = input.Prompt.Trim(),
                IsRequired = input.IsRequired,
                SortOrder = order++,
            };

            dbContext.VacancyRequirements.Add(requirement);
            vacancy.Requirements.Add(requirement);
        }
    }
}
