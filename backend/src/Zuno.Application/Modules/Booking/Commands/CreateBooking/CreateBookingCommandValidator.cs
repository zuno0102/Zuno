using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Booking.Commands.CreateBooking;

public class CreateBookingCommandValidator : AbstractValidator<CreateBookingCommand>
{
    public CreateBookingCommandValidator(IApplicationDbContext dbContext, IDateTimeProvider dateTimeProvider)
    {
        RuleFor(x => x.BusinessServiceId)
            .MustAsync((id, cancellationToken) => dbContext.BusinessServices
                .Include(s => s.BusinessOwnerProfile)
                .AnyAsync(s => s.Id == id && s.IsActive && s.BusinessOwnerProfile.VerificationStatus == VerificationStatus.Verified, cancellationToken))
            .WithMessage("BusinessServiceId must reference an active service from a verified business.");

        RuleFor(x => x.BusinessServiceVariantId)
            .MustAsync((command, variantId, cancellationToken) => dbContext.BusinessServiceVariants
                .AnyAsync(v => v.Id == variantId && v.IsActive && v.BusinessServiceId == command.BusinessServiceId, cancellationToken))
            .When(x => x.BusinessServiceVariantId.HasValue)
            .WithMessage("BusinessServiceVariantId must reference an active variant of the selected service.");

        RuleFor(x => x.ScheduledDate)
            .Must((command, scheduledDate) => scheduledDate > dateTimeProvider.UtcNow)
            .WithMessage("ScheduledDate must be in the future.");

        RuleFor(x => x.Notes).MaximumLength(1000);

        RuleForEach(x => x.Answers).ChildRules(answer =>
        {
            answer.RuleFor(a => a.AnswerText).MaximumLength(1000);
        });

        // A question id the client made up, or borrowed from another business's service, would
        // otherwise be written onto this order as though the business had asked it.
        RuleFor(x => x.Answers)
            .MustAsync(async (command, answers, cancellationToken) =>
            {
                var ids = answers.Select(a => a.QuestionId).ToList();
                var owned = await dbContext.BusinessServiceQuestions.CountAsync(
                    q => q.BusinessServiceId == command.BusinessServiceId && ids.Contains(q.Id),
                    cancellationToken);

                return owned == ids.Distinct().Count() && ids.Count == ids.Distinct().Count();
            })
            .When(x => x.Answers.Count > 0)
            .WithMessage("One or more answers do not match a question on this service.");

        // Required means required: a business that asks for the guest count cannot staff the job
        // without it, so an order missing one is refused rather than accepted half-blind.
        RuleFor(x => x.Answers)
            .MustAsync(async (command, answers, cancellationToken) =>
            {
                var answered = answers
                    .Where(a => !string.IsNullOrWhiteSpace(a.AnswerText))
                    .Select(a => a.QuestionId)
                    .ToHashSet();

                var required = await dbContext.BusinessServiceQuestions
                    .Where(q => q.BusinessServiceId == command.BusinessServiceId && q.IsRequired)
                    .Select(q => q.Id)
                    .ToListAsync(cancellationToken);

                return required.All(answered.Contains);
            })
            .WithMessage("Please answer everything the business marked as required.");

        RuleFor(x => x.AddressLine1).NotEmpty().MaximumLength(200);
        RuleFor(x => x.City).NotEmpty().MaximumLength(100);
        RuleFor(x => x.State).NotEmpty().MaximumLength(100);
        RuleFor(x => x.PostalCode).NotEmpty().MaximumLength(10);
        RuleFor(x => x.AddressLine2).MaximumLength(200);

        // The exact spot, pinned on a map. A typed address alone is how workers ended up at the
        // wrong house: it carries the typos and the "near the temple" no worker can navigate to.
        RuleFor(x => x.Latitude)
            .NotNull().WithMessage("Pin the job location on the map.")
            .InclusiveBetween(-90m, 90m).WithMessage("The pinned location is not valid. Pin it again.");
        RuleFor(x => x.Longitude)
            .NotNull().WithMessage("Pin the job location on the map.")
            .InclusiveBetween(-180m, 180m).WithMessage("The pinned location is not valid. Pin it again.");
    }
}
