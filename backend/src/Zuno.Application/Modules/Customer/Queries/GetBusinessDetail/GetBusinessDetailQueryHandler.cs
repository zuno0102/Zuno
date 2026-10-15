using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Customer.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Customer.Queries.GetBusinessDetail;

public class GetBusinessDetailQueryHandler(IApplicationDbContext dbContext)
    : IRequestHandler<GetBusinessDetailQuery, BusinessDetailDto>
{
    public async Task<BusinessDetailDto> Handle(GetBusinessDetailQuery request, CancellationToken cancellationToken)
    {
        var business = await dbContext.BusinessOwnerProfiles
            .Include(bp => bp.BusinessAddress)
            .Include(bp => bp.Services).ThenInclude(s => s.ServiceCategory)
            .Include(bp => bp.Services).ThenInclude(s => s.Media)
            .Include(bp => bp.Services).ThenInclude(s => s.TargetDistricts).ThenInclude(t => t.District).ThenInclude(d => d.State)
            .Include(bp => bp.Services).ThenInclude(s => s.Variants).ThenInclude(v => v.Media)
            .Include(bp => bp.Services).ThenInclude(s => s.Variants).ThenInclude(v => v.ServiceSubCategory)
            .Include(bp => bp.Services).ThenInclude(s => s.Questions)
            .FirstOrDefaultAsync(
                bp => bp.Id == request.BusinessId && bp.VerificationStatus == VerificationStatus.Verified,
                cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), request.BusinessId);

        return business.ToDetailDto();
    }
}
