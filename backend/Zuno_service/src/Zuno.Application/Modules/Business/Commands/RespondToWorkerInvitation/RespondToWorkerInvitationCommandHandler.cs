using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Commands.RespondToWorkerInvitation;

public class RespondToWorkerInvitationCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBusinessWorkerRepository businessWorkerRepository,
    IApplicationDbContext dbContext) : IRequestHandler<RespondToWorkerInvitationCommand, WorkerInvitationDto>
{
    public async Task<WorkerInvitationDto> Handle(RespondToWorkerInvitationCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessWorker = await businessWorkerRepository.GetByIdAsync(request.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessWorker), request.Id);

        if (businessWorker.WorkerProfile.UserId != userId)
        {
            throw new UnauthorizedAccessException("This invitation does not belong to you.");
        }

        if (businessWorker.AssignmentStatus != BusinessWorkerStatus.Invited)
        {
            throw new DomainException("This invitation has already been responded to.");
        }

        businessWorker.AssignmentStatus = request.Accept ? BusinessWorkerStatus.Active : BusinessWorkerStatus.Rejected;
        businessWorker.RespondedAt = dateTimeProvider.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);

        return businessWorker.ToInvitationDto();
    }
}
