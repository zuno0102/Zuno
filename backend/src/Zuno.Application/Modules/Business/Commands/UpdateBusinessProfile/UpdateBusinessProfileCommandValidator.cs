using FluentValidation;

namespace Zuno.Application.Modules.Business.Commands.UpdateBusinessProfile;

public class UpdateBusinessProfileCommandValidator : AbstractValidator<UpdateBusinessProfileCommand>
{
    public UpdateBusinessProfileCommandValidator()
    {
        RuleFor(x => x.BusinessName).NotEmpty().MaximumLength(200);
        RuleFor(x => x.BusinessType).MaximumLength(100);
        RuleFor(x => x.Description).MaximumLength(1000);
        RuleFor(x => x.LogoUrl).MaximumLength(500);

        When(x => !string.IsNullOrWhiteSpace(x.GstNumber), () =>
        {
            RuleFor(x => x.GstNumber!)
                .Matches(@"^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$")
                .WithMessage("GstNumber must be a valid 15-character GSTIN.");
        });

        When(x => !string.IsNullOrWhiteSpace(x.AddressLine1), () =>
        {
            RuleFor(x => x.City).NotEmpty().WithMessage("City is required when an address is provided.");
            RuleFor(x => x.State).NotEmpty().WithMessage("State is required when an address is provided.");
            RuleFor(x => x.PostalCode).NotEmpty().WithMessage("PostalCode is required when an address is provided.");
        });
    }
}
