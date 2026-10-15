using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Application.Modules.Business.Events;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Commands.InviteWorker;

public class InviteWorkerCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessWorkerRepository businessWorkerRepository,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<InviteWorkerCommand, BusinessWorkerDto>
{
    public async Task<BusinessWorkerDto> Handle(InviteWorkerCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var workerProfile = await dbContext.WorkerProfiles
            .Include(wp => wp.User)
            .FirstOrDefaultAsync(
                wp => wp.User.Email == request.WorkerIdentifier || wp.User.PhoneNumber == request.WorkerIdentifier,
                cancellationToken)
            ?? throw new EntityNotFoundException(nameof(WorkerProfile), request.WorkerIdentifier);

        var now = dateTimeProvider.UtcNow;
        var existing = await businessWorkerRepository.GetByBusinessAndWorkerAsync(
            businessProfile.Id, workerProfile.Id, cancellationToken);

        BusinessWorker businessWorker;
        if (existing is not null)
        {
            if (existing.AssignmentStatus is BusinessWorkerStatus.Invited or BusinessWorkerStatus.Active)
            {
                throw new DomainException("This worker is already invited or active for your business.");
            }

            existing.AssignmentStatus = BusinessWorkerStatus.Invited;
            existing.InvitedAt = now;
            existing.RespondedAt = null;
            existing.WorkerProfile = workerProfile;
            businessWorker = existing;
        }
        else
        {
            businessWorker = new BusinessWorker
            {
                BusinessOwnerProfileId = businessProfile.Id,
                WorkerProfileId = workerProfile.Id,
                WorkerProfile = workerProfile,
                AssignmentStatus = BusinessWorkerStatus.Invited,
                InvitedAt = now,
            };
            businessWorkerRepository.Add(businessWorker);
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        await publisher.Publish(
            new WorkerInvitedEvent(
                businessWorker.Id,
                workerProfile.UserId,
                workerProfile.User.Email,
                businessProfile.BusinessName),
            cancellationToken);

        return businessWorker.ToDto();
    }
}
