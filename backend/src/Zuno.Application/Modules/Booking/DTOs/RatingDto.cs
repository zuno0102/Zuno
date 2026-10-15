namespace Zuno.Application.Modules.Booking.DTOs;

public class RatingDto
{
    public short Score { get; set; }

    public string? Comment { get; set; }

    public DateTimeOffset CreatedDate { get; set; }
}
