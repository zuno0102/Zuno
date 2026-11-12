using FluentAssertions;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Application.Posts;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.UnitTests;

public class PostHandlerTests
{
    private static ChangeMarketplacePostStatusCommand Move(Guid id, MarketplacePostStatus to) => new() { Id = id, Status = to.ToString() };

    [Fact]
    public async Task Create_ValidCar_SavesActivePostOfTheCaller()
    {
        using var test = new TestMarketplace();

        var dto = await test.SaveHandlers.Handle(TestMarketplace.Car(), default);

        dto.Status.Should().Be("Active");
        dto.Kind.Should().Be("Listing");
        dto.CategoryName.Should().Be("Products");
        dto.SubCategoryName.Should().Be("Vehicles");
        dto.DistrictName.Should().Be("Kanyakumari");
        dto.Attributes.Should().ContainKey("km_driven").WhoseValue.Should().Be("48000");
        dto.Actions.Select(a => a.ToStatus).Should().Equal("Paused", "Closed", "Sold");
        var saved = await test.NewContext().Posts.SingleAsync();
        saved.OwnerUserId.Should().Be(TestMarketplace.OwnerA);
        saved.CreatedBy.Should().Be(TestMarketplace.OwnerA);
    }

    [Fact]
    public async Task Create_ListingWithTimes_DropsThem()
    {
        using var test = new TestMarketplace();

        var dto = await test.SaveHandlers.Handle(
            TestMarketplace.Car(c => { c.StartsAt = test.Now; c.EndsAt = test.Now.AddHours(1); c.OriginalPrice = 1; c.ContactPhone = "9876543210"; }),
            default);

        dto.StartsAt.Should().BeNull();
        dto.EndsAt.Should().BeNull();
        dto.OriginalPrice.Should().BeNull();
        dto.ContactPhone.Should().BeNull();
    }

    [Fact]
    public async Task Create_SecondLivePostOnFreePlan_IsRefusedAndNothingSaved()
    {
        using var test = new TestMarketplace();
        await test.SaveHandlers.Handle(TestMarketplace.Car(), default);

        var act = () => test.SaveHandlers.Handle(test.Biryani(), default);

        (await act.Should().ThrowAsync<DomainException>()).WithMessage("Your Free plan allows 1 active post.*");
        (await test.NewContext().Posts.CountAsync()).Should().Be(1);
    }

    [Fact]
    public async Task Create_WhenOtherPostPaused_IsAllowed()
    {
        using var test = new TestMarketplace();
        test.Seed(p => p.Status = MarketplacePostStatus.Paused);

        var dto = await test.SaveHandlers.Handle(test.Biryani(), default);

        dto.Status.Should().Be("Active");
    }

    [Theory]
    [InlineData(MarketplacePostStatus.Closed)]
    [InlineData(MarketplacePostStatus.Expired)]
    public async Task Create_WhenOtherPostClosedOrEnded_IsAllowed(MarketplacePostStatus other)
    {
        using var test = new TestMarketplace();
        test.Seed(p =>
        {
            p.Status = other == MarketplacePostStatus.Closed ? MarketplacePostStatus.Closed : MarketplacePostStatus.Active;
            p.EndsAt = other == MarketplacePostStatus.Expired ? test.Now.AddMinutes(-1) : null;
        });

        (await test.SaveHandlers.Handle(TestMarketplace.Car(), default)).Status.Should().Be("Active");
    }

    [Fact]
    public async Task Create_OtherBusinessesPosts_DoNotUseMySlot()
    {
        using var test = new TestMarketplace();
        test.Seed(p => p.OwnerUserId = TestMarketplace.OwnerB);

        (await test.SaveHandlers.Handle(TestMarketplace.Car(), default)).Status.Should().Be("Active");
    }

    [Fact]
    public async Task Create_DeletedPost_DoesNotUseASlot()
    {
        using var test = new TestMarketplace();
        var post = await test.SaveHandlers.Handle(TestMarketplace.Car(), default);
        await test.ManageHandlers.Handle(new DeleteMarketplacePostCommand { Id = post.Id }, default);

        (await test.SaveHandlers.Handle(test.Biryani(), default)).Status.Should().Be("Active");
    }

    [Fact]
    public async Task Create_OnTakenPlanWithMoreSlots_AllowsMore()
    {
        using var test = new TestMarketplace();
        var gold = new MarketplacePlan { Code = "gold", Name = "Gold", Price = 499, MaxActivePosts = 3, DurationDays = 30 };
        test.Db.Plans.Add(gold);
        test.Db.BusinessPlans.Add(new MarketplaceBusinessPlan
        {
            OwnerUserId = TestMarketplace.OwnerA,
            PlanId = gold.Id,
            StartsAt = test.Now.AddDays(-1),
            EndsAt = test.Now.AddDays(29),
        });
        await test.Db.SaveChangesAsync();

        await test.SaveHandlers.Handle(TestMarketplace.Car(), default);
        await test.SaveHandlers.Handle(test.Biryani(), default);
        await test.SaveHandlers.Handle(test.AadiSale(), default);
        var fourth = () => test.SaveHandlers.Handle(TestMarketplace.Bananas(), default);

        (await fourth.Should().ThrowAsync<DomainException>()).WithMessage("Your Gold plan allows 3 active posts.*");
    }

    [Fact]
    public async Task Create_TakenPlanHasEnded_FallsBackToFree()
    {
        using var test = new TestMarketplace();
        var gold = new MarketplacePlan { Code = "gold", Name = "Gold", Price = 499, MaxActivePosts = 3, DurationDays = 30 };
        test.Db.Plans.Add(gold);
        test.Db.BusinessPlans.Add(new MarketplaceBusinessPlan
        {
            OwnerUserId = TestMarketplace.OwnerA,
            PlanId = gold.Id,
            StartsAt = test.Now.AddDays(-31),
            EndsAt = test.Now.AddDays(-1),
        });
        await test.Db.SaveChangesAsync();
        await test.SaveHandlers.Handle(TestMarketplace.Car(), default);

        var second = () => test.SaveHandlers.Handle(test.Biryani(), default);

        await second.Should().ThrowAsync<DomainException>().WithMessage("Your Free plan*");
    }

    [Fact]
    public async Task Create_FreePlanLimitRaisedInTable_AllowsMore()
    {
        using var test = new TestMarketplace();
        var free = await test.Db.Plans.SingleAsync(p => p.IsDefault);
        free.MaxActivePosts = 2;
        await test.Db.SaveChangesAsync();

        await test.SaveHandlers.Handle(TestMarketplace.Car(), default);

        (await test.SaveHandlers.Handle(test.Biryani(), default)).Status.Should().Be("Active");
    }

    [Fact]
    public async Task Create_SwitchedOffCategory_IsAValidationError()
    {
        using var test = new TestMarketplace();
        var vehicles = await test.Db.Categories.SingleAsync(c => c.Id == MarketplaceCatalogSeedData.Products);
        vehicles.IsActive = false;
        await test.Db.SaveChangesAsync();

        var act = () => test.SaveHandlers.Handle(TestMarketplace.Car(), default);

        (await act.Should().ThrowAsync<ValidationException>()).Which.Errors.Should().ContainSingle(e => e.PropertyName == "CategoryId");
    }

    [Fact]
    public async Task Create_UnknownCategoryOrDistrict_IsAValidationError()
    {
        using var test = new TestMarketplace();

        var unknownCategory = () => test.SaveHandlers.Handle(TestMarketplace.Car(c => c.CategoryId = Guid.NewGuid()), default);
        var unknownDistrict = () => test.SaveHandlers.Handle(TestMarketplace.Car(c => c.DistrictId = Guid.NewGuid()), default);

        (await unknownCategory.Should().ThrowAsync<ValidationException>()).Which.Errors.Should().ContainSingle(e => e.PropertyName == "CategoryId");
        (await unknownDistrict.Should().ThrowAsync<ValidationException>()).Which.Errors.Should().ContainSingle(e => e.PropertyName == "DistrictId");
    }

    [Fact]
    public async Task Create_NotSignedIn_IsUnauthorized()
    {
        using var test = new TestMarketplace();
        test.User.UserId = null;

        var act = () => test.SaveHandlers.Handle(TestMarketplace.Car(), default);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Fact]
    public async Task Update_ChangesTheFields_AndKeepsTheOwner()
    {
        using var test = new TestMarketplace();
        var post = await test.SaveHandlers.Handle(TestMarketplace.Car(), default);
        var update = new UpdateMarketplacePostCommand { Id = post.Id };
        CopyCar(update, c => { c.Price = 400_000m; c.Attributes["km_driven"] = "50000"; });

        var dto = await test.SaveHandlers.Handle(update, default);

        dto.Price.Should().Be(400_000m);
        dto.Attributes["km_driven"].Should().Be("50000");
        (await test.NewContext().Posts.SingleAsync()).ModifiedBy.Should().Be(TestMarketplace.OwnerA);
    }

    [Fact]
    public async Task Update_AnotherBusinessesPost_IsForbidden()
    {
        using var test = new TestMarketplace();
        var post = await test.SaveHandlers.Handle(TestMarketplace.Car(), default);
        test.As(TestMarketplace.OwnerB);
        var update = new UpdateMarketplacePostCommand { Id = post.Id };
        CopyCar(update);

        var act = () => test.SaveHandlers.Handle(update, default);

        await act.Should().ThrowAsync<ForbiddenException>();
    }

    [Fact]
    public async Task Update_MissingPost_IsNotFound()
    {
        using var test = new TestMarketplace();
        var update = new UpdateMarketplacePostCommand { Id = Guid.NewGuid() };
        CopyCar(update);

        var act = () => test.SaveHandlers.Handle(update, default);

        await act.Should().ThrowAsync<EntityNotFoundException>();
    }

    [Fact]
    public async Task Update_ClosedPost_IsRefused()
    {
        using var test = new TestMarketplace();
        var post = test.Seed(p => p.Status = MarketplacePostStatus.Closed);
        var update = new UpdateMarketplacePostCommand { Id = post.Id };
        CopyCar(update);

        var act = () => test.SaveHandlers.Handle(update, default);

        await act.Should().ThrowAsync<DomainException>().WithMessage("A closed or sold post cannot be changed.");
    }

    [Fact]
    public async Task Update_EndedFoodOfferGivenNewTimes_NeedsAFreeSlot()
    {
        using var test = new TestMarketplace();
        var food = await test.SaveHandlers.Handle(test.Biryani(), default);
        test.Clock.Current = test.Now.AddHours(3);
        await test.SaveHandlers.Handle(TestMarketplace.Car(), default);
        var revive = new UpdateMarketplacePostCommand { Id = food.Id };
        CopyFood(revive, test);

        var act = () => test.SaveHandlers.Handle(revive, default);

        await act.Should().ThrowAsync<DomainException>().WithMessage("*allows 1 active post*");
    }

    [Fact]
    public async Task Status_PauseThenPutUpAgain_Works()
    {
        using var test = new TestMarketplace();
        var post = await test.SaveHandlers.Handle(TestMarketplace.Car(), default);

        (await test.ManageHandlers.Handle(Move(post.Id, MarketplacePostStatus.Paused), default)).Status.Should().Be("Paused");
        var back = await test.ManageHandlers.Handle(Move(post.Id, MarketplacePostStatus.Active), default);

        back.Status.Should().Be("Active");
    }

    [Fact]
    public async Task Status_PutUpAgainWhenSlotTaken_IsRefused()
    {
        using var test = new TestMarketplace();
        var paused = test.Seed(p => p.Status = MarketplacePostStatus.Paused);
        await test.SaveHandlers.Handle(test.Biryani(), default);

        var act = () => test.ManageHandlers.Handle(Move(paused.Id, MarketplacePostStatus.Active), default);

        await act.Should().ThrowAsync<DomainException>().WithMessage("*allows 1 active post*");
        (await test.NewContext().Posts.FindAsync(paused.Id))!.Status.Should().Be(MarketplacePostStatus.Paused);
    }

    [Theory]
    [InlineData(MarketplacePostStatus.Closed, MarketplacePostStatus.Active)]
    [InlineData(MarketplacePostStatus.Closed, MarketplacePostStatus.Paused)]
    public async Task Status_MoveNotInTheTable_IsRefused(MarketplacePostStatus from, MarketplacePostStatus to)
    {
        using var test = new TestMarketplace();
        var post = test.Seed(p => p.Status = from);

        var act = () => test.ManageHandlers.Handle(Move(post.Id, to), default);

        await act.Should().ThrowAsync<DomainException>().WithMessage($"A {from} post cannot be moved to {to}.");
    }

    [Fact]
    public async Task Status_SameAsNow_ChangesNothing()
    {
        using var test = new TestMarketplace();
        var post = test.Seed();

        (await test.ManageHandlers.Handle(Move(post.Id, MarketplacePostStatus.Active), default)).Status.Should().Be("Active");
    }

    [Fact]
    public async Task Status_PutUpAgainAfterItEnded_AsksForNewDates()
    {
        using var test = new TestMarketplace();
        var post = test.Seed(p => { p.Status = MarketplacePostStatus.Paused; p.EndsAt = test.Now.AddMinutes(-5); });

        var act = () => test.ManageHandlers.Handle(Move(post.Id, MarketplacePostStatus.Active), default);

        await act.Should().ThrowAsync<DomainException>().WithMessage("This post has ended.*");
    }

    [Fact]
    public async Task Status_EndedPost_ShowsExpiredAndOffersOnlyPauseAndClose()
    {
        using var test = new TestMarketplace();
        var post = await test.SaveHandlers.Handle(test.Biryani(), default);
        test.Clock.Current = test.Now.AddHours(2);

        var page = await test.QueryHandlers.Handle(new GetMyMarketplacePostsQuery(), default);

        var shown = page.Items.Single(p => p.Id == post.Id);
        shown.Status.Should().Be("Expired");
        shown.Actions.Select(a => a.ToStatus).Should().Equal("Paused", "Closed");
    }

    [Fact]
    public async Task Status_PausedPostThatEnded_DoesNotOfferPutUpAgain()
    {
        using var test = new TestMarketplace();
        var post = test.Seed(p => { p.Status = MarketplacePostStatus.Paused; p.EndsAt = test.Now.AddMinutes(-1); });

        var page = await test.QueryHandlers.Handle(new GetMyMarketplacePostsQuery(), default);

        page.Items.Single(p => p.Id == post.Id).Actions.Select(a => a.ToStatus).Should().Equal("Closed");
    }

    [Fact]
    public async Task Status_AnotherBusinessesPost_IsForbidden()
    {
        using var test = new TestMarketplace();
        var post = test.Seed(p => p.OwnerUserId = TestMarketplace.OwnerB);

        var act = () => test.ManageHandlers.Handle(Move(post.Id, MarketplacePostStatus.Paused), default);

        await act.Should().ThrowAsync<ForbiddenException>();
    }

    [Theory]
    [InlineData("Expired", false)]
    [InlineData("Sold", true)]
    [InlineData("", false)]
    [InlineData("paused", true)]
    public void StatusValidator_OnlyStoredStatuses(string status, bool valid) =>
        new ChangeMarketplacePostStatusCommandValidator()
            .Validate(new ChangeMarketplacePostStatusCommand { Id = Guid.NewGuid(), Status = status })
            .IsValid.Should().Be(valid);

    [Fact]
    public async Task Delete_MarksTheRowDeleted()
    {
        using var test = new TestMarketplace();
        var post = test.Seed();

        await test.ManageHandlers.Handle(new DeleteMarketplacePostCommand { Id = post.Id }, default);

        var context = test.NewContext();
        (await context.Posts.CountAsync()).Should().Be(0);
        (await context.Posts.IgnoreQueryFilters().SingleAsync()).IsDeleted.Should().BeTrue();
    }

    [Fact]
    public async Task Delete_AnotherBusinessesPost_IsForbidden()
    {
        using var test = new TestMarketplace();
        var post = test.Seed(p => p.OwnerUserId = TestMarketplace.OwnerB);

        var act = () => test.ManageHandlers.Handle(new DeleteMarketplacePostCommand { Id = post.Id }, default);

        await act.Should().ThrowAsync<ForbiddenException>();
    }

    [Fact]
    public async Task Image_SetReplaceRemove_KeepsOneRowPerSlot()
    {
        using var test = new TestMarketplace();
        var post = test.Seed();

        await test.ManageHandlers.Handle(new SetMarketplacePostImageCommand { PostId = post.Id, SlotIndex = 0 }, default);
        var replaced = await test.ManageHandlers.Handle(new SetMarketplacePostImageCommand { PostId = post.Id, SlotIndex = 0 }, default);
        replaced.Media.Should().ContainSingle().Which.Url.Should().Be(test.Storage.Saved[1]);

        var removed = await test.ManageHandlers.Handle(new RemoveMarketplacePostImageCommand { PostId = post.Id, SlotIndex = 0 }, default);

        removed.Media.Should().BeEmpty();
        test.Storage.Deleted.Should().Equal(test.Storage.Saved[1]);
    }

    [Fact]
    public async Task Image_RemoveEmptySlot_IsNotAnError()
    {
        using var test = new TestMarketplace();
        var post = test.Seed();

        (await test.ManageHandlers.Handle(new RemoveMarketplacePostImageCommand { PostId = post.Id, SlotIndex = 3 }, default)).Media.Should().BeEmpty();
        test.Storage.Deleted.Should().BeEmpty();
    }

    [Fact]
    public async Task Image_OnAnotherBusinessesPost_IsForbiddenAndNotSaved()
    {
        using var test = new TestMarketplace();
        var post = test.Seed(p => p.OwnerUserId = TestMarketplace.OwnerB);

        var act = () => test.ManageHandlers.Handle(new SetMarketplacePostImageCommand { PostId = post.Id, SlotIndex = 0 }, default);

        await act.Should().ThrowAsync<ForbiddenException>();
        test.Storage.Saved.Should().BeEmpty();
    }

    [Theory]
    [InlineData(-1, false)]
    [InlineData(0, true)]
    [InlineData(4, true)]
    [InlineData(5, false)]
    public void ImageValidator_SlotWithinConfiguredSlots(int slot, bool valid)
    {
        using var test = new TestMarketplace();

        new SetMarketplacePostImageCommandValidator(test.Settings)
            .Validate(new SetMarketplacePostImageCommand { PostId = Guid.NewGuid(), SlotIndex = slot })
            .IsValid.Should().Be(valid);
    }

    [Fact]
    public async Task Sync_VerifiedProfile_IsStored()
    {
        using var test = new TestMarketplace();
        var directory = new FakeServiceDirectory();

        var dto = await new SyncMarketplaceBusinessCommandHandler(test.User, test.Db, directory, test.Clock)
            .Handle(new SyncMarketplaceBusinessCommand(), default);

        dto.Should().BeEquivalentTo(new { Name = "shajil shajil", IsVerified = true, IsKnown = true });
        (await test.NewContext().Businesses.SingleAsync()).RefreshedAt.Should().Be(test.Now);
    }

    [Fact]
    public async Task Sync_ServiceUnreachable_KeepsWhatWasKnown()
    {
        using var test = new TestMarketplace();
        var directory = new FakeServiceDirectory();
        var handler = new SyncMarketplaceBusinessCommandHandler(test.User, test.Db, directory, test.Clock);
        await handler.Handle(new SyncMarketplaceBusinessCommand(), default);
        directory.Business = null;

        var dto = await handler.Handle(new SyncMarketplaceBusinessCommand(), default);

        dto.IsVerified.Should().BeTrue();
        dto.IsKnown.Should().BeTrue();
    }

    [Fact]
    public async Task Sync_ServiceUnreachableAndNothingKnown_SaysSo()
    {
        using var test = new TestMarketplace();

        var dto = await new SyncMarketplaceBusinessCommandHandler(test.User, test.Db, new FakeServiceDirectory { Business = null }, test.Clock)
            .Handle(new SyncMarketplaceBusinessCommand(), default);

        dto.IsKnown.Should().BeFalse();
        (await test.NewContext().Businesses.CountAsync()).Should().Be(0);
    }

    private static void CopyCar(UpdateMarketplacePostCommand update, Action<UpdateMarketplacePostCommand>? change = null)
    {
        var car = TestMarketplace.Car();
        update.CategoryId = car.CategoryId;
        update.SubCategoryId = car.SubCategoryId;
        update.Title = car.Title;
        update.Price = car.Price;
        update.Condition = car.Condition;
        update.DistrictId = car.DistrictId;
        update.Attributes = new(car.Attributes);
        change?.Invoke(update);
    }

    private static void CopyFood(UpdateMarketplacePostCommand update, TestMarketplace test)
    {
        var food = test.Biryani();
        update.CategoryId = food.CategoryId;
        update.SubCategoryId = food.SubCategoryId;
        update.Title = food.Title;
        update.Price = food.Price;
        update.OriginalPrice = food.OriginalPrice;
        update.Quantity = food.Quantity;
        update.StartsAt = food.StartsAt;
        update.EndsAt = food.EndsAt;
        update.DistrictId = food.DistrictId;
        update.Attributes = new(food.Attributes);
    }
}
