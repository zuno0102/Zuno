using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Customer.Queries.CheckServiceCoverage;

/// <remarks>
/// The same <see cref="ServiceAreaCheck"/> the booking validator runs, so the app's early warning and
/// the server's refusal can never disagree about a pin.
/// </remarks>
public class CheckServiceCoverageQueryHandler(IApplicationDbContext dbContext)
    : IRequestHandler<CheckServiceCoverageQuery, ServiceCoverageDto>
{
    public async Task<ServiceCoverageDto> Handle(
        CheckServiceCoverageQuery request,
        CancellationToken cancellationToken)
    {
        var exists = await dbContext.BusinessServices.AnyAsync(
            s => s.Id == request.ServiceId
                && s.IsActive
                && s.BusinessOwnerProfile.VerificationStatus == VerificationStatus.Verified,
            cancellationToken);
        if (!exists)
        {
            throw new EntityNotFoundException(nameof(BusinessService), request.ServiceId);
        }

        var check = await ServiceAreaCheck.CheckAsync(
            request.ServiceId,
            request.Latitude,
            request.Longitude,
            dbContext,
            cancellationToken);

        return new ServiceCoverageDto(check.IsServed, check.ServedDistrictNames);
    }
}
