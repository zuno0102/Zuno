using FluentValidation;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Business.Commands.UpdateBusinessServiceVariant;

public class UpdateBusinessServiceVariantCommandValidator : AbstractValidator<UpdateBusinessServiceVariantCommand>
{
    public UpdateBusinessServiceVariantCommandValidator()
    {
        RuleFor(x => x.ServiceId).NotEmpty();
        RuleFor(x => x.VariantId).NotEmpty();

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
