using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Queries.GetMyBusinessProfile;

public class GetMyBusinessProfileQueryHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessTrustService trustService)
    : IRequestHandler<GetMyBusinessProfileQuery, BusinessProfileDto>
{
    public async Task<BusinessProfileDto> Handle(GetMyBusinessProfileQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var profile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var dto = profile.ToDto();

        // An owner should be able to see both verdicts on themselves — it is the only way to know
        // what a customer or a worker is looking at before they decide.
        dto.Trust = await trustService.GetAsync(profile.Id, cancellationToken);

        return dto;
    }
}
