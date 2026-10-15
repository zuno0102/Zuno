using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Commands.RemoveBusinessWorker;

public class RemoveBusinessWorkerCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessWorkerRepository businessWorkerRepository,
    IApplicationDbContext dbContext) : IRequestHandler<RemoveBusinessWorkerCommand>
{
    public async Task Handle(RemoveBusinessWorkerCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var businessWorker = await businessWorkerRepository.GetByIdAsync(request.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessWorker), request.Id);

        if (businessWorker.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This worker does not belong to your business.");
        }

        businessWorker.AssignmentStatus = BusinessWorkerStatus.Removed;
        businessWorker.RespondedAt = dateTimeProvider.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
