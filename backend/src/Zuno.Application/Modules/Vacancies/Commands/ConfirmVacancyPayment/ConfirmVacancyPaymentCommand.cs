using System.Text.Json.Serialization;
using MediatR;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Commands.ConfirmVacancyPayment;

/// <summary>The business's payment has cleared: verify it, then put the vacancy live or extend it.</summary>
public class ConfirmVacancyPaymentCommand : IRequest<VacancyDto>
{
    [JsonIgnore]
    public Guid VacancyId { get; set; }

    public string? ProviderPaymentId { get; set; }

    public string? Signature { get; set; }
}
