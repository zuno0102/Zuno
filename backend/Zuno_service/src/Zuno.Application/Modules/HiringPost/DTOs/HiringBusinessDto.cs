using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.HiringPost.DTOs;

/// <summary>
/// A business as a worker sees it, before deciding whether to give up a day for it.
/// </summary>
/// <remarks>
/// Salary leads, because that is what actually brings someone to a job. Customer star ratings
/// are deliberately absent: how good the food was tells a worker nothing about whether they
/// will be paid.
/// </remarks>
public class HiringBusinessDto
{
    public Guid Id { get; set; }

    public string BusinessName { get; set; } = string.Empty;

    public string? LogoUrl { get; set; }

    public string? City { get; set; }

    public string? State { get; set; }

    public int Level { get; set; } = 1;

    public string LevelName { get; set; } = string.Empty;

    public bool IsVerified { get; set; }

    /// <summary>The pay record only — the customer half is not a worker's business.</summary>
    public WorkerFacingTrustDto Pay { get; set; } = new();

    /// <summary>Jobs this business is hiring for right now, so the pay figures have context.</summary>
    public List<HiringPostDto> OpenPosts { get; set; } = [];
}
