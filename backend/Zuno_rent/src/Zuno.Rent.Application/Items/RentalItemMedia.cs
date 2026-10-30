using FluentValidation;
using MediatR;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;

namespace Zuno.Rent.Application.Items;

/// <summary>Puts a photo in one of a rent item's slots, replacing what was there.</summary>
/// <remarks>
/// Carries the photo itself, not a saved URL: the file is written only after the item is known to be
/// the caller's, so nobody can overwrite another business's photo by guessing an id.
/// </remarks>
public class SetRentalItemImageCommand : IRequest<RentalItemDto>
{
    public Guid RentalItemId { get; set; }

    public int SlotIndex { get; set; }

    public Stream Content { get; set; } = Stream.Null;

    /// <summary>Chosen by the server from the file's bytes, with the dot, e.g. <c>.jpg</c>.</summary>
    public string FileExtension { get; set; } = ".jpg";
}

public class RemoveRentalItemImageCommand : IRequest<RentalItemDto>
{
    public Guid RentalItemId { get; set; }

    public int SlotIndex { get; set; }
}

/// <summary>Sets the rent item's one video, replacing any earlier one.</summary>
public class SetRentalItemVideoCommand : IRequest<RentalItemDto>
{
    public Guid RentalItemId { get; set; }

    public Stream Content { get; set; } = Stream.Null;

    /// <summary>Chosen by the server from the file's bytes, with the dot, e.g. <c>.mp4</c>.</summary>
    public string FileExtension { get; set; } = ".mp4";
}

public class RemoveRentalItemVideoCommand : IRequest<RentalItemDto>
{
    public Guid RentalItemId { get; set; }
}

public class SetRentalItemImageCommandValidator : AbstractValidator<SetRentalItemImageCommand>
{
    public SetRentalItemImageCommandValidator(IOptions<RentSettings> settings)
    {
        RuleFor(x => x.RentalItemId).NotEmpty();
        RuleFor(x => x.SlotIndex).InclusiveBetween(0, settings.Value.ImageSlots - 1);
        RuleFor(x => x.FileExtension).NotEmpty().MaximumLength(10);
    }
}

public class RemoveRentalItemImageCommandValidator : AbstractValidator<RemoveRentalItemImageCommand>
{
    public RemoveRentalItemImageCommandValidator(IOptions<RentSettings> settings)
    {
        RuleFor(x => x.RentalItemId).NotEmpty();
        RuleFor(x => x.SlotIndex).InclusiveBetween(0, settings.Value.ImageSlots - 1);
    }
}

public class SetRentalItemVideoCommandValidator : AbstractValidator<SetRentalItemVideoCommand>
{
    public SetRentalItemVideoCommandValidator()
    {
        RuleFor(x => x.RentalItemId).NotEmpty();
        RuleFor(x => x.FileExtension).NotEmpty().MaximumLength(10);
    }
}

public class RemoveRentalItemVideoCommandValidator : AbstractValidator<RemoveRentalItemVideoCommand>
{
    public RemoveRentalItemVideoCommandValidator()
    {
        RuleFor(x => x.RentalItemId).NotEmpty();
    }
}

/// <summary>Adds, replaces and removes a rent item's photos and video, always checking ownership first.</summary>
public class RentalItemMediaHandlers(ICurrentUser currentUser, IRentDbContext dbContext, IRentMediaStorage storage) :
    IRequestHandler<SetRentalItemImageCommand, RentalItemDto>,
    IRequestHandler<RemoveRentalItemImageCommand, RentalItemDto>,
    IRequestHandler<SetRentalItemVideoCommand, RentalItemDto>,
    IRequestHandler<RemoveRentalItemVideoCommand, RentalItemDto>
{
    public async Task<RentalItemDto> Handle(SetRentalItemImageCommand request, CancellationToken cancellationToken)
    {
        var item = await dbContext.OwnedItemAsync(request.RentalItemId, currentUser.OwnerId(), cancellationToken);
        var url = await storage.SaveImageAsync(
            item.Id, request.SlotIndex, request.Content, request.FileExtension, cancellationToken);

        return await PutAsync(item, RentalMediaType.Image, (short)request.SlotIndex, url, cancellationToken);
    }

    public async Task<RentalItemDto> Handle(RemoveRentalItemImageCommand request, CancellationToken cancellationToken)
    {
        var item = await dbContext.OwnedItemAsync(request.RentalItemId, currentUser.OwnerId(), cancellationToken);
        return await RemoveAsync(item, RentalMediaType.Image, (short)request.SlotIndex, cancellationToken);
    }

    public async Task<RentalItemDto> Handle(SetRentalItemVideoCommand request, CancellationToken cancellationToken)
    {
        var item = await dbContext.OwnedItemAsync(request.RentalItemId, currentUser.OwnerId(), cancellationToken);
        var url = await storage.SaveVideoAsync(item.Id, request.Content, request.FileExtension, cancellationToken);

        return await PutAsync(item, RentalMediaType.Video, 0, url, cancellationToken);
    }

    public async Task<RentalItemDto> Handle(RemoveRentalItemVideoCommand request, CancellationToken cancellationToken)
    {
        var item = await dbContext.OwnedItemAsync(request.RentalItemId, currentUser.OwnerId(), cancellationToken);
        return await RemoveAsync(item, RentalMediaType.Video, 0, cancellationToken);
    }

    private async Task<RentalItemDto> PutAsync(
        RentalItem item, RentalMediaType type, short sortOrder, string url, CancellationToken cancellationToken)
    {
        var existing = item.Media.FirstOrDefault(m => m.MediaType == type && m.SortOrder == sortOrder);

        if (existing != null)
        {
            existing.Url = url;
        }
        else
        {
            // On the DbSet: its Guid key is preset, so found only through the collection EF would take
            // it for an existing row and send an UPDATE for a row that is not there.
            var media = new RentalItemMedia { RentalItemId = item.Id, RentalItem = item, MediaType = type, SortOrder = sortOrder, Url = url };
            dbContext.RentalItemMedia.Add(media);
            item.Media.AddIfMissing(media);
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        return item.ToDto();
    }

    private async Task<RentalItemDto> RemoveAsync(
        RentalItem item, RentalMediaType type, short sortOrder, CancellationToken cancellationToken)
    {
        var existing = item.Media.FirstOrDefault(m => m.MediaType == type && m.SortOrder == sortOrder);

        // Removing an empty slot is not an error: the screen already shows what the caller wants.
        if (existing != null)
        {
            item.Media.Remove(existing);
            dbContext.RentalItemMedia.Remove(existing);
            await dbContext.SaveChangesAsync(cancellationToken);

            storage.Delete(existing.Url);
        }

        return item.ToDto();
    }
}
