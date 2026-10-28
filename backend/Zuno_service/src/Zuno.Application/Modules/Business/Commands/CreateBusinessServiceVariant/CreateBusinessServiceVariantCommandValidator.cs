using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Business.Commands.CreateBusinessServiceVariant;

public class CreateBusinessServiceVariantCommandValidator : AbstractValidator<CreateBusinessServiceVariantCommand>
{
    public CreateBusinessServiceVariantCommandValidator(IApplicationDbContext dbContext)
    {
        RuleFor(x => x.ServiceId)
            .MustAsync((id, cancellationToken) => dbContext.BusinessServices.AnyAsync(s => s.Id == id, cancellationToken))
            .WithMessage("ServiceId must reference an existing service.");

        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Description).MaximumLength(1000);

        RuleFor(x => x.PriceType)
            .NotEmpty()
            .Must(value => Enum.TryParse<PriceType>(value, ignoreCase: true, out _))
            .WithMessage($"PriceType must be one of: {string.Join(", ", Enum.GetNames<PriceType>())}.");

        RuleFor(x => x.Price).GreaterThan(0);

        RuleFor(x => x.EstimatedDurationMinutes)
            .GreaterThan((short)0)
            .When(x => x.EstimatedDurationMinutes.HasValue);
    }
}
