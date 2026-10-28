using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Queries.GetBusinessServices;

public class GetBusinessServicesQueryHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessServiceRepository businessServiceRepository)
    : IRequestHandler<GetBusinessServicesQuery, List<BusinessServiceDto>>
{
    public async Task<List<BusinessServiceDto>> Handle(GetBusinessServicesQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var services = await businessServiceRepository.GetByBusinessIdAsync(businessProfile.Id, cancellationToken);

        return services.Select(s => s.ToDto()).ToList();
    }
}
