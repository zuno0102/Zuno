using FluentValidation;

namespace Zuno.Application.Modules.Catalog.Commands.SaveServiceCategory;

public class SaveServiceCategoryCommandValidator : AbstractValidator<SaveServiceCategoryCommand>
{
    public SaveServiceCategoryCommandValidator()
    {
        // Lengths match the column widths in ServiceCategoryConfiguration, so an over-long name
        // is refused with a sentence rather than by the database.
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Description).MaximumLength(500);
        RuleFor(x => x.IconUrl).MaximumLength(500);
        RuleFor(x => x.IconName).MaximumLength(50);
        RuleFor(x => x.DisplayOrder).GreaterThanOrEqualTo((short)0);
    }
}
