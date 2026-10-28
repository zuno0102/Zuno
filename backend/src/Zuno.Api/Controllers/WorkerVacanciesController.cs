using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Zuno.Api.Authorization;
using Zuno.Api.Common;
using Zuno.Api.RateLimiting;
using Zuno.Application.Modules.Vacancies.Commands.ApplyToVacancy;
using Zuno.Application.Modules.Vacancies.Commands.WithdrawVacancyApplication;
using Zuno.Application.Modules.Vacancies.Queries.GetMyVacancyApplications;
using Zuno.Application.Modules.Vacancies.Queries.GetOpenVacancies;
using Zuno.Application.Modules.Vacancies.Queries.GetVacancyForWorker;
using Zuno.Application.Modules.Vacancies.Queries.GetVacancyOptions;

namespace Zuno.Api.Controllers;

/// <summary>
/// Full-time vacancies as a worker finds and applies to them. Workers only — customers never see
/// vacancies, which is enforced here and not just hidden by the app.
/// </summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/worker/vacancies")]
[Authorize(Policy = AuthorizationPolicyNames.RequireWorkerRole)]
public class WorkerVacanciesController(ISender mediator) : ControllerBase
{
    /// <summary>Upper bound on one application request. Each file is also held to its document's own limit.</summary>
    private const long MaxApplicationRequestBytes = 35 * 1024 * 1024;

    private const string TextFieldPrefix = "text_";
    private const string FileFieldPrefix = "file_";

    [HttpGet]
    public async Task<IActionResult> GetOpen([FromQuery] GetOpenVacanciesQuery query, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(query, cancellationToken));

    [HttpGet("options")]
    public async Task<IActionResult> GetOptions(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetVacancyOptionsQuery(), cancellationToken));

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetVacancyForWorkerQuery(id), cancellationToken));

    [HttpGet("applications")]
    public async Task<IActionResult> GetMyApplications(
        [FromQuery] GetMyVacancyApplicationsQuery query, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(query, cancellationToken));

    [HttpDelete("applications/{applicationId:guid}")]
    public async Task<IActionResult> Withdraw(Guid applicationId, CancellationToken cancellationToken)
    {
        await mediator.Send(new WithdrawVacancyApplicationCommand(applicationId), cancellationToken);
        return NoContent();
    }

    /// <summary>
    /// Applies with a multipart form: <c>text_{requirementId}</c> for each answer and
    /// <c>file_{requirementId}</c> for each document.
    /// </summary>
    [HttpPost("{id:guid}/apply")]
    [RequestSizeLimit(MaxApplicationRequestBytes)]
    [EnableRateLimiting(RateLimiterExtensions.DocumentUploadPolicy)]
    public async Task<IActionResult> Apply(Guid id, CancellationToken cancellationToken)
    {
        if (!Request.HasFormContentType)
        {
            return BadRequest(ApiResponse.Fail("Send the application as a form.", HttpContext.TraceIdentifier));
        }

        var form = await Request.ReadFormAsync(cancellationToken);
        var answers = new Dictionary<Guid, (string? Text, IFormFile? File)>();

        foreach (var (key, value) in form)
        {
            if (!TryRequirementId(key, TextFieldPrefix, out var requirementId))
            {
                continue;
            }

            answers[requirementId] = (value.ToString(), null);
        }

        foreach (var file in form.Files)
        {
            if (!TryRequirementId(file.Name, FileFieldPrefix, out var requirementId))
            {
                return BadRequest(ApiResponse.Fail("A file was sent for no requirement.", HttpContext.TraceIdentifier));
            }

            answers[requirementId] = (answers.GetValueOrDefault(requirementId).Text, file);
        }

        var streams = new List<Stream>();
        try
        {
            var command = new ApplyToVacancyCommand { VacancyId = id };

            foreach (var (requirementId, (text, file)) in answers)
            {
                var stream = file?.OpenReadStream();
                if (stream is not null)
                {
                    streams.Add(stream);
                }

                command.Answers.Add(new VacancyAnswerUpload(requirementId, text, stream, file?.Length ?? 0));
            }

            return Ok(await mediator.Send(command, cancellationToken));
        }
        finally
        {
            foreach (var stream in streams)
            {
                await stream.DisposeAsync();
            }
        }
    }

    private static bool TryRequirementId(string fieldName, string prefix, out Guid requirementId)
    {
        requirementId = Guid.Empty;
        return fieldName.StartsWith(prefix, StringComparison.Ordinal)
            && Guid.TryParse(fieldName.AsSpan(prefix.Length), out requirementId);
    }
}
