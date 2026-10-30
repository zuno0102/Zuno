using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Categories;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.UnitTests;

public class RentalItemHandlerTests : IDisposable
{
    private readonly TestRent _rent = new();

    public void Dispose() => _rent.Dispose();

    [Fact]
    public async Task Create_belongs_to_the_signed_in_business_and_shows_its_names()
    {
        var dto = await _rent.SaveHandlers.Handle(TestRent.Machine(), default);

        dto.RentalCategoryName.Should().Be("Tools & machines");
        dto.RentalSubCategoryName.Should().Be("Cutting machine");
        dto.PriceType.Should().Be("Daily");
        dto.QuantityOwned.Should().Be(1);
        dto.IsAvailable.Should().BeTrue();
        dto.Districts.Should().ContainSingle(d => d.Name == "Ernakulam" && d.StateName == "Kerala");
        (await _rent.Db.RentalItems.SingleAsync()).OwnerUserId.Should().Be(TestRent.OwnerA);
    }

    [Fact]
    public async Task Create_trims_text_and_lists_each_district_once()
    {
        var dto = await _rent.SaveHandlers.Handle(
            TestRent.Machine(c =>
            {
                c.Name = "  Plastic chair  ";
                c.Description = "   ";
                c.QuantityOwned = 200;
                c.DistrictIds = [TestRent.Ernakulam, TestRent.Thrissur, TestRent.Ernakulam];
            }),
            default);

        dto.Name.Should().Be("Plastic chair");
        dto.Description.Should().BeNull();
        dto.QuantityOwned.Should().Be(200);
        dto.Districts.Select(d => d.Name).Should().Equal("Ernakulam", "Thrissur");
    }

    [Fact]
    public async Task Update_changes_rate_quantity_availability_and_districts()
    {
        var created = await _rent.SaveHandlers.Handle(TestRent.Machine(c => c.DistrictIds = [TestRent.Ernakulam, TestRent.Thrissur]), default);
        _rent.Db.ChangeTracker.Clear();

        var dto = await _rent.SaveHandlers.Handle(
            TestRent.Edit(created.Id, c =>
            {
                c.PriceType = "Hourly";
                c.Price = 90;
                c.QuantityOwned = 2;
                c.IsAvailable = false;
                c.DistrictIds = [TestRent.Thrissur];
            }),
            default);

        dto.PriceType.Should().Be("Hourly");
        dto.Price.Should().Be(90);
        dto.QuantityOwned.Should().Be(2);
        dto.IsAvailable.Should().BeFalse();
        dto.Districts.Should().ContainSingle(d => d.Name == "Thrissur");
    }

    [Fact]
    public async Task A_district_removed_and_chosen_again_comes_back()
    {
        var created = await _rent.SaveHandlers.Handle(TestRent.Machine(), default);
        _rent.Db.ChangeTracker.Clear();
        await _rent.SaveHandlers.Handle(TestRent.Edit(created.Id, c => c.DistrictIds = [TestRent.Thrissur]), default);
        _rent.Db.ChangeTracker.Clear();

        var dto = await _rent.SaveHandlers.Handle(TestRent.Edit(created.Id, c => c.DistrictIds = [TestRent.Ernakulam]), default);

        dto.Districts.Should().ContainSingle(d => d.Name == "Ernakulam");
    }

    [Fact]
    public async Task Another_business_cannot_edit_delete_or_upload()
    {
        var created = await _rent.SaveHandlers.Handle(TestRent.Machine(), default);
        _rent.As(TestRent.OwnerB);

        await FluentActions.Awaiting(() => _rent.SaveHandlers.Handle(TestRent.Edit(created.Id), default))
            .Should().ThrowAsync<ForbiddenException>();
        await FluentActions.Awaiting(() => new DeleteRentalItemCommandHandler(_rent.User, _rent.Db).Handle(new DeleteRentalItemCommand { Id = created.Id }, default))
            .Should().ThrowAsync<ForbiddenException>();
        await FluentActions.Awaiting(() => _rent.MediaHandlers.Handle(new SetRentalItemImageCommand { RentalItemId = created.Id, SlotIndex = 0, FileExtension = ".png" }, default))
            .Should().ThrowAsync<ForbiddenException>();

        _rent.Storage.Saved.Should().BeEmpty("nothing is written before ownership is checked");
    }

    [Fact]
    public async Task Not_signed_in_is_refused()
    {
        _rent.User.UserId = null;

        await FluentActions.Awaiting(() => _rent.SaveHandlers.Handle(TestRent.Machine(), default))
            .Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Fact]
    public async Task An_unknown_item_is_not_found()
    {
        await FluentActions.Awaiting(() => _rent.SaveHandlers.Handle(TestRent.Edit(Guid.NewGuid()), default))
            .Should().ThrowAsync<EntityNotFoundException>();
    }

    [Fact]
    public async Task Delete_is_soft_and_hides_the_item()
    {
        var created = await _rent.SaveHandlers.Handle(TestRent.Machine(), default);
        _rent.Db.ChangeTracker.Clear();

        await new DeleteRentalItemCommandHandler(_rent.User, _rent.Db).Handle(new DeleteRentalItemCommand { Id = created.Id }, default);

        (await _rent.Db.RentalItems.AnyAsync()).Should().BeFalse();
        (await _rent.Db.RentalItems.IgnoreQueryFilters().SingleAsync()).IsDeleted.Should().BeTrue();
        await FluentActions.Awaiting(() => _rent.SaveHandlers.Handle(TestRent.Edit(created.Id), default))
            .Should().ThrowAsync<EntityNotFoundException>();
    }

    [Fact]
    public async Task Photos_fill_slots_replace_and_remove()
    {
        var item = await _rent.SaveHandlers.Handle(TestRent.Machine(), default);

        var first = await _rent.MediaHandlers.Handle(new SetRentalItemImageCommand { RentalItemId = item.Id, SlotIndex = 0, FileExtension = ".png" }, default);
        await _rent.MediaHandlers.Handle(new SetRentalItemImageCommand { RentalItemId = item.Id, SlotIndex = 2, FileExtension = ".jpg" }, default);
        var replaced = await _rent.MediaHandlers.Handle(new SetRentalItemImageCommand { RentalItemId = item.Id, SlotIndex = 0, FileExtension = ".webp" }, default);

        replaced.Media.Should().HaveCount(2);
        replaced.Media.Single(m => m.SortOrder == 0).Url.Should().NotBe(first.Media.Single().Url).And.EndWith(".webp");

        var removed = await _rent.MediaHandlers.Handle(new RemoveRentalItemImageCommand { RentalItemId = item.Id, SlotIndex = 2 }, default);

        removed.Media.Should().ContainSingle(m => m.SortOrder == 0);
        _rent.Storage.Deleted.Should().ContainSingle(url => url.EndsWith(".jpg"));
    }

    [Fact]
    public async Task Removing_an_empty_slot_changes_nothing()
    {
        var item = await _rent.SaveHandlers.Handle(TestRent.Machine(), default);

        var dto = await _rent.MediaHandlers.Handle(new RemoveRentalItemImageCommand { RentalItemId = item.Id, SlotIndex = 1 }, default);

        dto.Media.Should().BeEmpty();
        _rent.Storage.Deleted.Should().BeEmpty();
    }

    [Fact]
    public async Task One_video_is_kept_after_the_photos()
    {
        var item = await _rent.SaveHandlers.Handle(TestRent.Machine(), default);
        await _rent.MediaHandlers.Handle(new SetRentalItemVideoCommand { RentalItemId = item.Id, FileExtension = ".mp4" }, default);
        await _rent.MediaHandlers.Handle(new SetRentalItemImageCommand { RentalItemId = item.Id, SlotIndex = 1, FileExtension = ".png" }, default);

        var dto = await _rent.MediaHandlers.Handle(new SetRentalItemVideoCommand { RentalItemId = item.Id, FileExtension = ".webm" }, default);

        dto.Media.Select(m => m.MediaType).Should().Equal("Image", "Video");
        dto.Media.Last().Url.Should().EndWith(".webm");

        var noVideo = await _rent.MediaHandlers.Handle(new RemoveRentalItemVideoCommand { RentalItemId = item.Id }, default);
        noVideo.Media.Should().OnlyContain(m => m.MediaType == "Image");
    }

    [Fact]
    public async Task The_list_shows_only_the_callers_items_newest_first_and_paged()
    {
        await _rent.SaveHandlers.Handle(TestRent.Machine(c => c.Name = "First"), default);
        await Task.Delay(5);
        await _rent.SaveHandlers.Handle(TestRent.Machine(c => c.Name = "Second"), default);
        _rent.As(TestRent.OwnerB);
        await _rent.SaveHandlers.Handle(TestRent.Machine(c => c.Name = "Other business"), default);
        _rent.As(TestRent.OwnerA);

        var handler = new GetMyRentalItemsQueryHandler(_rent.User, _rent.Db, _rent.Settings);
        var page1 = await handler.Handle(new GetMyRentalItemsQuery { Page = 1, PageSize = 1 }, default);
        var page2 = await handler.Handle(new GetMyRentalItemsQuery { Page = 2, PageSize = 1 }, default);

        page1.TotalCount.Should().Be(2);
        page1.Items.Single().Name.Should().Be("Second");
        page2.Items.Single().Name.Should().Be("First");
    }

    [Theory]
    [InlineData(null, 50)]
    [InlineData(0, 1)]
    [InlineData(100_000, 100)]
    public async Task Page_size_defaults_and_is_capped(int? asked, int expected)
    {
        var handler = new GetMyRentalItemsQueryHandler(_rent.User, _rent.Db, _rent.Settings);

        var page = await handler.Handle(new GetMyRentalItemsQuery { Page = -3, PageSize = asked }, default);

        page.PageSize.Should().Be(expected);
        page.Page.Should().Be(1);
        page.Items.Should().BeEmpty();
    }

    [Fact]
    public async Task Categories_come_in_order_with_active_sub_categories_and_are_cached()
    {
        var cache = new Microsoft.Extensions.Caching.Memory.MemoryCache(new Microsoft.Extensions.Caching.Memory.MemoryCacheOptions());
        var handler = new GetRentalCategoriesQueryHandler(_rent.Db, cache, _rent.Settings);

        var categories = await handler.Handle(new GetRentalCategoriesQuery(), default);

        categories.Select(c => c.Name).Should().StartWith("Furniture & seating").And.HaveCount(7);
        categories.Single(c => c.Name == "Tools & machines").SubCategories.Select(s => s.Name).Should().StartWith("Cutting machine");

        _rent.Db.RentalCategories.Single(c => c.Slug == "decoration").IsActive = false;
        await _rent.Db.SaveChangesAsync();
        (await handler.Handle(new GetRentalCategoriesQuery(), default)).Should().HaveCount(7, "served from cache until it expires");
    }
}
