using FluentValidation;

namespace Zuno.Application.Modules.Booking.Commands.ProposeBookingTerms;

public class ProposeBookingTermsCommandValidator
    : AbstractValidator<ProposeBookingTermsCommand>
{
    public ProposeBookingTermsCommandValidator()
    {
        RuleFor(x => x.BookingId).NotEmpty();

        RuleFor(x => x.WorkerCount)
            .GreaterThanOrEqualTo(1)
            .WithMessage("A job needs at least one person on it.");

        RuleFor(x => x.Price)
            .GreaterThan(0)
            .WithMessage("Enter what the order will cost at that crew size.");

        RuleFor(x => x.Message).MaximumLength(500);
    }
}
