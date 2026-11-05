using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Application.Modules.Worker.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Commands.SetBusinessUpiId;

public class SetBusinessUpiIdCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IApplicationDbContext dbContext,
    IPlatformSettings platformSettings) : IRequestHandler<SetBusinessUpiIdCommand, BusinessProfileDto>
{
    public async Task<BusinessProfileDto> Handle(SetBusinessUpiIdCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var profile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        profile.UpiId = UpiFormat.Normalize(request.UpiId);
        await dbContext.SaveChangesAsync(cancellationToken);

        return profile.ToDto(platformSettings.Current);
    }
}
