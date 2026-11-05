using FluentValidation;
using Zuno.Application.Modules.Worker.Common;

namespace Zuno.Application.Modules.Business.Commands;

/// <summary>The one rule for a business's UPI ID, used by the profile form and the quick "Add UPI ID".</summary>
public static class BusinessUpiIdRule
{
    public const string Required = "Enter your UPI ID — customers pay you by scanning a QR made from it.";

    public static IRuleBuilderOptions<T, string> BusinessUpiId<T>(this IRuleBuilder<T, string> rule) =>
        // Checked as it will be kept — trimmed — so a space copied along with a pasted ID is not
        // refused for a reason nobody can see.
        rule.NotEmpty().WithMessage(Required)
            .Must(v => (v ?? string.Empty).Trim().Length <= UpiFormat.MaxLength)
            .WithMessage($"A UPI ID is at most {UpiFormat.MaxLength} characters.")
            .Must(v => string.IsNullOrWhiteSpace(v) || UpiFormat.IsValid(v.Trim()))
            .WithMessage(UpiFormat.Hint);
}
