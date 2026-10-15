using System.Globalization;
using System.Text;

namespace Zuno.Application.Modules.Catalog.Commands;

/// <summary>
/// Turns a typed name into the short url-safe handle stored beside it.
/// </summary>
/// <remarks>
/// The admin types a name; nobody should have to think about slugs. This produces the same result
/// as the rule the seeded rows were built with — "Sofa &amp; carpet cleaning" is still
/// "sofa-carpet-cleaning" — so a category added through the app is indistinguishable from one that
/// shipped with the product.
///
/// It keeps letters and digits and treats everything else as a separator, rather than splitting on
/// a list of known separators. The list approach passes anything it was not told about straight
/// through: a name of "!!!" came out as a slug of "!!!" and was accepted as a category.
/// </remarks>
public static class CatalogSlug
{
    /// <summary>
    /// "Sofa &amp; carpet cleaning" becomes "sofa-carpet-cleaning". Returns empty for a name with
    /// nothing usable in it, which the caller refuses.
    /// </summary>
    public static string From(string name)
    {
        var slug = new StringBuilder(name.Length);
        var pendingSeparator = false;

        foreach (var character in name.Trim())
        {
            if (char.IsLetterOrDigit(character))
            {
                // Held back rather than appended when seen, so a run of punctuation collapses to
                // one hyphen and a trailing one is never written at all.
                if (pendingSeparator && slug.Length > 0)
                {
                    slug.Append('-');
                }

                slug.Append(char.ToLower(character, CultureInfo.InvariantCulture));
                pendingSeparator = false;
            }
            else
            {
                pendingSeparator = true;
            }
        }

        return slug.ToString();
    }
}
