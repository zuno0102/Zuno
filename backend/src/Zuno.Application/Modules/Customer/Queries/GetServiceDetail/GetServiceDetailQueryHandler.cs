using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Customer.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Customer.Queries.GetServiceDetail;

public class GetServiceDetailQueryHandler(IApplicationDbContext dbContext)
    : IRequestHandler<GetServiceDetailQuery, ServiceDetailDto>
{
    public async Task<ServiceDetailDto> Handle(
        GetServiceDetailQuery request,
        CancellationToken cancellationToken)
    {
        var service = await dbContext.BusinessServices
            .Include(s => s.ServiceCategory)
            .Include(s => s.Media)
            .Include(s => s.Variants).ThenInclude(v => v.Media)
            .Include(s => s.Variants).ThenInclude(v => v.ServiceSubCategory)
            .Include(s => s.Questions)
            .Include(s => s.TargetDistricts).ThenInclude(t => t.District).ThenInclude(d => d.State)
            .Include(s => s.BusinessOwnerProfile).ThenInclude(b => b.BusinessAddress)
            .Include(s => s.BusinessOwnerProfile).ThenInclude(b => b.Services).ThenInclude(s => s.ServiceCategory)
            .FirstOrDefaultAsync(
                // The same gate the browse list applies. Reaching a service an admin has not
                // cleared by guessing its id would make the approval step meaningless.
                s => s.Id == request.ServiceId
                    && s.IsActive
                    && s.BusinessOwnerProfile.VerificationStatus == VerificationStatus.Verified,
                cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessService), request.ServiceId);

        return service.ToServiceDetailDto();
    }
}
