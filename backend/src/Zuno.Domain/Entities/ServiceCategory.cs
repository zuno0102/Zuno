using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

public class ServiceCategory : BaseEntity
{
    public string Name { get; set; } = string.Empty;

    public string Slug { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string? IconUrl { get; set; }

    /// <summary>
    /// Which built-in icon the apps should draw for this category — "plumbing", "celebration".
    /// </summary>
    /// <remarks>
    /// Here rather than in the client, which is the point of it. The customer app used to pick an
    /// icon by matching words in the category name, so "Carpentry" drew a lorry (it contains "car")
    /// and anything the matcher had not been taught fell back to a generic spanner. A category is a
    /// row the app owner creates, so what it looks like is a property of that row.
    ///
    /// A key rather than a codepoint: Flutter strips every icon the code does not name, so a number
    /// from the database would draw nothing unless the whole icon font were shipped. The client holds
    /// the short list of keys it can draw; the database decides which one each category uses.
    ///
    /// Null is allowed and means "work it out" — a business-created category with nothing chosen yet.
    /// </remarks>
    public string? IconName { get; set; }

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; } = true;

    public ICollection<ServiceSubCategory> SubCategories { get; set; } = new List<ServiceSubCategory>();

    public ICollection<BusinessService> BusinessServices { get; set; } = new List<BusinessService>();
}
