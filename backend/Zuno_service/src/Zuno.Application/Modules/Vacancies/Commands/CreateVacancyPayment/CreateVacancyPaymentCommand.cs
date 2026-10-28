using System.Text.Json.Serialization;
using MediatR;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Commands.CreateVacancyPayment;

/// <summary>
/// Raises the listing fee order: the first payment that puts a vacancy live, or a renewal. The price
/// comes from the fee plan table — never from the client.
/// </summary>
public class CreateVacancyPaymentCommand : IRequest<VacancyPaymentDto>
{
    [JsonIgnore]
    public Guid VacancyId { get; set; }

    /// <summary>The plan to pay for. Omitted, the vacancy's last plan or the first active one.</summary>
    public Guid? FeePlanId { get; set; }
}
