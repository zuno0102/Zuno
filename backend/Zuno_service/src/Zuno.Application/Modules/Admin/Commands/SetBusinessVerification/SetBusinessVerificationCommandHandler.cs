using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Admin.DTOs;
using Zuno.Application.Modules.Business.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Admin.Commands.SetBusinessVerification;

public class SetBusinessVerificationCommandHandler(
    BusinessApproval businessApproval,
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

        // Approval goes through the same validation as auto-approval; it is refused, with the reasons,
        // while the business still has something to fix. A rejection is always allowed.
        var problems = await businessApproval.DecideAsync(profile, request.Approve, cancellationToken);
        if (problems.Count > 0)
        {
            throw new DomainException(
                "This business cannot be approved yet: " + string.Join("; ", problems));
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        return profile.ToReviewDto();
    }
}
