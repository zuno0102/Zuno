namespace Zuno.Application.Modules.Vacancies.DTOs;

/// <summary>One page of a keyset-paged list.</summary>
/// <remarks>
/// <see cref="NextBefore"/> is passed back as <c>before</c> for the following page, and is null on the
/// last one. A cursor rather than a page number: rows added while a worker scrolls never shift the list
/// under them, and the database seeks straight to the position instead of counting past every row.
/// </remarks>
public class VacancyPageDto<T>
{
    public List<T> Items { get; set; } = [];

    public DateTimeOffset? NextBefore { get; set; }
}
