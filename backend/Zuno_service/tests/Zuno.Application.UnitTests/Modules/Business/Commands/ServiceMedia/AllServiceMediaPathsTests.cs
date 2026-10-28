using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.Commands.RemoveBusinessServiceMedia;
using Zuno.Application.Modules.Business.Commands.RemoveBusinessServiceVariantImage;
using Zuno.Application.Modules.Business.Commands.RemoveBusinessServiceVariantVideo;
using Zuno.Application.Modules.Business.Commands.SetBusinessServiceMedia;
using Zuno.Application.Modules.Business.Commands.SetBusinessServiceVariantImage;
using Zuno.Application.Modules.Business.Commands.SetBusinessServiceVariantVideo;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.UnitTests.Modules.Business.Commands.ServiceMedia;

/// <summary>
/// The same two rules, asked of every media path rather than only the first one.
/// </summary>
/// <remarks>
/// Both faults these cover existed on five upload paths and four removal paths at once, because
/// each was written by copying the one before it. Testing a single path would have left the fix
/// free to be undone on the other eight without anything noticing, so each one is asked
/// separately here:
/// <list type="bullet">
/// <item>nothing is written to storage for a caller who does not own the service</item>
/// <item>removal deletes the row instead of severing the relationship</item>
/// </list>
/// </remarks>
public class AllServiceMediaPathsTests
{
    private readonly Mock<ICurrentUserService> _currentUser = new();
    private readonly Mock<IBusinessOwnerProfileRepository> _profiles = new();
    private readonly Mock<IBusinessServiceRepository> _services = new();
    private readonly Mock<IFileStorageService> _storage = new();
    private readonly Mock<IApplicationDbContext> _dbContext = new();
    private readonly Mock<DbSet<BusinessServiceMedia>> _media = new();

    private readonly BusinessOwnerProfile _owner = new() { Id = Guid.NewGuid(), BusinessName = "Boss T" };
    private readonly BusinessService _service;
    private readonly BusinessServiceVariant _variant;

    public AllServiceMediaPathsTests()
    {
        _variant = new BusinessServiceVariant { Id = Guid.NewGuid(), Name = "Gold package" };
        _service = new BusinessService
        {
            Id = Guid.NewGuid(),
            Name = "Wedding catering",
            BusinessOwnerProfileId = _owner.Id,
            ServiceCategory = new ServiceCategory { Name = "Catering" },
        };
        _service.Variants.Add(_variant);

        _dbContext.Setup(d => d.BusinessServiceMedia).Returns(_media.Object);
        _services.Setup(s => s.GetByIdAsync(_service.Id, It.IsAny<CancellationToken>())).ReturnsAsync(_service);
    }

    /// <summary>Signs in as somebody who owns a different business.</summary>
    private void SignInAsAStranger()
    {
        var strangerUserId = Guid.NewGuid();
        _currentUser.Setup(c => c.UserId).Returns(strangerUserId);
        _profiles.Setup(p => p.GetByUserIdAsync(strangerUserId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new BusinessOwnerProfile { Id = Guid.NewGuid(), BusinessName = "Someone Else" });
    }

    private void SignInAsTheOwner()
    {
        var ownerUserId = Guid.NewGuid();
        _currentUser.Setup(c => c.UserId).Returns(ownerUserId);
        _profiles.Setup(p => p.GetByUserIdAsync(ownerUserId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_owner);
    }

    private void NothingWasWrittenOrSaved()
    {
        _storage.VerifyNoOtherCalls();
        _dbContext.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
        _media.Verify(m => m.Add(It.IsAny<BusinessServiceMedia>()), Times.Never);
        _media.Verify(m => m.Remove(It.IsAny<BusinessServiceMedia>()), Times.Never);
    }

    private BusinessServiceMedia GiveTheServiceSome(ServiceMediaType type, short slot = 0)
    {
        var media = new BusinessServiceMedia
        {
            BusinessServiceId = _service.Id,
            MediaType = type,
            SortOrder = slot,
            Url = $"/uploads/services/{_service.Id}/{type}-{slot}.bin",
        };
        _service.Media.Add(media);
        return media;
    }

    private BusinessServiceMedia GiveThePackageSome(ServiceMediaType type, short slot = 0)
    {
        var media = new BusinessServiceMedia
        {
            BusinessServiceVariantId = _variant.Id,
            MediaType = type,
            SortOrder = slot,
            Url = $"/uploads/services/{_service.Id}/variants/{_variant.Id}/{type}-{slot}.bin",
        };
        _variant.Media.Add(media);
        return media;
    }

    // ---- nothing is written for a caller who does not own the service ----------------------------

    [Fact]
    public async Task A_stranger_setting_a_service_video_writes_nothing()
    {
        SignInAsAStranger();
        var sut = new SetBusinessServiceVideoCommandHandler(
            _currentUser.Object, _profiles.Object, _services.Object, _storage.Object, _dbContext.Object);

        var act = () => sut.Handle(
            new SetBusinessServiceVideoCommand
            {
                ServiceId = _service.Id,
                Content = new MemoryStream([1]),
                FileExtension = ".mp4",
            },
            CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        NothingWasWrittenOrSaved();
    }

    [Fact]
    public async Task A_stranger_setting_a_package_picture_writes_nothing()
    {
        SignInAsAStranger();
        var sut = new SetBusinessServiceVariantImageCommandHandler(
            _currentUser.Object, _profiles.Object, _services.Object, _storage.Object, _dbContext.Object);

        var act = () => sut.Handle(
            new SetBusinessServiceVariantImageCommand
            {
                ServiceId = _service.Id,
                VariantId = _variant.Id,
                SlotIndex = 0,
                Content = new MemoryStream([1]),
                FileExtension = ".jpg",
            },
            CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        NothingWasWrittenOrSaved();
    }

    [Fact]
    public async Task A_stranger_setting_a_package_video_writes_nothing()
    {
        SignInAsAStranger();
        var sut = new SetBusinessServiceVariantVideoCommandHandler(
            _currentUser.Object, _profiles.Object, _services.Object, _storage.Object, _dbContext.Object);

        var act = () => sut.Handle(
            new SetBusinessServiceVariantVideoCommand
            {
                ServiceId = _service.Id,
                VariantId = _variant.Id,
                Content = new MemoryStream([1]),
                FileExtension = ".mp4",
            },
            CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        NothingWasWrittenOrSaved();
    }

    // ---- removal deletes the row -----------------------------------------------------------------

    [Fact]
    public async Task Removing_a_service_video_deletes_the_row()
    {
        SignInAsTheOwner();
        var existing = GiveTheServiceSome(ServiceMediaType.Video);
        var sut = new RemoveBusinessServiceVideoCommandHandler(
            _currentUser.Object, _profiles.Object, _services.Object, _storage.Object, _dbContext.Object);

        await sut.Handle(
            new RemoveBusinessServiceVideoCommand { ServiceId = _service.Id },
            CancellationToken.None);

        _media.Verify(m => m.Remove(existing), Times.Once);
        _dbContext.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
        _storage.Verify(s => s.DeleteFile(existing.Url), Times.Once);
    }

    [Fact]
    public async Task Removing_a_package_picture_deletes_the_row()
    {
        SignInAsTheOwner();
        var existing = GiveThePackageSome(ServiceMediaType.Image, slot: 1);
        var sut = new RemoveBusinessServiceVariantImageCommandHandler(
            _currentUser.Object, _profiles.Object, _services.Object, _storage.Object, _dbContext.Object);

        await sut.Handle(
            new RemoveBusinessServiceVariantImageCommand
            {
                ServiceId = _service.Id,
                VariantId = _variant.Id,
                SlotIndex = 1,
            },
            CancellationToken.None);

        _media.Verify(m => m.Remove(existing), Times.Once);
        _dbContext.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
        _storage.Verify(s => s.DeleteFile(existing.Url), Times.Once);
    }

    [Fact]
    public async Task Removing_a_package_video_deletes_the_row()
    {
        SignInAsTheOwner();
        var existing = GiveThePackageSome(ServiceMediaType.Video);
        var sut = new RemoveBusinessServiceVariantVideoCommandHandler(
            _currentUser.Object, _profiles.Object, _services.Object, _storage.Object, _dbContext.Object);

        await sut.Handle(
            new RemoveBusinessServiceVariantVideoCommand
            {
                ServiceId = _service.Id,
                VariantId = _variant.Id,
            },
            CancellationToken.None);

        _media.Verify(m => m.Remove(existing), Times.Once);
        _dbContext.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
        _storage.Verify(s => s.DeleteFile(existing.Url), Times.Once);
    }

    [Fact]
    public async Task A_stranger_cannot_remove_a_package_video()
    {
        SignInAsAStranger();
        GiveThePackageSome(ServiceMediaType.Video);
        var sut = new RemoveBusinessServiceVariantVideoCommandHandler(
            _currentUser.Object, _profiles.Object, _services.Object, _storage.Object, _dbContext.Object);

        var act = () => sut.Handle(
            new RemoveBusinessServiceVariantVideoCommand
            {
                ServiceId = _service.Id,
                VariantId = _variant.Id,
            },
            CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        NothingWasWrittenOrSaved();
    }

    /// <remarks>
    /// A package belonging to a different service, reached through a service the caller does own.
    /// Owning one service must not open the packages of another.
    /// </remarks>
    [Fact]
    public async Task A_package_that_is_not_on_this_service_is_not_found()
    {
        SignInAsTheOwner();
        var sut = new SetBusinessServiceVariantImageCommandHandler(
            _currentUser.Object, _profiles.Object, _services.Object, _storage.Object, _dbContext.Object);

        var act = () => sut.Handle(
            new SetBusinessServiceVariantImageCommand
            {
                ServiceId = _service.Id,
                VariantId = Guid.NewGuid(),
                SlotIndex = 0,
                Content = new MemoryStream([1]),
                FileExtension = ".jpg",
            },
            CancellationToken.None);

        await act.Should().ThrowAsync<Zuno.Domain.Exceptions.EntityNotFoundException>();
        NothingWasWrittenOrSaved();
    }
}
