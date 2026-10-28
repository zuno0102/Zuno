using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Commands.ConfirmPayoutCollection;

/// <summary>
/// The business's payment for the batch total has cleared. Triggers the split to each worker.
/// </summary>
/// <param name="ProviderPaymentId">Razorpay's id for the completed payment.</param>
/// <param name="Signature">
/// Razorpay's signature over the order and payment ids. Verified against the key secret before
/// a rupee is moved — the browser reports its own success, so without this anyone could claim a
/// pay run was funded and have every worker marked paid without paying.
/// </param>
public record ConfirmPayoutCollectionCommand(
    Guid PayoutBatchId,
    string ProviderPaymentId,
    string? Signature = null) : IRequest<PayoutBatchDto>;
