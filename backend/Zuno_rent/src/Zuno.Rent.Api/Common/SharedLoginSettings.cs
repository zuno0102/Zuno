using System.ComponentModel.DataAnnotations;

namespace Zuno.Rent.Api.Common;

/// <summary>
/// How to check a token from the shared login. Same section name and values as the Service API
/// (<c>JwtSettings</c>), which issues the tokens; Rent only validates them and never issues any.
/// </summary>
public class SharedLoginSettings
{
    public const string SectionName = "JwtSettings";

    [Required]
    public string Issuer { get; set; } = string.Empty;

    [Required]
    public string Audience { get; set; } = string.Empty;

    [Required]
    [MinLength(32)]
    public string SigningKey { get; set; } = string.Empty;
}

public static class RentPolicies
{
    public const string BusinessOwner = "RequireBusinessOwnerRole";

    public const string Customer = "RequireCustomerRole";

    public const string UploadPolicy = "RentUploadPolicy";

    /// <summary>Sending and checking mobile codes: a few a minute per person, whatever the database allows.</summary>
    public const string PhoneCodePolicy = "RentPhoneCodePolicy";
}
