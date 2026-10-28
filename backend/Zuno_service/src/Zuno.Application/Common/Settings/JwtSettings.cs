using System.ComponentModel.DataAnnotations;

namespace Zuno.Application.Common.Settings;

public class JwtSettings
{
    public const string SectionName = "JwtSettings";

    [Required(AllowEmptyStrings = false)]
    public string Issuer { get; set; } = string.Empty;

    [Required(AllowEmptyStrings = false)]
    public string Audience { get; set; } = string.Empty;

    [Required(AllowEmptyStrings = false)]
    [MinLength(32, ErrorMessage = "SigningKey must be at least 32 characters (256 bits) long.")]
    public string SigningKey { get; set; } = string.Empty;

    [Range(1, 1440)]
    public int AccessTokenExpiryMinutes { get; set; } = 15;

    [Range(1, 90)]
    public int RefreshTokenExpiryDays { get; set; } = 14;
}
