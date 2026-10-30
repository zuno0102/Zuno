using FluentValidation;
using Microsoft.AspNetCore.Diagnostics;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.Api.Common;

/// <summary>
/// Where exceptions become responses. Never shows an unexpected error's details to the client —
/// those are logged instead.
/// </summary>
public class GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        var (statusCode, message, errors) = Map(exception);

        if (statusCode == StatusCodes.Status500InternalServerError)
        {
            logger.LogError(exception, "Unhandled exception processing {Method} {Path}", httpContext.Request.Method, httpContext.Request.Path);
        }
        else
        {
            logger.LogWarning("Handled {StatusCode} processing {Method} {Path}: {Message}", statusCode, httpContext.Request.Method, httpContext.Request.Path, message);
        }

        httpContext.Response.StatusCode = statusCode;
        await httpContext.Response.WriteAsJsonAsync(ApiResponse.Fail(message, httpContext.TraceIdentifier, errors), cancellationToken);

        return true;
    }

    internal static (int StatusCode, string Message, IReadOnlyDictionary<string, string[]>? Errors) Map(Exception exception) =>
        exception switch
        {
            ValidationException validation => (
                StatusCodes.Status400BadRequest,
                "One or more validation errors occurred.",
                validation.Errors
                    .GroupBy(e => e.PropertyName)
                    .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorMessage).ToArray())),

            EntityNotFoundException notFound => (StatusCodes.Status404NotFound, notFound.Message, null),

            // 403, not 401: the app treats 401 as "session expired" and would sign the user out.
            ForbiddenException forbidden => (StatusCodes.Status403Forbidden, forbidden.Message, null),

            UnauthorizedAccessException unauthorized => (StatusCodes.Status401Unauthorized, unauthorized.Message, null),

            DomainException domain => (StatusCodes.Status400BadRequest, domain.Message, null),

            _ => (StatusCodes.Status500InternalServerError, "An unexpected error occurred. Please try again later.", null),
        };
}
