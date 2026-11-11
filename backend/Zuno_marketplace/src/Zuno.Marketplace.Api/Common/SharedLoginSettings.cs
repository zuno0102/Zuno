using System.ComponentModel.DataAnnotations;

namespace Zuno.Marketplace.Api.Common;

/// <summary>
/// How to check a token from the shared login. Same section name and values as the Service API
/// (<c>JwtSettings</c>), which issues the tokens; Marketplace only validates them and never issues any.
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

public static class MarketplacePolicies
{
    public const string BusinessOwner = "RequireBusinessOwnerRole";

    public const string SuperAdmin = "RequireSuperAdminRole";

    public const string UploadPolicy = "MarketplaceUploadPolicy";
}
