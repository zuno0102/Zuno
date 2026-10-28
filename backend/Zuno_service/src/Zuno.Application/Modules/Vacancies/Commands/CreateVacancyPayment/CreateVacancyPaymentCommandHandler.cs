using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Application.Modules.Vacancies.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Vacancies.Commands.CreateVacancyPayment;

public class CreateVacancyPaymentCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IPayoutProvider paymentProvider,
    IOptions<RazorpaySettings> razorpaySettings,
    IApplicationDbContext dbContext) : IRequestHandler<CreateVacancyPaymentCommand, VacancyPaymentDto>
{
    public async Task<VacancyPaymentDto> Handle(CreateVacancyPaymentCommand request, CancellationToken cancellationToken)
    {
        var businessProfileId = await VacancyActor.BusinessProfileIdAsync(currentUserService, dbContext, cancellationToken);
        var vacancy = await VacancyActor.OwnedVacancyAsync(
            dbContext.Vacancies, request.VacancyId, businessProfileId, cancellationToken);

        var plan = await ResolvePlanAsync(request.FeePlanId ?? vacancy.VacancyFeePlanId, cancellationToken);
        var now = dateTimeProvider.UtcNow;

        vacancy.PriceWith(plan);

        var result = new VacancyPaymentDto
        {
            VacancyId = vacancy.Id,
            PlanName = plan.Name,
            Amount = plan.Amount,
            ListingDays = plan.ListingDays,
        };

        // A free plan has nothing to collect, so the listing is settled here and goes live at once.
        if (plan.Amount == 0m)
        {
            vacancy.RecordPayment(null, now);
            await dbContext.SaveChangesAsync(cancellationToken);

            result.NothingToCollect = true;
            result.Vacancy = await VacancyReader.GetAsync(dbContext, vacancy.Id, null, now, cancellationToken);
            return result;
        }

        // An order already raised for these terms is handed back, so a second tap never charges twice.
        if (vacancy.PendingOrderId is not { Length: > 0 })
        {
            var order = await paymentProvider.CreateCollectionOrderAsync(
                plan.Amount,
                vacancy.NextPaymentKey,
                $"Job listing: {vacancy.Title}",
                cancellationToken);

            // Empty when collection is simulated. Still stored, so confirming knows an order was raised.
            vacancy.PendingOrderId = order.ProviderOrderId;
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        result.ProviderOrderId = vacancy.PendingOrderId is { Length: > 0 } id ? id : null;
        result.RazorpayKeyId = result.ProviderOrderId is null ? null : razorpaySettings.Value.KeyId;
        result.NothingToCollect = result.ProviderOrderId is null;
        return result;
    }

    private async Task<VacancyFeePlan> ResolvePlanAsync(Guid? planId, CancellationToken cancellationToken)
    {
        var active = dbContext.VacancyFeePlans.AsNoTracking().Where(p => p.IsActive);

        var plan = planId is { } id
            ? await active.FirstOrDefaultAsync(p => p.Id == id, cancellationToken)
            : null;

        // A vacancy's earlier plan may have been retired since; it renews on the current default.
        plan ??= await active.OrderBy(p => p.SortOrder).FirstOrDefaultAsync(cancellationToken);

        return plan ?? throw new DomainException("Job listings are not available right now. Please try again later.");
    }
}
