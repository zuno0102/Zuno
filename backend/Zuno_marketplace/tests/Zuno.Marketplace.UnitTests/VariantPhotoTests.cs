using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Application.Posts;
using Zuno.Marketplace.Domain.Exceptions;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.UnitTests;

/// <summary>
/// A colour / size has photos of its own — the saree in that colour — apart from the product's, in
/// its own few slots, gone with it when it is taken off.
/// </summary>
public class VariantPhotoTests
{
    private static CreateMarketplacePostCommand Saree() =>
        TestMarketplace.Car(c =>
        {
            c.SubCategoryId = MarketplaceCatalogSeedData.SubId(3, 1);
            c.Title = "Silk saree";
            c.Price = 2_400m;
            c.Condition = "New";
            c.Attributes = new();
            c.Variants =
            [
                new() { Colour = "Red", Price = 2_400m, Stock = 10 },
                new() { Colour = "Green", Price = 2_400m, Stock = 3 },
            ];
        });

    private static SetMarketplacePostImageCommand Photo(Guid postId, Guid? variantId, int slot) =>
        new() { PostId = postId, VariantId = variantId, SlotIndex = slot };

    [Fact]
    public async Task AColoursPhoto_IsItsOwn_AndNeverReplacesTheProductsCover()
    {
        using var test = new TestMarketplace();
        var saree = await test.SaveHandlers.Handle(Saree(), default);
        var green = saree.Variants.Single(v => v.Colour == "Green");

        await test.ManageHandlers.Handle(Photo(saree.Id, null, 0), default);
        var dto = await test.ManageHandlers.Handle(Photo(saree.Id, green.Id, 0), default);

        dto.Media.Should().ContainSingle().Which.Url.Should().Be(test.Storage.Saved[0], "the cover stays the cover");
        dto.Variants.Single(v => v.Id == green.Id).Media.Should().ContainSingle()
            .Which.Url.Should().Be(test.Storage.Saved[1]);
        test.Storage.Saved[1].Should().Contain($"variant-{green.Id:N}-0", "its file is named apart");
        dto.Variants.Single(v => v.Colour == "Red").Media.Should().BeEmpty();
    }

    [Fact]
    public async Task AColoursPhoto_IsReplaced_AndRemoved_InItsSlot()
    {
        using var test = new TestMarketplace();
        var saree = await test.SaveHandlers.Handle(Saree(), default);
        var green = saree.Variants.Single(v => v.Colour == "Green");

        await test.ManageHandlers.Handle(Photo(saree.Id, green.Id, 1), default);
        var replaced = await test.ManageHandlers.Handle(Photo(saree.Id, green.Id, 1), default);
        replaced.Variants.Single(v => v.Id == green.Id).Media.Should().ContainSingle()
            .Which.Url.Should().Be(test.Storage.Saved[1]);

        var removed = await test.ManageHandlers.Handle(
            new RemoveMarketplacePostImageCommand { PostId = saree.Id, VariantId = green.Id, SlotIndex = 1 }, default);

        removed.Variants.Single(v => v.Id == green.Id).Media.Should().BeEmpty();
        test.Storage.Deleted.Should().Equal(test.Storage.Saved[1]);
    }

    [Fact]
    public async Task AColourOfAnotherPost_IsNotFound_AndNoFileIsWritten()
    {
        using var test = new TestMarketplace();
        var free = await test.Db.Plans.SingleAsync(p => p.IsDefault);
        free.MaxActivePosts = 2;
        await test.Db.SaveChangesAsync();
        var mine = await test.SaveHandlers.Handle(Saree(), default);
        var other = await test.SaveHandlers.Handle(Saree(), default);
        var othersGreen = other.Variants.Single(v => v.Colour == "Green");

        var act = () => test.ManageHandlers.Handle(Photo(mine.Id, othersGreen.Id, 0), default);

        await act.Should().ThrowAsync<EntityNotFoundException>();
        test.Storage.Saved.Should().BeEmpty();
    }

    [Fact]
    public async Task AColourOnAnotherBusinesssPost_IsForbidden()
    {
        using var test = new TestMarketplace();
        var saree = await test.SaveHandlers.Handle(Saree(), default);
        var green = saree.Variants.Single(v => v.Colour == "Green");

        var act = () => test.As(TestMarketplace.OwnerB).ManageHandlers.Handle(Photo(saree.Id, green.Id, 0), default);

        await act.Should().ThrowAsync<ForbiddenException>();
        test.Storage.Saved.Should().BeEmpty();
    }

    [Fact]
    public async Task TakingAColourOff_TakesItsPhotosWithIt()
    {
        using var test = new TestMarketplace();
        var saree = await test.SaveHandlers.Handle(Saree(), default);
        var red = saree.Variants.Single(v => v.Colour == "Red");
        var green = saree.Variants.Single(v => v.Colour == "Green");
        await test.ManageHandlers.Handle(Photo(saree.Id, null, 0), default);
        await test.ManageHandlers.Handle(Photo(saree.Id, green.Id, 0), default);

        var dto = await test.VariantsHandler.Handle(new ReplaceMarketplacePostVariantsCommand
        {
            Id = saree.Id,
            Variants = [new() { Id = red.Id, Colour = "Red", Price = 2_400m, Stock = 10 }],
        }, default);

        dto.Variants.Should().ContainSingle();
        dto.Media.Should().ContainSingle("the product's own photo stays");
        test.Storage.Deleted.Should().Equal(test.Storage.Saved[1]);
    }

    [Theory]
    [InlineData(3)]
    [InlineData(-1)]
    public void AColourHasFewerSlotsThanThePost(int slot)
    {
        var validator = new SetMarketplacePostImageCommandValidator(Options.Create(new MarketplaceSettings()));

        validator.Validate(Photo(Guid.NewGuid(), Guid.NewGuid(), slot)).IsValid.Should().BeFalse();
        validator.Validate(Photo(Guid.NewGuid(), null, 3)).IsValid.Should().BeTrue("the post itself has 5");
        validator.Validate(Photo(Guid.NewGuid(), Guid.NewGuid(), 2)).IsValid.Should().BeTrue();
    }
}
