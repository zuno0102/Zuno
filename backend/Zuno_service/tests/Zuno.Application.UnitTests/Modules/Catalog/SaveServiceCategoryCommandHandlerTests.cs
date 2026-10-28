using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Catalog.Commands.SaveServiceCategory;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.Catalog;

public class SaveServiceCategoryCommandHandlerTests
{
    private readonly Mock<IApplicationDbContext> _dbContextMock = new();

    private SaveServiceCategoryCommandHandler Build(params ServiceCategory[] categories)
    {
        _dbContextMock.Setup(d => d.ServiceCategories).Returns(TestDbSet.From(categories));
        _dbContextMock.Setup(d => d.BusinessServices).Returns(TestDbSet.From<BusinessService>());

        return new SaveServiceCategoryCommandHandler(_dbContextMock.Object);
    }

    private static ServiceCategory Existing(string name, string slug) => new()
    {
        Id = Guid.NewGuid(), Name = name, Slug = slug, IsActive = true,
    };

    [Fact]
    public async Task Should_Add_A_Category_With_A_Slug_Worked_Out_From_The_Name()
    {
        var sut = Build();

        var result = await sut.Handle(
            new SaveServiceCategoryCommand
            {
                Name = "  Catering & events  ",
                Description = " Food for events ",
                DisplayOrder = 9,
                IsActive = true,
            },
            CancellationToken.None);

        result.Name.Should().Be("Catering & events");
        result.Slug.Should().Be("catering-events", "nobody should have to think about slugs");
        result.Description.Should().Be("Food for events");
        result.IsActive.Should().BeTrue();
        _dbContextMock.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Should_Refuse_A_Name_That_Collides_With_Another_Category()
    {
        var sut = Build(Existing("Cleaning", "cleaning"));

        // Differently typed, same slug — which is what the unique index actually compares.
        var act = () => sut.Handle(
            new SaveServiceCategoryCommand { Name = "CLEANING" },
            CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>()
            .WithMessage("*already a category*");
        _dbContextMock.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    /// <summary>
    /// Saving a category without renaming it must not trip the duplicate check against itself —
    /// the naive version compares slugs and refuses every second save of the same row.
    /// </summary>
    [Fact]
    public async Task Should_Let_A_Category_Keep_Its_Own_Name_When_Edited()
    {
        var existing = Existing("Cleaning", "cleaning");
        var sut = Build(existing);

        var result = await sut.Handle(
            new SaveServiceCategoryCommand
            {
                Id = existing.Id,
                Name = "Cleaning",
                DisplayOrder = 4,
                IsActive = true,
            },
            CancellationToken.None);

        result.Id.Should().Be(existing.Id);
        result.DisplayOrder.Should().Be(4);
    }

    [Fact]
    public async Task Should_Hide_Rather_Than_Delete()
    {
        var existing = Existing("Cleaning", "cleaning");
        var sut = Build(existing);

        var result = await sut.Handle(
            new SaveServiceCategoryCommand { Id = existing.Id, Name = "Cleaning", IsActive = false },
            CancellationToken.None);

        result.IsActive.Should().BeFalse();
        // The whole point: businesses have services priced under this row, and the foreign key is
        // set to refuse deletion. Hiding takes it out of the pickers and leaves them working.
        existing.IsDeleted.Should().BeFalse();
    }

    [Fact]
    public async Task Should_Refuse_A_Name_With_Nothing_Usable_In_It()
    {
        var sut = Build();

        var act = () => sut.Handle(
            new SaveServiceCategoryCommand { Name = "!!!" },
            CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>().WithMessage("*no letters or numbers*");
        _dbContextMock.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Should_Refuse_An_Unknown_Category()
    {
        var sut = Build();

        var act = () => sut.Handle(
            new SaveServiceCategoryCommand { Id = Guid.NewGuid(), Name = "Anything" },
            CancellationToken.None);

        await act.Should().ThrowAsync<EntityNotFoundException>();
    }
}
