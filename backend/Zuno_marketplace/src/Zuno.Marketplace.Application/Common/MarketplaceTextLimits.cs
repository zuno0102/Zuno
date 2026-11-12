namespace Zuno.Marketplace.Application.Common;

/// <summary>
/// How long each piece of text may be, and the contact number's digits. The one place these are
/// written: the validators check against them and <c>marketplace-options</c> sends them, so the app's
/// boxes stop exactly where the server would refuse — a change here reaches both.
/// </summary>
public static class MarketplaceTextLimits
{
    // A post.
    public const int Title = 120;
    public const int Description = 2000;
    public const int PriceUnit = 20;
    public const int Area = 120;
    public const int AttributeValue = 200;
    public const int CustomDetailName = 40;
    public const int Colour = 40;
    public const int Size = 20;
    public const int ContactPhoneMinDigits = 10;
    public const int ContactPhoneMaxDigits = 15;

    // The super admin's categories, sub-categories and details.
    public const int CategoryName = 100;
    public const int CategoryShortName = 20;
    public const int CategoryDescription = 200;
    public const int IconName = 50;
    public const int FieldLabel = 60;
    public const int FieldUnit = 20;
    public const int FieldOption = 60;

    /// <summary>A contact number: an optional +, then the digits above.</summary>
    public static readonly string ContactPhonePattern = $@"^\+?[0-9]{{{ContactPhoneMinDigits},{ContactPhoneMaxDigits}}}$";

    /// <summary>What <c>marketplace-options</c> sends.</summary>
    public static MarketplaceTextLimitsDto ToDto() => new()
    {
        Title = Title,
        Description = Description,
        PriceUnit = PriceUnit,
        AttributeValue = AttributeValue,
        CustomDetailName = CustomDetailName,
        Colour = Colour,
        Size = Size,
        ContactPhoneMinDigits = ContactPhoneMinDigits,
        ContactPhoneMaxDigits = ContactPhoneMaxDigits,
        CategoryName = CategoryName,
        CategoryShortName = CategoryShortName,
        CategoryDescription = CategoryDescription,
        IconName = IconName,
        FieldLabel = FieldLabel,
        FieldUnit = FieldUnit,
        FieldOption = FieldOption,
    };
}

/// <summary>The text limits as the app reads them.</summary>
public class MarketplaceTextLimitsDto
{
    public int Title { get; set; }

    public int Description { get; set; }

    public int PriceUnit { get; set; }

    public int AttributeValue { get; set; }

    public int CustomDetailName { get; set; }

    public int Colour { get; set; }

    public int Size { get; set; }

    public int ContactPhoneMinDigits { get; set; }

    public int ContactPhoneMaxDigits { get; set; }

    public int CategoryName { get; set; }

    public int CategoryShortName { get; set; }

    public int CategoryDescription { get; set; }

    public int IconName { get; set; }

    public int FieldLabel { get; set; }

    public int FieldUnit { get; set; }

    public int FieldOption { get; set; }
}
