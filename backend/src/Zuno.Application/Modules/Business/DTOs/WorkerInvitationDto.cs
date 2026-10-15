namespace Zuno.Application.Modules.Business.DTOs;

public class WorkerInvitationDto
{
    public Guid Id { get; set; }

    public Guid BusinessOwnerProfileId { get; set; }

    public string BusinessName { get; set; } = string.Empty;

    public string? BusinessLogoUrl { get; set; }

    public string Status { get; set; } = string.Empty;

    public DateTimeOffset InvitedAt { get; set; }

    public DateTimeOffset? RespondedAt { get; set; }
}
