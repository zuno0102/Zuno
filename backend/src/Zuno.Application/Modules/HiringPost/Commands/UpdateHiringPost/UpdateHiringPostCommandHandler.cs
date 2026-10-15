using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.UpdateHiringPost;

/// <summary>
/// Edits an existing hiring post. Most fields are freely editable, but anything a confirmed
/// worker already relied on is protected: the advertised salary can never be lowered, the
/// salary unit can never change, and the headcount can never drop below the number of workers
/// already confirmed. Those three rules are what make a confirmation trustworthy — without them
/// a business could advertise 100 per event, confirm a crew, then quietly rewrite it to 50.
/// </summary>
public class UpdateHiringPostCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IApplicationDbContext dbContext) : IRequestHandler<UpdateHiringPostCommand, HiringPostDto>
{
    public async Task<HiringPostDto> Handle(UpdateHiringPostCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var post = await dbContext.HiringPosts
            .Include(p => p.BusinessOwnerProfile)
            .Include(p => p.Applications).ThenInclude(a => a.WorkerProfile).ThenInclude(wp => wp.User)
            .Include(p => p.Applications).ThenInclude(a => a.SalaryAdjustments)
            .FirstOrDefaultAsync(p => p.Id == request.HiringPostId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.HiringPost), request.HiringPostId);

        if (post.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This hiring post does not belong to your business.");
        }

        var confirmedCount = post.ConfirmedCount;

        // Pending offers count too: a worker weighing an offer is deciding on this exact figure.
        if (post.HasCommittedWorkers)
        {
            if (request.SalaryAmount < post.SalaryAmount)
            {
                var relying = post.PendingOfferCount > 0
                    ? $"{confirmedCount} worker(s) have accepted and {post.PendingOfferCount} are still deciding"
                    : $"{confirmedCount} worker(s) have already accepted";

                throw new DomainException(
                    $"Salary cannot be reduced from {post.SalaryAmount:0.##} to {request.SalaryAmount:0.##} — " +
                    $"{relying} on this post. You may only increase it.");
            }

            if (request.SalaryUnit != post.SalaryUnit)
            {
                throw new DomainException(
                    "The salary unit cannot be changed once workers have been confirmed on this post.");
            }

            // Cutting the head count below the people already hired would leave workers with a
            // place that no longer exists.
            if (request.WorkersNeeded < post.FilledCount)
            {
                throw new DomainException(
                    $"Workers needed cannot be fewer than the {post.FilledCount} worker(s) who have " +
                    "already accepted.");
            }
        }

        post.Title = request.Title;
        post.Description = request.Description;
        post.EventDate = request.EventDate;
        post.DurationMinutes = request.DurationMinutes;
        post.Location = request.Location;
        post.ServiceSubCategoryId = request.ServiceSubCategoryId;
        post.WorkersNeeded = request.WorkersNeeded;
        post.SalaryAmount = request.SalaryAmount;
        post.SalaryUnit = request.SalaryUnit;

        // Raising the head count on a filled post is how it gets reopened to applicants,
        // and lowering it to exactly the confirmed count closes it — no separate action needed.
        post.SyncStatusToStaffing();

        await dbContext.SaveChangesAsync(cancellationToken);

        return post.ToDto();
    }
}
