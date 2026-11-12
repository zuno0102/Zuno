using FluentValidation;
using MediatR;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;

namespace Zuno.Marketplace.Application.Posts;

/// <summary>Pauses, re-opens or closes a post — only along a move in the transitions table.</summary>
public class ChangeMarketplacePostStatusCommand : IRequest<MarketplacePostDto>
{
    public Guid Id { get; set; }

    /// <summary><c>Active</c>, <c>Paused</c>, <c>Closed</c> or <c>Sold</c>.</summary>
    public string Status { get; set; } = string.Empty;
}

/// <summary>Takes a post off the business's list. The row is kept, marked deleted.</summary>
public class DeleteMarketplacePostCommand : IRequest
{
    public Guid Id { get; set; }
}

/// <summary>Puts a photo in one of a post's slots, replacing what was there.</summary>
/// <remarks>Carries the photo itself: the file is written only after the post is known to be the caller's.</remarks>
public class SetMarketplacePostImageCommand : IRequest<MarketplacePostDto>
{
    public Guid PostId { get; set; }

    public int SlotIndex { get; set; }

    public Stream Content { get; set; } = Stream.Null;

    /// <summary>Chosen by the server from the file's bytes, with the dot, e.g. <c>.jpg</c>.</summary>
    public string FileExtension { get; set; } = ".jpg";
}

public class RemoveMarketplacePostImageCommand : IRequest<MarketplacePostDto>
{
    public Guid PostId { get; set; }

    public int SlotIndex { get; set; }
}

public class ChangeMarketplacePostStatusCommandValidator : AbstractValidator<ChangeMarketplacePostStatusCommand>
{
    public ChangeMarketplacePostStatusCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.Status)
            .Must(s => Enum.TryParse<MarketplacePostStatus>(s, true, out var v) && Enum.IsDefined(v) && v != MarketplacePostStatus.Expired)
            .WithMessage("Status must be Active, Paused, Closed or Sold.");
    }
}

public class DeleteMarketplacePostCommandValidator : AbstractValidator<DeleteMarketplacePostCommand>
{
    public DeleteMarketplacePostCommandValidator() => RuleFor(x => x.Id).NotEmpty();
}

public class SetMarketplacePostImageCommandValidator : AbstractValidator<SetMarketplacePostImageCommand>
{
    public SetMarketplacePostImageCommandValidator(IOptions<MarketplaceSettings> settings)
    {
        RuleFor(x => x.PostId).NotEmpty();
        RuleFor(x => x.SlotIndex).InclusiveBetween(0, settings.Value.ImageSlots - 1);
        RuleFor(x => x.FileExtension).NotEmpty().MaximumLength(10);
    }
}

public class RemoveMarketplacePostImageCommandValidator : AbstractValidator<RemoveMarketplacePostImageCommand>
{
    public RemoveMarketplacePostImageCommandValidator(IOptions<MarketplaceSettings> settings)
    {
        RuleFor(x => x.PostId).NotEmpty();
        RuleFor(x => x.SlotIndex).InclusiveBetween(0, settings.Value.ImageSlots - 1);
    }
}

/// <summary>Status, removal and photos of a business's own post — ownership checked first every time.</summary>
public class ManageMarketplacePostHandlers(
    ICurrentUser currentUser,
    IMarketplaceDbContext dbContext,
    IMarketplaceMediaStorage storage,
    MarketplaceReference reference,
    TimeProvider clock) :
    IRequestHandler<ChangeMarketplacePostStatusCommand, MarketplacePostDto>,
    IRequestHandler<DeleteMarketplacePostCommand>,
    IRequestHandler<SetMarketplacePostImageCommand, MarketplacePostDto>,
    IRequestHandler<RemoveMarketplacePostImageCommand, MarketplacePostDto>
{
    public async Task<MarketplacePostDto> Handle(ChangeMarketplacePostStatusCommand request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var now = clock.GetUtcNow();
        var target = Enum.Parse<MarketplacePostStatus>(request.Status, ignoreCase: true);
        var post = await dbContext.OwnedPostAsync(request.Id, ownerId, cancellationToken);
        var transitions = await reference.TransitionsAsync(cancellationToken);

        if (post.Status == target)
        {
            return post.ToDto(now, transitions);
        }

        if (target == MarketplacePostStatus.Sold && post.Condition != MarketplaceItemCondition.Used)
        {
            throw new DomainException("Only a used item is marked sold. A new one keeps a stock count: set it to 0 when it runs out.");
        }

        if (!transitions.Any(t => t.AppliesTo(post) && t.ToStatus == target))
        {
            throw new DomainException($"A {post.Status} post cannot be moved to {target}.");
        }

        if (target == MarketplacePostStatus.Active && post.HasEnded(now))
        {
            throw new DomainException("This post has ended. Edit its dates to put it up again.");
        }

        return await dbContext.WithOwnerLockAsync(ownerId, async () =>
        {
            if (target == MarketplacePostStatus.Active)
            {
                await dbContext.EnsureRoomAsync(ownerId, post.Id, now, cancellationToken);
            }

            post.Status = target;
            await dbContext.SaveChangesAsync(cancellationToken);
            return post.ToDto(now, transitions);
        }, cancellationToken);
    }

    public async Task Handle(DeleteMarketplacePostCommand request, CancellationToken cancellationToken)
    {
        var post = await dbContext.OwnedPostAsync(request.Id, currentUser.OwnerId(), cancellationToken);

        // Soft: the row stays, marked deleted, so a later enquiry or reservation can still name it.
        dbContext.Posts.Remove(post);
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<MarketplacePostDto> Handle(SetMarketplacePostImageCommand request, CancellationToken cancellationToken)
    {
        var post = await dbContext.OwnedPostAsync(request.PostId, currentUser.OwnerId(), cancellationToken);
        var url = await storage.SaveImageAsync(post.Id, request.SlotIndex, request.Content, request.FileExtension, cancellationToken);
        var sortOrder = (short)request.SlotIndex;

        var existing = post.Media.FirstOrDefault(m => m.SortOrder == sortOrder);
        if (existing is not null)
        {
            existing.Url = url;
        }
        else
        {
            // On the DbSet: its Guid key is preset, so found only through the collection EF would take
            // it for an existing row and send an UPDATE for a row that is not there.
            var media = new MarketplacePostMedia { PostId = post.Id, Post = post, SortOrder = sortOrder, Url = url };
            dbContext.PostMedia.Add(media);
            post.Media.AddIfMissing(media);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return post.ToDto(clock.GetUtcNow(), await reference.TransitionsAsync(cancellationToken));
    }

    public async Task<MarketplacePostDto> Handle(RemoveMarketplacePostImageCommand request, CancellationToken cancellationToken)
    {
        var post = await dbContext.OwnedPostAsync(request.PostId, currentUser.OwnerId(), cancellationToken);
        var existing = post.Media.FirstOrDefault(m => m.SortOrder == request.SlotIndex);

        // Removing an empty slot is not an error: the screen already shows what the caller wants.
        if (existing is not null)
        {
            post.Media.Remove(existing);
            dbContext.PostMedia.Remove(existing);
            await dbContext.SaveChangesAsync(cancellationToken);
            storage.Delete(existing.Url);
        }

        return post.ToDto(clock.GetUtcNow(), await reference.TransitionsAsync(cancellationToken));
    }
}
