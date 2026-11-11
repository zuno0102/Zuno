using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace Zuno.Marketplace.Api.Common;

/// <summary>
/// The one response shape, identical to the Service API's, so the app parses both with the same code.
/// </summary>
public sealed class ApiResponse
{
    public required bool Success { get; init; }

    public required string Message { get; init; }

    public object? Data { get; init; }

    public IReadOnlyDictionary<string, string[]>? Errors { get; init; }

    public required string CorrelationId { get; init; }

    public DateTimeOffset Timestamp { get; init; } = DateTimeOffset.UtcNow;

    public static ApiResponse Ok(object? data, string correlationId, string message = "Request completed successfully.") =>
        new() { Success = true, Message = message, Data = data, CorrelationId = correlationId };

    public static ApiResponse Fail(
        string message, string correlationId, IReadOnlyDictionary<string, string[]>? errors = null) =>
        new() { Success = false, Message = message, Errors = errors, CorrelationId = correlationId };
}

/// <summary>Wraps every 2xx result that has a body in <see cref="ApiResponse"/>.</summary>
public class ApiResponseWrapperFilter : IActionFilter
{
    public void OnActionExecuting(ActionExecutingContext context)
    {
    }

    public void OnActionExecuted(ActionExecutedContext context)
    {
        if (context.Result is not ObjectResult objectResult || objectResult.Value is ApiResponse)
        {
            return;
        }

        var statusCode = objectResult.StatusCode ?? StatusCodes.Status200OK;
        if (statusCode is < 200 or >= 300)
        {
            return;
        }

        objectResult.Value = ApiResponse.Ok(objectResult.Value, context.HttpContext.TraceIdentifier);
    }
}
