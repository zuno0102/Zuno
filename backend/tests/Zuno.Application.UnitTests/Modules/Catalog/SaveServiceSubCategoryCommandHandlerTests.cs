using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Catalog.Commands.SaveServiceSubCategory;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.Catalog;

public class SaveServiceSubCategoryCommandHandlerTests
{
    private readonly Mock<IApplicationDbContext> _dbContextMock = new();

    private static readonly Guid CleaningId = Guid.NewGuid();
    private static readonly Guid PlumbingId = Guid.NewGuid();

    private readonly ServiceCategory _cleaning = new()
    {
        Id = CleaningId, Name = "Cleaning", Slug = "cleaning",
    };

    private readonly ServiceCategory _plumbing = new()
    {
        Id = PlumbingId, Name = "Plumbing", Slug = "plumbing",
    };

    private SaveServiceSubCategoryCommandHandler Build(params ServiceSubCategory[] subCategories)
    {
        _dbContextMock.Setup(d => d.ServiceCategories)
            .Returns(TestDbSet.From(_cleaning, _plumbing));
        _dbContextMock.Setup(d => d.ServiceSubCategories)
            .Returns(TestDbSet.From(subCategories));

        return new SaveServiceSubCategoryCommandHandler(_dbContextMock.Object);
    }

    private static ServiceSubCategory Existing(Guid categoryId, string name, string slug) => new()
    {
        Id = Guid.NewGuid(), ServiceCategoryId = categoryId, Name = name, Slug = slug, IsActive = true,
    };

    [Fact]
    public async Task Should_Add_A_Sub_Category_Under_Its_Category()
    {
        var sut = Build();

        var result = await sut.Handle(
            new SaveServiceSubCategoryCommand
            {
                ServiceCategoryId = CleaningId,
                Name = "  Kitchen cleaning  ",
                DisplayOrder = 3,
                IsActive = true,
            },
            CancellationToken.None);

        result.Name.Should().Be("Kitchen cleaning", "the typed name is trimmed, not stored raw");
        result.Slug.Should().Be("kitchen-cleaning");
        result.ServiceCategoryId.Should().Be(CleaningId);
        _dbContextMock.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Should_Refuse_A_Duplicate_Inside_The_Same_Category()
    {
        var sut = Build(Existing(CleaningId, "Kitchen cleaning", "kitchen-cleaning"));

        var act = () => sut.Handle(
            new SaveServiceSubCategoryCommand { ServiceCategoryId = CleaningId, Name = "Kitchen Cleaning" },
            CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>()
            .WithMessage("*already has a sub-category*");
        _dbContextMock.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    /// <summary>
    /// The rule the database index already encodes: "water tank cleaning" genuinely belongs under
    /// both Plumbing and Cleaning, so uniqueness is per parent rather than global. A global check
    /// would look correct and quietly make half the real catalogue unenterable.
    /// </summary>
    [Fact]
    public async Task Should_Allow_The_Same_Name_Under_A_Different_Category()
    {
        var sut = Build(Existing(PlumbingId, "Water tank cleaning", "water-tank-cleaning"));

        var result = await sut.Handle(
            new SaveServiceSubCategoryCommand
            {
                ServiceCategoryId = CleaningId,
                Name = "Water tank cleaning",
            },
            CancellationToken.None);

        result.Slug.Should().Be("water-tank-cleaning");
        result.ServiceCategoryId.Should().Be(CleaningId);
    }

    /// <summary>
    /// Items priced under a sub-category belong to services in its original category. Moving it
    /// would leave them tagged with a kind of work their own service does not offer.
    /// </summary>
    [Fact]
    public async Task Should_Refuse_To_Move_A_Sub_Category_To_Another_Category()
    {
        var existing = Existing(PlumbingId, "Pipe leak repair", "pipe-leak-repair");
        var sut = Build(existing);

        var act = () => sut.Handle(
            new SaveServiceSubCategoryCommand
            {
                Id = existing.Id,
                ServiceCategoryId = CleaningId,
                Name = "Pipe leak repair",
            },
            CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>().WithMessage("*cannot be moved*");
        existing.ServiceCategoryId.Should().Be(PlumbingId, "the row must not have moved");
        _dbContextMock.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Should_Rename_In_Place_Keeping_Its_Id()
    {
        var existing = Existing(CleaningId, "Kitchen cleaning", "kitchen-cleaning");
        var sut = Build(existing);

        var result = await sut.Handle(
            new SaveServiceSubCategoryCommand
            {
                Id = existing.Id,
                ServiceCategoryId = CleaningId,
                Name = "Kitchen deep cleaning",
                IsActive = true,
            },
            CancellationToken.None);

        // The id surviving is what keeps every service already tagged with it pointing somewhere.
        result.Id.Should().Be(existing.Id);
        result.Name.Should().Be("Kitchen deep cleaning");
        result.Slug.Should().Be("kitchen-deep-cleaning");
    }

    [Fact]
    public async Task Should_Hide_Rather_Than_Delete()
    {
        var existing = Existing(CleaningId, "Kitchen cleaning", "kitchen-cleaning");
        var sut = Build(existing);

        var result = await sut.Handle(
            new SaveServiceSubCategoryCommand
            {
                Id = existing.Id,
                ServiceCategoryId = CleaningId,
                Name = "Kitchen cleaning",
                IsActive = false,
            },
            CancellationToken.None);

        result.IsActive.Should().BeFalse();
        existing.IsDeleted.Should().BeFalse("hiding must never remove the row businesses point at");
    }

    [Fact]
    public async Task Should_Refuse_An_Unknown_Category()
    {
        var sut = Build();

        var act = () => sut.Handle(
            new SaveServiceSubCategoryCommand { ServiceCategoryId = Guid.NewGuid(), Name = "Anything" },
            CancellationToken.None);

        await act.Should().ThrowAsync<EntityNotFoundException>();
    }

    [Fact]
    public async Task Should_Refuse_A_Name_With_Nothing_Usable_In_It()
    {
        var sut = Build();

        var act = () => sut.Handle(
            new SaveServiceSubCategoryCommand { ServiceCategoryId = CleaningId, Name = "!!!" },
            CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>().WithMessage("*no letters or numbers*");
    }
}
