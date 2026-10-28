using MediatR;
using Microsoft.Extensions.Logging;

namespace Zuno.Application.Common.Behaviors;

public class UnhandledExceptionBehavior<TRequest, TResponse>(
    ILogger<UnhandledExceptionBehavior<TRequest, TResponse>> logger)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : IRequest<TResponse>
{
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        try
        {
            return await next(cancellationToken);
        }
        catch (Exception ex) when (ex is not FluentValidation.ValidationException)
        {
            var requestName = typeof(TRequest).Name;
            logger.LogError(ex, "Unhandled exception for request {RequestName}", requestName);
            throw;
        }
    }
}
