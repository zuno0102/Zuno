using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Commands.CreatePayoutBatch;

/// <summary>
/// "Pay all" — opens a pay run for everyone still owed on this job.
/// </summary>
/// <remarks>
/// Carries no amount, deliberately. The total is derived from the crew's agreed wages on the
/// server, so a tampered client cannot pay ₹1,200 against a ₹1,500 obligation. The optional
/// <see cref="ExpectedTotal"/> is a check, not an instruction: if it disagrees with the server's
/// figure the request is refused rather than either value being used.
/// </remarks>
public record CreatePayoutBatchCommand(Guid HiringPostId, decimal? ExpectedTotal = null)
    : IRequest<PayoutBatchDto>;
