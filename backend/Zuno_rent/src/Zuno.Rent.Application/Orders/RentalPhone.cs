using System.Text.RegularExpressions;

namespace Zuno.Rent.Application.Orders;

/// <summary>
/// The customer's mobile on an offline order: an Indian mobile, kept as its 10 digits. The app reads
/// it the same way (<c>Validators.indianMobileDigits</c>), and so does sign-up on the Service API.
/// </summary>
public static partial class RentalPhone
{
    public const string Missing = "Give the customer's mobile number.";

    public const string Hint = "Enter a 10-digit mobile number, like 98765 43210.";

    /// <summary>
    /// The 10 digits of a mobile however it was typed — "98765 43210", "+91 98765 43210",
    /// "09876543210" — or null when it is not one.
    /// </summary>
    public static string? Normalize(string? phone)
    {
        var digits = Separators().Replace(phone ?? string.Empty, string.Empty);
        if (digits.StartsWith("+91", StringComparison.Ordinal))
        {
            digits = digits[3..];
        }
        else if (digits.Length == 12 && digits.StartsWith("91", StringComparison.Ordinal))
        {
            digits = digits[2..];
        }
        else if (digits.Length == 11 && digits.StartsWith('0'))
        {
            digits = digits[1..];
        }

        return Mobile().IsMatch(digits) ? digits : null;
    }

    [GeneratedRegex(@"[\s-]")]
    private static partial Regex Separators();

    [GeneratedRegex(@"^[6-9]\d{9}$")]
    private static partial Regex Mobile();
}
