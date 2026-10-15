using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Admin.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Admin.Commands.SetBusinessVerification;

public class SetBusinessVerificationCommandHandler(
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext)
    : IRequestHandler<SetBusinessVerificationCommand, BusinessReviewDto>
{
    public async Task<BusinessReviewDto> Handle(
        SetBusinessVerificationCommand request,
        CancellationToken cancellationToken)
    {
        var profile = await dbContext.BusinessOwnerProfiles
            .Include(p => p.User)
            .Include(p => p.BusinessAddress)
            .Include(p => p.Services)
            .FirstOrDefaultAsync(p => p.Id == request.BusinessOwnerProfileId, cancellationToken)
            ?? throw new EntityNotFoundException(
                nameof(BusinessOwnerProfile), request.BusinessOwnerProfileId);

        profile.VerificationStatus = request.Approve
            ? VerificationStatus.Verified
            : VerificationStatus.Rejected;

        // Stamped only on approval. A rejection is not a verification date, and keeping the
        // field meaning one thing is what lets "verified since" be shown later without lying.
        profile.VerifiedAt = request.Approve ? dateTimeProvider.UtcNow : null;

        await dbContext.SaveChangesAsync(cancellationToken);

        return profile.ToReviewDto();
    }
}
