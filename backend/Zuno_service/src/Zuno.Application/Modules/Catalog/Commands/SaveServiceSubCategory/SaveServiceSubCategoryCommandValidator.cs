using FluentValidation;

namespace Zuno.Application.Modules.Catalog.Commands.SaveServiceSubCategory;

public class SaveServiceSubCategoryCommandValidator
    : AbstractValidator<SaveServiceSubCategoryCommand>
{
    public SaveServiceSubCategoryCommandValidator()
    {
        RuleFor(x => x.ServiceCategoryId).NotEmpty();

        // Matches the column width in ServiceSubCategoryConfiguration.
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        RuleFor(x => x.DisplayOrder).GreaterThanOrEqualTo((short)0);
    }
}
