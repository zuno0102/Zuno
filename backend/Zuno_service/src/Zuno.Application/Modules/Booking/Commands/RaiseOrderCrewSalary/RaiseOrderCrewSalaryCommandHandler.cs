using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Application.Modules.HiringPost.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Booking.Commands.RaiseOrderCrewSalary;

/// <summary>
/// Raises everyone on an order who is still to be paid by the same amount. A crew comes from two
/// places — added to the order directly, or hired through its post — and both are raised here, in
/// one save, so the business never ends up with half a crew on the new rate.
/// </summary>
public class RaiseOrderCrewSalaryCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBookingRepository bookingRepository,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<RaiseOrderCrewSalaryCommand, BookingDto>
{
    public async Task<BookingDto> Handle(RaiseOrderCrewSalaryCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var booking = await bookingRepository.GetByIdAsync(request.BookingId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.Booking), request.BookingId);

        if (booking.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This booking does not belong to your business.");
        }

        // Added directly: the wage sits on the assignment. A post hire's assignment carries no
        // wage, so nobody is raised twice.
        var direct = booking.WorkerAssignments.Where(a => a.CanRaiseSalary).ToList();
        foreach (var assignment in direct)
        {
            dbContext.BookingAssignmentSalaryAdjustments.Add(assignment.RaiseSalary(request.Increase, request.Reason));
        }

        var posts = await dbContext.LoadHiringPostsAsync(
            dbContext.HiringPosts.Where(p => p.BookingId == booking.Id),
            cancellationToken);

        var raisedHires = new List<(Domain.Entities.HiringPost Post, List<HiringPostApplication> Hires)>();
        foreach (var post in posts)
        {
            var hires = await CrewRaise.RaisePostHiresAsync(post, request.Increase, request.Reason, dbContext, cancellationToken);
            raisedHires.Add((post, hires));
        }

        if (direct.Count == 0 && raisedHires.All(r => r.Hires.Count == 0))
        {
            throw new DomainException("Nobody on this job is waiting to be paid, so there is no wage to raise.");
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        foreach (var (post, hires) in raisedHires)
        {
            await CrewRaise.NotifyAsync(post, hires, publisher, cancellationToken);
        }

        return booking.ToDto(includeCrew: true);
    }
}
