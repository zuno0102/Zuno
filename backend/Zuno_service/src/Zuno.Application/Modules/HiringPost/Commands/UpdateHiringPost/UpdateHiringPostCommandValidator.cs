using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.Common;

namespace Zuno.Application.Modules.HiringPost.Commands.UpdateHiringPost;

public class UpdateHiringPostCommandValidator : AbstractValidator<UpdateHiringPostCommand>
{
    public UpdateHiringPostCommandValidator(IApplicationDbContext dbContext, IPlatformSettings platformSettings)
    {
        RuleFor(x => x.HiringPostId).NotEmpty();
        RuleFor(x => x.Title).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Description).MaximumLength(1000);
        RuleFor(x => x.Location).MaximumLength(300);
        RuleFor(x => x.Latitude).InclusiveBetween(-90m, 90m);
        RuleFor(x => x.Longitude).InclusiveBetween(-180m, 180m);
        RuleFor(x => x)
            .Must(x => x.Latitude.HasValue == x.Longitude.HasValue)
            .WithMessage("Send both latitude and longitude, or neither.");
        RuleFor(x => x.EventDate).NotEmpty();
        RuleFor(x => x.DurationMinutes).ValidDuration(platformSettings);
        // Not required: a post raised from an order takes its kind of work from the package the
        // customer chose, and a standalone post has no order to take one from. Validated only
        // when something was sent, so a bad id can never be stored.
        RuleFor(x => x.ServiceSubCategoryId)
            .MustAsync((id, cancellationToken) => dbContext.ServiceSubCategories
                .AnyAsync(s => s.Id == id && s.IsActive, cancellationToken))
            .When(x => x.ServiceSubCategoryId.HasValue)
            .WithMessage("That kind of work is not one Zuno lists.");

        RuleFor(x => x.WorkersNeeded).ValidWorkersNeeded(platformSettings);
        RuleFor(x => x.SalaryAmount).ValidWage();
        RuleFor(x => x.SalaryUnit).IsInEnum();
    }
}
