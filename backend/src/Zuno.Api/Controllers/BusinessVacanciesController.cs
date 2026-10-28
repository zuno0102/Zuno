using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Api.Authorization;
using Zuno.Application.Modules.Vacancies.Commands.ConfirmVacancyPayment;
using Zuno.Application.Modules.Vacancies.Commands.CreateVacancy;
using Zuno.Application.Modules.Vacancies.Commands.CreateVacancyPayment;
using Zuno.Application.Modules.Vacancies.Commands.DeleteVacancy;
using Zuno.Application.Modules.Vacancies.Commands.MarkVacancyApplicationViewed;
using Zuno.Application.Modules.Vacancies.Commands.SetVacancyApplicationStatus;
using Zuno.Application.Modules.Vacancies.Commands.SetVacancyHiring;
using Zuno.Application.Modules.Vacancies.Commands.UpdateVacancy;
using Zuno.Application.Modules.Vacancies.Queries.GetMyVacancies;
using Zuno.Application.Modules.Vacancies.Queries.GetVacancyApplications;
using Zuno.Application.Modules.Vacancies.Queries.GetVacancyDocument;
using Zuno.Application.Modules.Vacancies.Queries.GetVacancyOptions;
using Zuno.Application.Modules.Vacancies.Queries.GetVacancySummary;
using Zuno.Domain.Enums;

namespace Zuno.Api.Controllers;

/// <summary>A business's full-time vacancies: writing them, paying to list them, and reviewing applicants.</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/business/vacancies")]
[Authorize(Policy = AuthorizationPolicyNames.RequireBusinessOwnerRole)]
public class BusinessVacanciesController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetMine([FromQuery] GetMyVacanciesQuery query, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(query, cancellationToken));

    /// <summary>Live posts and applicants by list, for the business home screen.</summary>
    [HttpGet("summary")]
    public async Task<IActionResult> GetSummary(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetVacancySummaryQuery(), cancellationToken));

    /// <summary>Job types, fee plans and upload rules for the forms.</summary>
    [HttpGet("options")]
    public async Task<IActionResult> GetOptions(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetVacancyOptionsQuery(), cancellationToken));

    [HttpPost]
    public async Task<IActionResult> Create(CreateVacancyCommand command, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(command, cancellationToken));

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, UpdateVacancyCommand command, CancellationToken cancellationToken)
    {
        command.VacancyId = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }

    /// <summary>Deletes the vacancy and every applicant's documents at once. No refund.</summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        await mediator.Send(new DeleteVacancyCommand(id), cancellationToken);
        return NoContent();
    }

    [HttpPost("{id:guid}/stop-hiring")]
    public async Task<IActionResult> StopHiring(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new SetVacancyHiringCommand(id, IsHiring: false), cancellationToken));

    /// <summary>Reopens a stopped vacancy, free while its paid period lasts.</summary>
    [HttpPost("{id:guid}/start-hiring")]
    public async Task<IActionResult> StartHiring(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new SetVacancyHiringCommand(id, IsHiring: true), cancellationToken));

    /// <summary>Raises the listing fee order. The amount comes from the fee plan, never the request.</summary>
    [HttpPost("{id:guid}/payment")]
    public async Task<IActionResult> CreatePayment(
        Guid id, [FromBody] CreateVacancyPaymentCommand? command, CancellationToken cancellationToken)
    {
        command ??= new CreateVacancyPaymentCommand();
        command.VacancyId = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }

    [HttpPost("{id:guid}/payment/confirm")]
    public async Task<IActionResult> ConfirmPayment(
        Guid id, ConfirmVacancyPaymentCommand command, CancellationToken cancellationToken)
    {
        command.VacancyId = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }

    [HttpGet("{id:guid}/applications")]
    public async Task<IActionResult> GetApplications(
        Guid id,
        [FromQuery] VacancyApplicationStatus? status,
        [FromQuery] int? take,
        [FromQuery] DateTimeOffset? before,
        CancellationToken cancellationToken) =>
        Ok(await mediator.Send(
            new GetVacancyApplicationsQuery { VacancyId = id, Status = status, Take = take, Before = before },
            cancellationToken));

    /// <summary>Applicants across every vacancy the business owns — what the home screen's tiles open.</summary>
    [HttpGet("applications")]
    public async Task<IActionResult> GetAllApplications(
        [FromQuery] VacancyApplicationStatus? status,
        [FromQuery] int? take,
        [FromQuery] DateTimeOffset? before,
        CancellationToken cancellationToken) =>
        Ok(await mediator.Send(
            new GetVacancyApplicationsQuery { Status = status, Take = take, Before = before },
            cancellationToken));

    /// <summary>The business opened this applicant: New moves to Waiting. Repeating it changes nothing.</summary>
    [HttpPost("applications/{applicationId:guid}/viewed")]
    public async Task<IActionResult> MarkApplicationViewed(Guid applicationId, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new MarkVacancyApplicationViewedCommand(applicationId), cancellationToken));

    [HttpPost("applications/{applicationId:guid}/status")]
    public async Task<IActionResult> SetApplicationStatus(
        Guid applicationId, SetVacancyApplicationStatusCommand command, CancellationToken cancellationToken)
    {
        command.ApplicationId = applicationId;
        return Ok(await mediator.Send(command, cancellationToken));
    }

    /// <summary>
    /// Streams an applicant's document. Private storage has no URL, so this is the only way to it,
    /// and it answers the owning business alone.
    /// </summary>
    [HttpGet("documents/{answerId:guid}")]
    public async Task<IActionResult> GetDocument(Guid answerId, CancellationToken cancellationToken)
    {
        var file = await mediator.Send(new GetVacancyDocumentQuery(answerId), cancellationToken);

        // Personal documents are never kept by a browser or proxy cache.
        Response.Headers.CacheControl = "no-store";
        return File(file.Content, file.ContentType, file.FileName);
    }
}
