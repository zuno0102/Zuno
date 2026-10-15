using MediatR;
using Zuno.Application.Modules.Admin.DTOs;

namespace Zuno.Application.Modules.Admin.Commands.SetBusinessVerification;

/// <summary>
/// An admin's decision on whether a business may be found by customers.
/// </summary>
/// <remarks>
/// The gate exists because a listing is a recommendation: anything a customer can find here
/// carries Zuno's word that someone looked at it. Until this runs, a business can build its
/// whole catalogue and remain invisible — which is the intended default, not a bug.
/// </remarks>
/// <param name="Approve">True to verify, false to reject.</param>
public record SetBusinessVerificationCommand(
    Guid BusinessOwnerProfileId,
    bool Approve) : IRequest<BusinessReviewDto>;
