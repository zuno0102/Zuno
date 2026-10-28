namespace Zuno.Api.Common;

/// <summary>
/// The single response envelope every endpoint (success or failure) returns, so mobile clients
/// can parse one shape regardless of which controller or exception path produced the response.
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
        new()
        {
            Success = true,
            Message = message,
            Data = data,
            CorrelationId = correlationId,
        };

    public static ApiResponse Fail(
        string message,
        string correlationId,
        IReadOnlyDictionary<string, string[]>? errors = null) =>
        new()
        {
            Success = false,
            Message = message,
            Errors = errors,
            CorrelationId = correlationId,
        };
}
