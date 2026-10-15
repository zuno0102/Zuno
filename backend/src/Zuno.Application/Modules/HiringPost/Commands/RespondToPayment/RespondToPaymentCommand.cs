using MediatR;

namespace Zuno.Application.Modules.HiringPost.Commands.RespondToPayment;

/// <summary>
/// The worker's answer on whether their wages arrived.
/// </summary>
/// <remarks>
/// A provider reporting success says the instruction was accepted, not that the money landed, and
/// a business marking someone paid is only its own word. The person whose account it should have
/// reached is the one who actually knows — which is why a dispute here is the signal the trust
/// score rests on.
/// </remarks>
/// <param name="Received">True if the money arrived; false raises a dispute.</param>
public record RespondToPaymentCommand(
    Guid HiringPostApplicationId,
    bool Received,
    string? DisputeReason = null) : IRequest<Unit>;
