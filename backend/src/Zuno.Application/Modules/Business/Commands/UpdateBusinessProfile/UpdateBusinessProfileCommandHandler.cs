using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Commands.UpdateBusinessProfile;

public class UpdateBusinessProfileCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IApplicationDbContext dbContext) : IRequestHandler<UpdateBusinessProfileCommand, BusinessProfileDto>
{
    public async Task<BusinessProfileDto> Handle(UpdateBusinessProfileCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var profile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        profile.BusinessName = request.BusinessName;
        profile.BusinessType = request.BusinessType;
        profile.GstNumber = request.GstNumber;
        profile.Description = request.Description;

        // LogoUrl is deliberately not touched here — SetBusinessLogoCommand owns it. The edit
        // form posts back whatever profile copy it loaded, so a business that uploaded a picture
        // and then renamed itself would otherwise wipe the picture as a side effect.

        var hasAddressInput = !string.IsNullOrWhiteSpace(request.AddressLine1)
            || !string.IsNullOrWhiteSpace(request.City)
            || !string.IsNullOrWhiteSpace(request.State)
            || !string.IsNullOrWhiteSpace(request.PostalCode);

        if (hasAddressInput)
        {
            var address = profile.BusinessAddress;
            if (address is null)
            {
                address = new Address { OwnerUserId = userId };
                dbContext.Addresses.Add(address);
                profile.BusinessAddress = address;
            }

            address.Label = "Business";
            address.Line1 = request.AddressLine1 ?? address.Line1;
            address.Line2 = request.AddressLine2;
            address.City = request.City ?? address.City;
            address.State = request.State ?? address.State;
            address.PostalCode = request.PostalCode ?? address.PostalCode;
            address.Country = request.Country ?? address.Country;
            address.Latitude = request.Latitude ?? address.Latitude;
            address.Longitude = request.Longitude ?? address.Longitude;
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        return profile.ToDto();
    }
}
