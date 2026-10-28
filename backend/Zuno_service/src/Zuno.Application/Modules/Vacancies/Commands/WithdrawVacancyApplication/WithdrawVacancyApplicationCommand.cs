using MediatR;

namespace Zuno.Application.Modules.Vacancies.Commands.WithdrawVacancyApplication;

/// <summary>The worker takes their application back. Their documents and answers are deleted with it.</summary>
public record WithdrawVacancyApplicationCommand(Guid ApplicationId) : IRequest;
