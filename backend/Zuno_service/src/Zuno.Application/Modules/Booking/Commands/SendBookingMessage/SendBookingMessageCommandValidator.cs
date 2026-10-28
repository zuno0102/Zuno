using FluentValidation;

namespace Zuno.Application.Modules.Booking.Commands.SendBookingMessage;

public class SendBookingMessageCommandValidator : AbstractValidator<SendBookingMessageCommand>
{
    public SendBookingMessageCommandValidator()
    {
        RuleFor(x => x.BookingId).NotEmpty();

        RuleFor(x => x.Body)
            // Trimmed first, so a message of nothing but spaces is refused rather than stored as an
            // empty bubble the other side has to puzzle over.
            .Must(body => !string.IsNullOrWhiteSpace(body))
            .WithMessage("Write something before sending.")
            .MaximumLength(2000)
            .WithMessage("A message can be at most 2000 characters.");
    }
}
