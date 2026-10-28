using MediatR;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Application.Modules.Vacancies.DTOs;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Vacancies.Commands.ConfirmVacancyPayment;

public class ConfirmVacancyPaymentCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IPayoutProvider paymentProvider,
    IOptions<RazorpaySettings> razorpaySettings,
    IApplicationDbContext dbContext) : IRequestHandler<ConfirmVacancyPaymentCommand, VacancyDto>
{
    public async Task<VacancyDto> Handle(ConfirmVacancyPaymentCommand request, CancellationToken cancellationToken)
    {
        var businessProfileId = await VacancyActor.BusinessProfileIdAsync(currentUserService, dbContext, cancellationToken);
        var vacancy = await VacancyActor.OwnedVacancyAsync(
            dbContext.Vacancies, request.VacancyId, businessProfileId, cancellationToken);

        var now = dateTimeProvider.UtcNow;

        // The same payment confirmed twice — a retry, a double tap — extends the listing once.
        if (vacancy.PendingOrderId is null
            && request.ProviderPaymentId is { Length: > 0 } repeated
            && repeated == vacancy.LastPaymentId)
        {
            return await VacancyReader.GetAsync(dbContext, vacancy.Id, null, now, cancellationToken);
        }

        switch (vacancy.PendingOrderId)
        {
            case null:
                throw new DomainException("There is no listing fee waiting to be paid. Open the payment again.");

            // No order was raised because collection is simulated. Only honoured while it still is, so
            // an order left over from a Development run can never be confirmed for free in production.
            case "" when !razorpaySettings.Value.SimulateCollection:
                throw new DomainException("This payment could not be verified. Open the payment again.");

            case "":
                break;

            // The client says it paid; only a signature made with the server's secret proves it.
            case var orderId when !paymentProvider.VerifyPaymentSignature(
                orderId, request.ProviderPaymentId ?? string.Empty, request.Signature ?? string.Empty):
                throw new DomainException(
                    "This payment could not be verified with Razorpay. Your vacancy is not live yet — try paying again.");
        }

        vacancy.RecordPayment(request.ProviderPaymentId, now);
        await dbContext.SaveChangesAsync(cancellationToken);

        return await VacancyReader.GetAsync(dbContext, vacancy.Id, null, now, cancellationToken);
    }
}
