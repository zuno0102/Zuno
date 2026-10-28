using MediatR;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Commands.CreateVacancy;

/// <summary>Writes a vacancy. It stays unseen by workers until its listing fee is paid.</summary>
public class CreateVacancyCommand : VacancyFieldsCommand, IRequest<VacancyDto>;
