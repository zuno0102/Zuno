using FluentValidation;
using Microsoft.AspNetCore.Diagnostics;
using Zuno.Api.Common;
using Zuno.Domain.Exceptions;

namespace Zuno.Api.ExceptionHandling;

/// <summary>
/// Single point where exceptions become HTTP responses. Never surfaces internal exception
/// messages or stack traces to the client for unexpected errors — those are logged instead.
/// </summary>
public class GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        var (statusCode, message, errors) = MapException(exception);

        if (statusCode == StatusCodes.Status500InternalServerError)
        {
            logger.LogError(exception, "Unhandled exception processing {Method} {Path}", httpContext.Request.Method, httpContext.Request.Path);
        }
        else
        {
            logger.LogWarning(exception, "Handled exception ({StatusCode}) processing {Method} {Path}", statusCode, httpContext.Request.Method, httpContext.Request.Path);
        }

        var response = ApiResponse.Fail(message, httpContext.TraceIdentifier, errors);

        httpContext.Response.StatusCode = statusCode;
        await httpContext.Response.WriteAsJsonAsync(response, cancellationToken);

        return true;
    }

    private static (int StatusCode, string Message, IReadOnlyDictionary<string, string[]>? Errors) MapException(Exception exception) =>
        exception switch
        {
            ValidationException validationException => (
                StatusCodes.Status400BadRequest,
                "One or more validation errors occurred.",
                validationException.Errors
                    .GroupBy(e => e.PropertyName)
                    .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorMessage).ToArray())),

            EntityNotFoundException notFoundException => (
                StatusCodes.Status404NotFound,
                notFoundException.Message,
                null),

            UnauthorizedAccessException unauthorizedException => (
                StatusCodes.Status401Unauthorized,
                unauthorizedException.Message,
                null),

            DomainException domainException => (
                StatusCodes.Status400BadRequest,
                domainException.Message,
                null),

            _ => (
                StatusCodes.Status500InternalServerError,
                "An unexpected error occurred. Please try again later.",
                null),
        };
}
