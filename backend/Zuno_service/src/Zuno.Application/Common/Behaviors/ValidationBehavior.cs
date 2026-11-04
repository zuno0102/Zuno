using FluentValidation;
using MediatR;

namespace Zuno.Application.Common.Behaviors;

/// <summary>
/// Runs a request's validators before its handler. Constrained to <c>notnull</c>, not
/// <c>IRequest&lt;TResponse&gt;</c>: a command that returns nothing (<c>IRequest</c>, such as
/// ChangePassword) does not implement <c>IRequest&lt;Unit&gt;</c>, so the narrower constraint
/// silently skipped its validators and let weak passwords through.
/// </summary>
public class ValidationBehavior<TRequest, TResponse>(IEnumerable<IValidator<TRequest>> validators)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        if (!validators.Any())
        {
            return await next(cancellationToken);
        }

        var context = new ValidationContext<TRequest>(request);

        var validationResults = await Task.WhenAll(
            validators.Select(v => v.ValidateAsync(context, cancellationToken)));

        var failures = validationResults
            .SelectMany(result => result.Errors)
            .Where(failure => failure is not null)
            .ToList();

        if (failures.Count != 0)
        {
            throw new ValidationException(failures);
        }

        return await next(cancellationToken);
    }
}
