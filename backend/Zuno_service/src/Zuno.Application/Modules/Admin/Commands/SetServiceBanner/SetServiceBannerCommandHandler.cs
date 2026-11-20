using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Admin.Commands.SetServiceBanner;

public class SetServiceBannerCommandHandler(IApplicationDbContext dbContext)
    : IRequestHandler<SetServiceBannerCommand, ServiceBannerDto>
{
    public async Task<ServiceBannerDto> Handle(SetServiceBannerCommand request, CancellationToken cancellationToken)
    {
        var service = await dbContext.BusinessServices
            .FirstOrDefaultAsync(s => s.Id == request.ServiceId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessService), request.ServiceId);

        service.BannerPaidUntil = request.PaidUntil;
        await dbContext.SaveChangesAsync(cancellationToken);
        return new ServiceBannerDto(service.Id, service.BannerPaidUntil);
    }
}
