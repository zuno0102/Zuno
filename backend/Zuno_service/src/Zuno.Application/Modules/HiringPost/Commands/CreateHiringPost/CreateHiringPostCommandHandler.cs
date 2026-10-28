using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.Common;
using Zuno.Application.Modules.HiringPost.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.HiringPost.Commands.CreateHiringPost;

public class CreateHiringPostCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IPlatformSettings platformSettings,
    IApplicationDbContext dbContext) : IRequestHandler<CreateHiringPostCommand, HiringPostDto>
{
    public async Task<HiringPostDto> Handle(CreateHiringPostCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        // Hiring against a customer order rather than for the business's own event. Checked here
        // so a post can never point at someone else's booking, or at one that is already over.
        string? inheritedImageUrl = null;
        Guid? inheritedSubCategoryId = null;
        Address? orderAddress = null;

        if (request.BookingId is { } bookingId)
        {
            var booking = await dbContext.Bookings
                .Include(b => b.Address)
                .Include(b => b.BusinessService).ThenInclude(s => s.Media)
                .Include(b => b.BusinessServiceVariant).ThenInclude(v => v!.Media)
                .Include(b => b.BusinessServiceVariant).ThenInclude(v => v!.ServiceSubCategory)
                .FirstOrDefaultAsync(b => b.Id == bookingId, cancellationToken)
                ?? throw new EntityNotFoundException(nameof(Booking), bookingId);

            if (booking.BusinessOwnerProfileId != businessProfile.Id)
            {
                throw new UnauthorizedAccessException(
                    "This booking does not belong to your business.");
            }

            if (booking.BookingStatus is BookingStatus.Completed or BookingStatus.Cancelled)
            {
                throw new DomainException("This booking is closed — you cannot hire for it.");
            }

            // A picture of this work already exists; a post raised from an order borrows it
            // rather than making the business find and upload the same photo again. Uploading a
            // different one afterwards simply overwrites this.
            //
            // The package's own photo first, then the service's. An order is usually for a
            // specific package — "acrylic pouring" — and that picture shows the actual work,
            // where the service's is a picture of the whole trade.
            inheritedImageUrl =
                FirstImage(booking.BusinessServiceVariant?.Media)
                ?? FirstImage(booking.BusinessService.Media);

            // The kind of work is the order's, not something to ask the business again. Taken
            // from the package the customer actually chose.
            inheritedSubCategoryId = booking.BusinessServiceVariant?.ServiceSubCategoryId;

            orderAddress = booking.Address;
        }

        // The order's kind of work wins over anything the client sent: it is the customer's
        // choice of package that decides what the job is, not a field on this form.
        // Loaded rather than merely referenced, so the response names it instead of handing the
        // client a bare id to look up.
        var chosenSubCategoryId = inheritedSubCategoryId ?? request.ServiceSubCategoryId;

        var subCategory = chosenSubCategoryId is { } subCategoryId
            ? await dbContext.ServiceSubCategories
                .FirstOrDefaultAsync(s => s.Id == subCategoryId, cancellationToken)
            : null;

        var post = new Domain.Entities.HiringPost
        {
            BusinessOwnerProfileId = businessProfile.Id,
            BusinessOwnerProfile = businessProfile,
            BookingId = request.BookingId,
            Title = request.Title,
            Description = request.Description,
            ImageUrl = inheritedImageUrl,
            EventDate = request.EventDate,
            DurationMinutes = request.DurationMinutes ?? platformSettings.Current.HiringPostDefaultDurationMinutes,
            Location = string.IsNullOrWhiteSpace(request.Location)
                ? DescribeAddress(orderAddress)
                : request.Location,
            ServiceSubCategoryId = subCategory?.Id,
            ServiceSubCategory = subCategory,
            WorkersNeeded = request.WorkersNeeded,
            SalaryAmount = request.SalaryAmount,
            SalaryUnit = request.SalaryUnit,
        };

        // Where the work is. The order's pinned address wins: the crew goes to the customer's door,
        // and that point was picked on a map by the customer themselves. Otherwise whatever the
        // business picked on this form. Neither leaves the post unplaced, as before.
        if (orderAddress is { Latitude: { } orderLat, Longitude: { } orderLon })
        {
            await HiringPostLocation.PlaceAsync(
                post, orderLat, orderLon, HiringPostLocationPrecision.Pinned, platformSettings.Current, dbContext, cancellationToken);
        }
        else if (request is { Latitude: { } lat, Longitude: { } lon })
        {
            await HiringPostLocation.PlaceAsync(
                post, lat, lon, HiringPostLocation.ParsePrecision(request.LocationPrecision),
                platformSettings.Current, dbContext, cancellationToken);
        }

        dbContext.HiringPosts.Add(post);
        await dbContext.SaveChangesAsync(cancellationToken);

        return post.ToDto();
    }

    /// <summary>The order's address as one line, for the post's free-text location.</summary>
    private static string? DescribeAddress(Address? address)
    {
        if (address is null)
        {
            return null;
        }

        var parts = new[] { address.Line1, address.Line2, address.City, address.State }
            .Where(p => !string.IsNullOrWhiteSpace(p));
        var text = string.Join(", ", parts);
        return text.Length > 300 ? text[..300] : text;
    }

    private static string? FirstImage(ICollection<BusinessServiceMedia>? media) => media
        ?.Where(m => m.MediaType == ServiceMediaType.Image)
        .OrderBy(m => m.SortOrder)
        .Select(m => m.Url)
        .FirstOrDefault();
}
