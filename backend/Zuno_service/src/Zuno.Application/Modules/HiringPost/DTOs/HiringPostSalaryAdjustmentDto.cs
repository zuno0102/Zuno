namespace Zuno.Application.Modules.HiringPost.DTOs;

public class HiringPostSalaryAdjustmentDto
{
    public Guid Id { get; set; }

    public decimal PreviousAmount { get; set; }

    public decimal NewAmount { get; set; }

    public string? Reason { get; set; }

    public DateTimeOffset AdjustedAt { get; set; }
}
