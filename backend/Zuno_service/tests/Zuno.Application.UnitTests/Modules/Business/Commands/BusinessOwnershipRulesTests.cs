using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.Commands.DeleteBusinessService;
using Zuno.Application.Modules.Business.Commands.RemoveBusinessWorker;
using Zuno.Application.Modules.Business.Commands.SetBusinessLogo;
using Zuno.Application.Modules.Business.Commands.SetBusinessServiceQuestions;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.Business.Commands;

/// <summary>
/// One business cannot reach into another's.
/// </summary>
/// <remarks>
/// Each of these handlers finds its subject by an id that came from the request, then checks that
/// subject belongs to the caller. The check is the only thing standing between a business and
/// somebody else's services, team and pictures — ids are not secret, and a customer browsing is
/// handed service ids as a matter of course. None of them had a test.
/// </remarks>
public class BusinessOwnershipRulesTests
{
    private readonly Mock<ICurrentUserService> _currentUser = new();
    private readonly Mock<IBusinessOwnerProfileRepository> _profiles = new();
    private readonly Mock<IBusinessServiceRepository> _services = new();
    private readonly Mock<IBusinessWorkerRepository> _workers = new();
    private readonly Mock<IFileStorageService> _storage = new();
    private readonly Mock<IDateTimeProvider> _clock = new();
    private readonly Mock<IApplicationDbContext> _dbContext = new();
    private readonly Mock<DbSet<BusinessServiceQuestion>> _questions = new();

    private readonly Guid _ownerUserId = Guid.NewGuid();
    private readonly Guid _strangerUserId = Guid.NewGuid();
    private readonly BusinessOwnerProfile _owner = new() { Id = Guid.NewGuid(), BusinessName = "Boss T Catering" };
    private readonly BusinessOwnerProfile _stranger = new() { Id = Guid.NewGuid(), BusinessName = "Rival Caterers" };
    private readonly BusinessService _service;

    public BusinessOwnershipRulesTests()
    {
        _service = new BusinessService
        {
            Id = Guid.NewGuid(),
            Name = "Wedding catering",
            BusinessOwnerProfileId = _owner.Id,
            ServiceCategory = new ServiceCategory { Name = "Catering" },
        };

        _clock.Setup(c => c.UtcNow).Returns(DateTimeOffset.UtcNow);
        _dbContext.Setup(d => d.BusinessServiceQuestions).Returns(_questions.Object);
        _profiles.Setup(p => p.GetByUserIdAsync(_ownerUserId, It.IsAny<CancellationToken>())).ReturnsAsync(_owner);
        _profiles.Setup(p => p.GetByUserIdAsync(_strangerUserId, It.IsAny<CancellationToken>())).ReturnsAsync(_stranger);
        _services.Setup(s => s.GetByIdAsync(_service.Id, It.IsAny<CancellationToken>())).ReturnsAsync(_service);
    }

    private void SignedInAs(Guid userId) => _currentUser.Setup(c => c.UserId).Returns(userId);

    private void NothingWasSaved() =>
        _dbContext.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);

    // ---- deleting a service ----------------------------------------------------------------------

    [Fact]
    public async Task The_owner_can_delete_their_own_service()
    {
        SignedInAs(_ownerUserId);
        var sut = new DeleteBusinessServiceCommandHandler(
            _currentUser.Object, _profiles.Object, _services.Object, _dbContext.Object);

        await sut.Handle(new DeleteBusinessServiceCommand { Id = _service.Id }, CancellationToken.None);

        _services.Verify(s => s.Remove(_service), Times.Once);
        _dbContext.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Another_business_cannot_delete_it()
    {
        SignedInAs(_strangerUserId);
        var sut = new DeleteBusinessServiceCommandHandler(
            _currentUser.Object, _profiles.Object, _services.Object, _dbContext.Object);

        var act = () => sut.Handle(new DeleteBusinessServiceCommand { Id = _service.Id }, CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        _services.Verify(s => s.Remove(It.IsAny<BusinessService>()), Times.Never);
        NothingWasSaved();
    }

    [Fact]
    public async Task Deleting_a_service_that_does_not_exist_is_a_not_found()
    {
        SignedInAs(_ownerUserId);
        var sut = new DeleteBusinessServiceCommandHandler(
            _currentUser.Object, _profiles.Object, _services.Object, _dbContext.Object);

        var act = () => sut.Handle(new DeleteBusinessServiceCommand { Id = Guid.NewGuid() }, CancellationToken.None);

        await act.Should().ThrowAsync<EntityNotFoundException>();
        NothingWasSaved();
    }

    [Fact]
    public async Task Somebody_with_no_business_profile_cannot_delete_a_service()
    {
        // A customer or worker token reaching a business endpoint. The route's policy refuses this
        // first, but the handler must not depend on that having happened.
        var strayUserId = Guid.NewGuid();
        SignedInAs(strayUserId);
        _profiles.Setup(p => p.GetByUserIdAsync(strayUserId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((BusinessOwnerProfile?)null);
        var sut = new DeleteBusinessServiceCommandHandler(
            _currentUser.Object, _profiles.Object, _services.Object, _dbContext.Object);

        var act = () => sut.Handle(new DeleteBusinessServiceCommand { Id = _service.Id }, CancellationToken.None);

        await act.Should().ThrowAsync<EntityNotFoundException>();
        NothingWasSaved();
    }

    [Fact]
    public async Task An_unauthenticated_caller_cannot_delete_a_service()
    {
        _currentUser.Setup(c => c.UserId).Returns((Guid?)null);
        var sut = new DeleteBusinessServiceCommandHandler(
            _currentUser.Object, _profiles.Object, _services.Object, _dbContext.Object);

        var act = () => sut.Handle(new DeleteBusinessServiceCommand { Id = _service.Id }, CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        NothingWasSaved();
    }

    // ---- taking somebody off the team ------------------------------------------------------------

    [Fact]
    public async Task The_owner_can_take_a_worker_off_their_team()
    {
        SignedInAs(_ownerUserId);
        var membership = new BusinessWorker
        {
            Id = Guid.NewGuid(),
            BusinessOwnerProfileId = _owner.Id,
            AssignmentStatus = BusinessWorkerStatus.Active,
        };
        _workers.Setup(w => w.GetByIdAsync(membership.Id, It.IsAny<CancellationToken>())).ReturnsAsync(membership);
        var sut = new RemoveBusinessWorkerCommandHandler(
            _currentUser.Object, _clock.Object, _profiles.Object, _workers.Object, _dbContext.Object);

        await sut.Handle(new RemoveBusinessWorkerCommand { Id = membership.Id }, CancellationToken.None);

        membership.AssignmentStatus.Should().Be(BusinessWorkerStatus.Removed);
        membership.RespondedAt.Should().NotBeNull();
        _dbContext.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Another_business_cannot_take_somebody_off_a_team_that_is_not_theirs()
    {
        SignedInAs(_strangerUserId);
        var membership = new BusinessWorker
        {
            Id = Guid.NewGuid(),
            BusinessOwnerProfileId = _owner.Id,
            AssignmentStatus = BusinessWorkerStatus.Active,
        };
        _workers.Setup(w => w.GetByIdAsync(membership.Id, It.IsAny<CancellationToken>())).ReturnsAsync(membership);
        var sut = new RemoveBusinessWorkerCommandHandler(
            _currentUser.Object, _clock.Object, _profiles.Object, _workers.Object, _dbContext.Object);

        var act = () => sut.Handle(new RemoveBusinessWorkerCommand { Id = membership.Id }, CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        membership.AssignmentStatus.Should().Be(BusinessWorkerStatus.Active, "nothing should have changed");
        NothingWasSaved();
    }

    // ---- the profile picture ---------------------------------------------------------------------

    [Fact]
    public async Task Setting_a_logo_replaces_the_old_file_only_after_the_row_is_saved()
    {
        SignedInAs(_ownerUserId);
        _owner.LogoUrl = "/uploads/businesses/x/logo.jpg";
        var sut = new SetBusinessLogoCommandHandler(
            _currentUser.Object, _profiles.Object, _storage.Object, _dbContext.Object, new TestPlatformSettings());

        await sut.Handle(
            new SetBusinessLogoCommand { Url = "/uploads/businesses/x/logo.png" },
            CancellationToken.None);

        _owner.LogoUrl.Should().Be("/uploads/businesses/x/logo.png");
        _dbContext.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
        _storage.Verify(s => s.DeleteFile("/uploads/businesses/x/logo.jpg"), Times.Once);
    }

    /// <remarks>
    /// Replacing a JPEG with a JPEG writes over the same filename, so deleting the "previous" file
    /// afterwards would delete the picture that was just uploaded, leaving a profile pointing at
    /// nothing.
    /// </remarks>
    [Fact]
    public async Task Replacing_a_logo_with_the_same_filename_does_not_delete_it()
    {
        SignedInAs(_ownerUserId);
        _owner.LogoUrl = "/uploads/businesses/x/logo.jpg";
        var sut = new SetBusinessLogoCommandHandler(
            _currentUser.Object, _profiles.Object, _storage.Object, _dbContext.Object, new TestPlatformSettings());

        await sut.Handle(
            new SetBusinessLogoCommand { Url = "/uploads/businesses/x/logo.jpg" },
            CancellationToken.None);

        _storage.Verify(s => s.DeleteFile(It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task A_first_logo_deletes_nothing()
    {
        SignedInAs(_ownerUserId);
        _owner.LogoUrl = null;
        var sut = new SetBusinessLogoCommandHandler(
            _currentUser.Object, _profiles.Object, _storage.Object, _dbContext.Object, new TestPlatformSettings());

        await sut.Handle(
            new SetBusinessLogoCommand { Url = "/uploads/businesses/x/logo.jpg" },
            CancellationToken.None);

        _storage.Verify(s => s.DeleteFile(It.IsAny<string>()), Times.Never);
    }

    // ---- the questions on the booking form -------------------------------------------------------

    [Fact]
    public async Task Editing_a_question_keeps_its_id_so_answers_stay_attached()
    {
        SignedInAs(_ownerUserId);
        var existing = new BusinessServiceQuestion
        {
            Id = Guid.NewGuid(),
            BusinessServiceId = _service.Id,
            Prompt = "How many guests?",
            IsRequired = true,
            SortOrder = 0,
        };
        _service.Questions.Add(existing);
        var sut = new SetBusinessServiceQuestionsCommandHandler(
            _currentUser.Object, _profiles.Object, _services.Object, _dbContext.Object);

        await sut.Handle(
            new SetBusinessServiceQuestionsCommand
            {
                ServiceId = _service.Id,
                Questions = [new ServiceQuestionInput { Id = existing.Id, Prompt = "  How many people?  ", IsRequired = false }],
            },
            CancellationToken.None);

        existing.Prompt.Should().Be("How many people?", "the wording is trimmed");
        existing.IsRequired.Should().BeFalse();
        _questions.Verify(q => q.Remove(It.IsAny<BusinessServiceQuestion>()), Times.Never);
        _questions.Verify(q => q.Add(It.IsAny<BusinessServiceQuestion>()), Times.Never);
    }

    [Fact]
    public async Task A_question_left_out_of_the_list_is_removed()
    {
        SignedInAs(_ownerUserId);
        var dropped = new BusinessServiceQuestion
        {
            Id = Guid.NewGuid(),
            BusinessServiceId = _service.Id,
            Prompt = "Any allergies?",
            SortOrder = 0,
        };
        _service.Questions.Add(dropped);
        var sut = new SetBusinessServiceQuestionsCommandHandler(
            _currentUser.Object, _profiles.Object, _services.Object, _dbContext.Object);

        await sut.Handle(
            new SetBusinessServiceQuestionsCommand { ServiceId = _service.Id, Questions = [] },
            CancellationToken.None);

        _questions.Verify(q => q.Remove(dropped), Times.Once);
        _service.Questions.Should().BeEmpty();
    }

    [Fact]
    public async Task Another_business_cannot_change_the_questions()
    {
        SignedInAs(_strangerUserId);
        _service.Questions.Add(new BusinessServiceQuestion
        {
            Id = Guid.NewGuid(),
            BusinessServiceId = _service.Id,
            Prompt = "How many guests?",
        });
        var sut = new SetBusinessServiceQuestionsCommandHandler(
            _currentUser.Object, _profiles.Object, _services.Object, _dbContext.Object);

        var act = () => sut.Handle(
            new SetBusinessServiceQuestionsCommand { ServiceId = _service.Id, Questions = [] },
            CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        _service.Questions.Should().HaveCount(1, "nothing should have been dropped");
        NothingWasSaved();
    }

    [Fact]
    public async Task Editing_a_question_that_belongs_to_nothing_is_a_not_found()
    {
        SignedInAs(_ownerUserId);
        var sut = new SetBusinessServiceQuestionsCommandHandler(
            _currentUser.Object, _profiles.Object, _services.Object, _dbContext.Object);

        var act = () => sut.Handle(
            new SetBusinessServiceQuestionsCommand
            {
                ServiceId = _service.Id,
                Questions = [new ServiceQuestionInput { Id = Guid.NewGuid(), Prompt = "Smuggled in" }],
            },
            CancellationToken.None);

        await act.Should().ThrowAsync<EntityNotFoundException>();
    }
}
