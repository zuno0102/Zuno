using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Worker.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Worker.Commands.SetWorkerPhoto;

public class SetWorkerPhotoCommandHandler(
    ICurrentUserService currentUserService,
    IWorkerEarningsService earningsService,
    IApplicationDbContext dbContext) : IRequestHandler<SetWorkerPhotoCommand, WorkerProfileDto>
{
    public async Task<WorkerProfileDto> Handle(
        SetWorkerPhotoCommand request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var profile = await dbContext.WorkerProfiles
            .Include(w => w.User)
            .Include(w => w.PayoutDetail)
            .FirstOrDefaultAsync(w => w.UserId == userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(WorkerProfile), userId);

        profile.PhotoUrl = request.Url;

        await dbContext.SaveChangesAsync(cancellationToken);

        var earnings = await earningsService.GetAsync(profile.Id, cancellationToken);
        return profile.ToDto(earnings);
    }
}
