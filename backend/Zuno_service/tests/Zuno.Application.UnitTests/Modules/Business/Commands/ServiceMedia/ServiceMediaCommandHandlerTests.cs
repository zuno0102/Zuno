using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.Commands.RemoveBusinessServiceMedia;
using Zuno.Application.Modules.Business.Commands.SetBusinessServiceMedia;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.UnitTests.Modules.Business.Commands.ServiceMedia;

/// <summary>
/// Pictures and video on a service — the two faults these cover were both found by exercising the
/// endpoints for the first time, and neither showed up as a wrong answer to the caller.
/// </summary>
public class ServiceMediaCommandHandlerTests
{
    private readonly Mock<ICurrentUserService> _currentUser = new();
    private readonly Mock<IBusinessOwnerProfileRepository> _profiles = new();
    private readonly Mock<IBusinessServiceRepository> _services = new();
    private readonly Mock<IFileStorageService> _storage = new();
    private readonly Mock<IApplicationDbContext> _dbContext = new();
    private readonly Mock<DbSet<BusinessServiceMedia>> _media = new();

    private readonly Guid _ownerUserId = Guid.NewGuid();
    private readonly BusinessOwnerProfile _ownerProfile = new() { Id = Guid.NewGuid(), BusinessName = "Boss T Catering" };
    private readonly BusinessService _service;

    public ServiceMediaCommandHandlerTests()
    {
        _service = new BusinessService
        {
            Id = Guid.NewGuid(),
            Name = "Wedding catering",
            BusinessOwnerProfileId = _ownerProfile.Id,
            ServiceCategory = new ServiceCategory { Name = "Catering" },
        };

        _dbContext.Setup(d => d.BusinessServiceMedia).Returns(_media.Object);
        _currentUser.Setup(c => c.UserId).Returns(_ownerUserId);
        _profiles.Setup(p => p.GetByUserIdAsync(_ownerUserId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_ownerProfile);
        _services.Setup(s => s.GetByIdAsync(_service.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_service);
        _storage.Setup(s => s.SaveServiceImageAsync(
                It.IsAny<Guid>(), It.IsAny<int>(), It.IsAny<Stream>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync("/uploads/services/x/image-0.jpg");
    }

    private SetBusinessServiceImageCommandHandler SetHandler() => new(
        _currentUser.Object, _profiles.Object, _services.Object, _storage.Object, _dbContext.Object);

    private RemoveBusinessServiceImageCommandHandler RemoveHandler() => new(
        _currentUser.Object, _profiles.Object, _services.Object, _storage.Object, _dbContext.Object);

    [Fact]
    public async Task The_owner_can_set_a_picture()
    {
        var result = await SetHandler().Handle(
            new SetBusinessServiceImageCommand
            {
                ServiceId = _service.Id,
                SlotIndex = 0,
                Content = new MemoryStream([1, 2, 3]),
                FileExtension = ".jpg",
            },
            CancellationToken.None);

        result.Should().NotBeNull();
        _media.Verify(m => m.Add(It.Is<BusinessServiceMedia>(
            x => x.BusinessServiceId == _service.Id
                 && x.MediaType == ServiceMediaType.Image
                 && x.SortOrder == 0)), Times.Once);
        _dbContext.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    /// <remarks>
    /// <para>
    /// The fault: the controller saved the uploaded file and then sent a command carrying its URL,
    /// so the file reached the disk before anybody had checked whose service it was. Saving a
    /// picture clears the slot first, which made the ordering destructive rather than merely
    /// untidy — aiming an upload at another business's service id deleted that business's picture
    /// and left this one in its place, while the caller got a tidy "does not belong to your
    /// business" and no idea anything had happened.
    /// </para>
    /// <para>
    /// Service ids are not secret; a customer browsing the app is given them. So this asserts the
    /// strong thing — not that the command is refused, but that <i>nothing is written at all</i>.
    /// </para>
    /// </remarks>
    [Fact]
    public async Task A_stranger_cannot_cause_anything_to_be_written()
    {
        var strangerUserId = Guid.NewGuid();
        _currentUser.Setup(c => c.UserId).Returns(strangerUserId);
        _profiles.Setup(p => p.GetByUserIdAsync(strangerUserId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new BusinessOwnerProfile { Id = Guid.NewGuid(), BusinessName = "Someone Else" });

        var act = () => SetHandler().Handle(
            new SetBusinessServiceImageCommand
            {
                ServiceId = _service.Id,
                SlotIndex = 0,
                Content = new MemoryStream([1, 2, 3]),
                FileExtension = ".jpg",
            },
            CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();

        _storage.Verify(s => s.SaveServiceImageAsync(
            It.IsAny<Guid>(), It.IsAny<int>(), It.IsAny<Stream>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Never);
        _dbContext.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    /// <remarks>
    /// The fault: removal took the row out of <c>service.Media</c>, which tells EF the
    /// relationship is severed, not that the row should go. EF then tried to null the row's
    /// owning foreign key, and the table refuses that — it requires exactly one of its two owner
    /// columns — so every attempt to remove a picture answered 500 and the picture stayed.
    /// </remarks>
    [Fact]
    public async Task Removing_a_picture_deletes_the_row_rather_than_detaching_it()
    {
        var existing = new BusinessServiceMedia
        {
            BusinessServiceId = _service.Id,
            MediaType = ServiceMediaType.Image,
            SortOrder = 0,
            Url = "/uploads/services/x/image-0.jpg",
        };
        _service.Media.Add(existing);

        await RemoveHandler().Handle(
            new RemoveBusinessServiceImageCommand { ServiceId = _service.Id, SlotIndex = 0 },
            CancellationToken.None);

        _media.Verify(m => m.Remove(existing), Times.Once);
        _dbContext.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
        _storage.Verify(s => s.DeleteFile(existing.Url), Times.Once);
    }

    [Fact]
    public async Task Removing_a_picture_that_is_not_there_changes_nothing()
    {
        await RemoveHandler().Handle(
            new RemoveBusinessServiceImageCommand { ServiceId = _service.Id, SlotIndex = 2 },
            CancellationToken.None);

        _media.Verify(m => m.Remove(It.IsAny<BusinessServiceMedia>()), Times.Never);
        _dbContext.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
        _storage.Verify(s => s.DeleteFile(It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task A_stranger_cannot_remove_a_picture()
    {
        var strangerUserId = Guid.NewGuid();
        _currentUser.Setup(c => c.UserId).Returns(strangerUserId);
        _profiles.Setup(p => p.GetByUserIdAsync(strangerUserId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new BusinessOwnerProfile { Id = Guid.NewGuid(), BusinessName = "Someone Else" });

        _service.Media.Add(new BusinessServiceMedia
        {
            BusinessServiceId = _service.Id,
            MediaType = ServiceMediaType.Image,
            SortOrder = 0,
            Url = "/uploads/services/x/image-0.jpg",
        });

        var act = () => RemoveHandler().Handle(
            new RemoveBusinessServiceImageCommand { ServiceId = _service.Id, SlotIndex = 0 },
            CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();

        _media.Verify(m => m.Remove(It.IsAny<BusinessServiceMedia>()), Times.Never);
        _storage.Verify(s => s.DeleteFile(It.IsAny<string>()), Times.Never);
    }
}
