using FluentValidation;

namespace Zuno.Application.Modules.WorkChat.Commands.SendWorkMessage;

/// <summary>The same rules as a booking message, so the two chats behave alike.</summary>
public class SendWorkMessageCommandValidator : AbstractValidator<SendWorkMessageCommand>
{
    public SendWorkMessageCommandValidator()
    {
        RuleFor(x => x.CounterpartId).NotEmpty();

        RuleFor(x => x.Body)
            .Must(body => !string.IsNullOrWhiteSpace(body))
            .WithMessage("Write something before sending.")
            .MaximumLength(2000)
            .WithMessage("A message can be at most 2000 characters.");
    }
}
