using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Application.Modules.HiringPost.Events;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.RejectHiringPostApplication;

public class RejectHiringPostApplicationCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<RejectHiringPostApplicationCommand, HiringPostDto>
{
    public async Task<HiringPostDto> Handle(RejectHiringPostApplicationCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var application = await dbContext.HiringPostApplications
            .Include(a => a.HiringPost).ThenInclude(p => p.BusinessOwnerProfile)
            .Include(a => a.HiringPost).ThenInclude(p => p.ServiceSubCategory)
            .Include(a => a.HiringPost).ThenInclude(p => p.Applications).ThenInclude(a => a.WorkerProfile).ThenInclude(wp => wp.User)
            .Include(a => a.HiringPost).ThenInclude(p => p.Applications).ThenInclude(a => a.SalaryAdjustments)
            .FirstOrDefaultAsync(a => a.Id == request.ApplicationId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(HiringPostApplication), request.ApplicationId);

        if (application.HiringPost.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This application does not belong to your business.");
        }

        if (application.ApplicationStatus != HiringPostApplicationStatus.Applied)
        {
            throw new DomainException("This application has already been responded to.");
        }

        application.ApplicationStatus = HiringPostApplicationStatus.Rejected;
        application.RespondedAt = dateTimeProvider.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);

        // Bad news, and still worth sending: without it an applicant keeps the evening free for a
        // job that has already gone to somebody else.
        await publisher.Publish(
            new HiringPostApplicationRejectedEvent(
                application.HiringPostId,
                application.WorkerProfile.UserId,
                application.HiringPost.BusinessOwnerProfile.BusinessName,
                application.HiringPost.Title),
            cancellationToken);

        return application.HiringPost.ToDto();
    }
}
